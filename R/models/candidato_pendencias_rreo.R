# Candidato 4 (hipótese RREO, estados): despesa primária empenhada e não paga + restos a pagar processados a pagar,
# no bimestre b, como preditor do restante do ano do primário estadual (BCB 4643). Indicativo: só 2019+ tem RREO de caixa.

#' Pendências de pagamento dos estados por ano x bimestre (R$ bi, soma das 27 UFs; NA se faltar UF):
#' (empenhada - paga) da despesa primária total, cumulativa no ano + saldo de RP processados a pagar no bimestre.
#' Contas: RREO6TotalDespesaPrimaria (colunas "DESPESAS EMPENHADAS" e "DESPESAS PAGAS (a)") e
#' RestosAPagarProcessadosExcetoPrecatorios (coluna "Até o Bimestre"). Nota: RREO6TotalDespesaPrimaria inclui RPPS.
pendencias_estados <- function(rreo) {
  a6 <- rreo[grepl("Anexo 06", rreo$anexo), ]
  col <- toupper(gsub("[[:space:]]+", " ", trimws(a6$coluna)))
  emp <- a6$cod_conta == "RREO6TotalDespesaPrimaria" & col == "DESPESAS EMPENHADAS"
  pag <- a6$cod_conta == "RREO6TotalDespesaPrimaria" & col == "DESPESAS PAGAS (A)"
  rp  <- a6$cod_conta == "RestosAPagarProcessadosExcetoPrecatorios" & grepl("^AT. O BIMESTRE", col)
  pega <- function(sel, nome) {
    d <- a6[sel, c("exercicio", "periodo", "cod_ibge", "valor")]
    d <- d[!duplicated(d[c("exercicio", "periodo", "cod_ibge")]), ]; names(d)[4] <- nome; d
  }
  m <- Reduce(function(x, y) merge(x, y, by = c("exercicio", "periodo", "cod_ibge"), all = TRUE),
              list(pega(emp, "emp"), pega(pag, "pag"), pega(rp, "rp")))
  m$pend <- (m$emp - m$pag) + ifelse(is.na(m$rp), 0, m$rp)
  m <- m[!is.na(m$emp) & !is.na(m$pag), ]
  agg <- stats::aggregate(cbind(pend = pend, ufs = 1) ~ exercicio + periodo, data = m, FUN = sum)
  data.frame(ano = agg$exercicio, bimestre = agg$periodo, ufs = agg$ufs,
             pend_bi = ifelse(agg$ufs == 27, agg$pend / 1e9, NA_real_))
}

#' Teste indicativo por corte m = 2b+1: restante (% PIB) ~ r_lag + pend_t (% PIB), erro leave-one-out contra o SRW em % do PIB.
#' `painel`: painel_restante() do primário estadual. Sem poder estatístico (n <= 7); serve para ver sinal e ordem de grandeza.
teste_pendencias <- function(painel, pend, excluir = integer(0)) {
  out <- list()
  for (b in 1:5) {
    m <- 2 * b + 1
    pm <- painel[painel$corte == m, ]
    pm$x <- pend$pend_bi[match(paste(pm$ano, b), paste(pend$ano, pend$bimestre))] / pm$pib * 100
    pm$r100 <- pm$r * 100; pm$rl100 <- pm$r_lag * 100
    pm <- pm[stats::complete.cases(pm[c("r100", "rl100", "x")]) & !(pm$ano %in% excluir), ]
    if (nrow(pm) < 5) next
    e_srw <- pm$rl100 - pm$r100
    e_loo <- vapply(seq_len(nrow(pm)), function(i) {
      fit <- stats::lm(r100 ~ rl100 + x, data = pm[-i, ]); stats::predict(fit, pm[i, ]) - pm$r100[i] }, numeric(1))
    fit <- stats::lm(r100 ~ rl100 + x, data = pm)
    out[[length(out) + 1]] <- data.frame(bimestre = b, corte = m, n = nrow(pm),
      coef_pend = unname(stats::coef(fit)["x"]), p_coef = summary(fit)$coefficients["x", 4],
      RMSE_srw_pp = sqrt(mean(e_srw^2)), RMSE_loo_pp = sqrt(mean(e_loo^2)),
      cor_x_vs_surpresa = stats::cor(pm$x, pm$r100 - pm$rl100))
  }
  do.call(rbind, out)
}
