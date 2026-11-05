# E5 em producao: adocao por serie e faixa (data/protocolo/e5_adocao.csv), projecao do ano corrente e agregacao do crescimento real dos estados.
# Decisao de adocao: Pedro, 05/11/2026 (pos-resultado; docs/relatorio_e5_adendo.md, docs/contrato.md). Codigo so em ASCII.

E5_ADOCAO_ARQ <- file.path("data", "protocolo", "e5_adocao.csv")
E5_MODELOS_SOMBRA <- c("B0", "M1", "M2", "M3")   # M4 fora da producao (05/11/2026); Ca e Cb nao foram aceitos

#' Tabela de adocao: serie, faixa, modelo, membros ("M1+M2+M3" so para M5s4), oficial (TRUE/FALSE), desde, motivo.
e5_ler_adocao <- function(arq = E5_ADOCAO_ARQ) {
  a <- ler_csv(arq, colClasses = c(serie = "character", faixa = "character", modelo = "character", membros = "character", desde = "character", motivo = "character"))
  a$oficial <- a$oficial %in% c(TRUE, "TRUE", "true", "1"); a$membros[is.na(a$membros)] <- ""
  stopifnot(all(c("serie", "faixa", "modelo", "membros", "oficial") %in% names(a)))
  of <- a[a$oficial, ]; stopifnot(!anyDuplicated(of[, c("serie", "faixa")]))
  a
}
e5_faixa_corte <- function(corte) names(E5_FAIXAS)[vapply(E5_FAIXAS, function(z) corte %in% z, logical(1))]

#' Estende o IPCA mensal (SGS 433, em %) ate dezembro de `ano`: ate o mes `ate_mes` usa o realizado; depois, taxa mensal uniforme tal que o IPCA do ano
#' feche em `ipca_anual` (convencao do contrato, 04/11/2026). Retorna data.frame(data, valor) em %.
e5_ipca_estendido <- function(sgs, ano, ipca_anual, ate_mes) {
  sgs <- sgs[order(sgs$data), ]; d <- as.Date(sgs$data)
  sgs <- sgs[!(format(d, "%Y") == as.character(ano) & as.integer(format(d, "%m")) > ate_mes) & format(d, "%Y") <= as.character(ano), ]
  if (ate_mes >= 12) return(sgs)
  d <- as.Date(sgs$data); acum <- prod(1 + sgs$valor[format(d, "%Y") == as.character(ano) & as.integer(format(d, "%m")) <= ate_mes] / 100)
  k <- 12L - ate_mes; i <- ((1 + ipca_anual) / acum)^(1 / k) - 1
  rbind(sgs, data.frame(data = as.Date(sprintf("%d-%02d-01", ano, (ate_mes + 1L):12L)), valor = 100 * i))
}

#' Maior bimestre b (1..6) do ano em que todas as UFs esperadas tem os b primeiros bimestres de rec:total e desp:total.
e5_corte_disponivel <- function(P, ano, n_ufs = 27L) {
  x <- P[P$exercicio == ano & P$serie %in% c("rec:total", "desp:total") & !is.na(P$valor), ]
  ok <- vapply(1:6, function(b) { y <- x[x$periodo <= b, ]; ag <- table(y$cod_ibge, y$serie); length(unique(y$cod_ibge)) >= n_ufs && all(ag[, "rec:total"] == b) && all(ag[, "desp:total"] == b) }, logical(1))
  if (!any(ok)) 0L else max(which(ok))
}

#' Acumulado do ano corrente ate o corte (nominal e real), por UF x serie. Exige os `corte` bimestres.
e5_painel_corrente <- function(P, ind_bim, series, ano, corte) {
  P <- P[P$exercicio == ano & P$serie %in% series & P$periodo <= corte & !is.na(P$valor), ]
  P$real <- P$valor / ind_bim(P$exercicio, P$periodo)
  ch <- split(P, list(P$cod_ibge, P$serie), drop = TRUE)
  out <- lapply(ch, function(d) if (length(unique(d$periodo)) < corte) NULL else data.frame(cod_ibge = d$cod_ibge[1], serie = d$serie[1], exercicio = ano, corte = corte, A = sum(d$valor), Areal = sum(d$real)))
  out <- do.call(rbind, out); if (is.null(out)) return(NULL)
  cbind(out, T = NA_real_, R = NA_real_, r = NA_real_, Treal = NA_real_)
}

#' Projecao do ano `ano` no corte `corte`, por UF, para cada serie e modelo. `hist`: painel de UF-anos validos (anos < ano) com colunas do e5_painel();
#' `cur`: e5_painel_corrente(); `modelos`: vetor de B0/M1/M2/M3; `membros`: lista nomeada de M5s4 (ex.: list(M5s4 = c("M1","M2","M3"))) por serie.
#' Treino: todas as linhas de anos < `ano` na faixa do corte (mesma regra do backtest). Retorna data.frame por UF x serie x modelo com A, Areal, logr_hat, That, Rhat, Rreal_hat, Treal_hat, Treal_ant, T_ant.
e5_projetar <- function(hist, cur, ind_bim, ano, corte, modelos = E5_MODELOS_SOMBRA, membros = list(), pend = NULL, den = NULL, sem = FALSE, series = E5_ALVOS) {
  faixa <- e5_faixa_corte(corte); cf <- E5_FAIXAS[[faixa]]
  base <- e5_base_modelo(rbind(hist, cur), ind_bim, pend, den, sem)
  ind_rest <- if (corte < 6) mean(ind_bim(rep(ano, 6 - corte), (corte + 1L):6)) else NA_real_
  out <- list()
  for (s in series) {
    termos <- e5_termos(s, sem); need <- intersect(c("y", "x1", "x2", "x3", "x4"), c("y", termos))
    b <- base[base$serie == s & base$corte %in% cf, ]
    tr <- b[b$exercicio < ano & stats::complete.cases(b[, need]), ]
    al0 <- b[b$exercicio == ano & b$corte == corte & is.finite(b$x1), ]
    if (!nrow(al0)) next
    okm <- stats::complete.cases(al0[, setdiff(need, "y")]); al <- al0[okm, ]
    pr <- list(B0 = al0$x1)
    for (m in intersect(modelos, c("M1", "M2", "M3"))) {
      v <- rep(NA_real_, nrow(al0)); if (nrow(al)) v[okm] <- al$x1 + e5_prever(tr, al, termos, m)$yhat; pr[[m]] <- v
    }
    for (nm in names(membros)) { mm <- membros[[nm]]; if (all(mm %in% names(pr))) pr[[nm]] <- rowMeans(do.call(cbind, pr[mm])) }
    al <- al0
    for (m in names(pr)) {
      lh <- pr[[m]]; Rh <- al$A * exp(lh)
      out[[length(out) + 1]] <- data.frame(serie = s, modelo = m, cod_ibge = al$cod_ibge, exercicio = ano, corte = corte, A = al$A, Areal = al$Areal, logr_hat = lh, That = al$A + Rh, Rhat = Rh,
        Rreal_hat = Rh / ind_rest, Treal_hat = al$Areal + Rh / ind_rest, Treal_ant = al$Treal_ant, T_ant = al$T_ant)
    }
  }
  do.call(rbind, out)
}

#' Agrega por serie x modelo (UFs com previsao e ano anterior; `excluir` = codigos IBGE fora): crescimento real do ano e total nominal/real.
e5_agregar_cresc <- function(U, excluir = integer(0)) {
  U <- U[!U$cod_ibge %in% excluir & is.finite(U$Treal_hat) & is.finite(U$Treal_ant), ]
  g <- split(U, list(U$serie, U$modelo), drop = TRUE)
  out <- lapply(g, function(d) data.frame(serie = d$serie[1], modelo = d$modelo[1], n_ufs = length(unique(d$cod_ibge)), That_bi = sum(d$That) / 1e9, Treal_hat_bi = sum(d$Treal_hat) / 1e9,
    T_ant_bi = sum(d$T_ant) / 1e9, Treal_ant_bi = sum(d$Treal_ant) / 1e9, cresc_real_pct = 100 * (sum(d$Treal_hat) / sum(d$Treal_ant) - 1), cresc_nominal_pct = 100 * (sum(d$That) / sum(d$T_ant) - 1)))
  out <- do.call(rbind, out); rownames(out) <- NULL; out
}

#' Resolve o modelo oficial e a sombra por serie. Retorna data.frame(serie, modelo, membros, oficial) para a faixa do corte; B0, M1, M2 e M3 sempre entram (sombra se nao oficiais).
e5_plano_faixa <- function(adocao, corte) {
  f <- e5_faixa_corte(corte); a <- adocao[adocao$faixa == f, c("serie", "modelo", "membros", "oficial")]
  base <- expand.grid(serie = E5_ALVOS, modelo = E5_MODELOS_SOMBRA, stringsAsFactors = FALSE); base$membros <- ""; base$oficial <- FALSE
  x <- rbind(a, base[!paste(base$serie, base$modelo) %in% paste(a$serie, a$modelo), ])
  x[order(x$serie, !x$oficial, x$modelo), ]
}

#' Projecao completa de uma rodada: conceito consolidado (todas as UFs) e ponte sem RPPS excluindo `excluir_sem` (PR e RS), no corte b disponivel.
#' `fh`: fluxos harmonizados (com RPPS, sem intra); `fl`: fluxos brutos com RPPS (denominador das pendencias); `fs`: fluxos sem RPPS (bruto); `rreo`, `dic`, `dc`: para o total primario do A6;
#' `sgs_ipca`: SGS 433 (data, valor em %); `ipca_anual`: premissa do ano. Retorna NULL se nao ha corte utilizavel (b < 1 ou ano fechado).
e5_projecao_rodada <- function(fh, fl, fs, rreo, dic, dc, sgs_ipca, ipca_anual, ano, adocao, n_ufs = 27L, excluir_sem = c(41L, 43L)) {
  Pc <- e5_com_totais(fh[fh$exercicio <= ano, ]); b <- e5_corte_disponivel(Pc, ano, n_ufs)
  if (b < 1L || b >= 6L) return(NULL)
  ind <- e5_ipca_bim(e5_ipca_estendido(sgs_ipca, ano, ipca_anual, ate_mes = 2L * b))
  pb <- e5_painel(e5_com_totais(fl[fl$exercicio < ano, ]), ind, "desp:total")
  den <- data.frame(cod_ibge = pb$cod_ibge[pb$corte == 1], exercicio = pb$exercicio[pb$corte == 1] + 1L, Treal_bruta_ant = pb$Treal[pb$corte == 1])
  a6 <- e5_a6_totais(rreo, dic, dc); pe <- a6[a6$periodo %in% 1:5, ]
  pend <- data.frame(cod_ibge = pe$cod_ibge, exercicio = pe$exercicio, corte = pe$periodo, liq_menos_paga = pe$liquidada - pe$paga, emp_menos_liq = pe$empenhada - pe$liquidada)
  plano <- e5_plano_faixa(adocao, b); f <- e5_faixa_corte(b)
  mem <- list(); for (i in which(plano$modelo == "M5s4")) mem[[paste0("M5s4")]] <- strsplit(plano$membros[i], "+", fixed = TRUE)[[1]]
  # metodo da faixa anterior (para o salto na troca de metodo): so quando difere do da faixa atual
  fa <- names(E5_FAIXAS)[match(f, names(E5_FAIXAS)) - 1L]; prev <- if (length(fa) && !is.na(fa)) adocao[adocao$faixa == fa & adocao$oficial, ] else adocao[0, ]
  for (i in seq_len(nrow(prev))) if (prev$modelo[i] == "M5s4") mem[[paste0("prev_", prev$serie[i])]] <- strsplit(prev$membros[i], "+", fixed = TRUE)[[1]]
  rodar <- function(Pser, excl, sem) {
    Pser <- Pser[!Pser$cod_ibge %in% excl, ]
    hist <- e5_painel(Pser[Pser$exercicio < ano, ], ind, E5_ALVOS); cur <- e5_painel_corrente(Pser, ind, E5_ALVOS, ano, b)
    e5_projetar(hist, cur, ind, ano, b, c("B0", "M1", "M2", "M3"), mem, if (sem) NULL else pend, den[!den$cod_ibge %in% excl, ], sem)
  }
  Uc <- rodar(Pc, integer(0), FALSE); Us <- rodar(e5_com_totais(fs[fs$exercicio <= ano, ]), excluir_sem, TRUE)
  marca <- function(A) { A$oficial <- FALSE; for (i in seq_len(nrow(plano))) A$oficial[A$serie == plano$serie[i] & A$modelo == plano$modelo[i]] <- plano$oficial[i]; A }
  filtra <- function(A) A[!(grepl("^prev_", A$modelo) & A$modelo != paste0("prev_", A$serie)), ]
  Ac <- marca(cbind(conceito = "consolidado", filtra(e5_agregar_cresc(Uc)))); As <- marca(cbind(conceito = "sem_rpps_ex_PR_RS", filtra(e5_agregar_cresc(Us))))
  list(corte = b, faixa = f, ano = ano, plano = plano, uf = Uc, uf_sem = Us, cresc = rbind(Ac, As), adocao_usada = adocao[adocao$faixa == f, ])
}

#' Primario por diferenca (receita - despesa) do modelo oficial de cada serie, por conceito. R$ bi nominais (previsao e ano anterior) e reais (do ano anterior).
e5_primario <- function(cresc) {
  out <- lapply(split(cresc, cresc$conceito), function(d) {
    r <- d[d$serie == "rec:total" & d$oficial, ][1, ]; x <- d[d$serie == "desp:total" & d$oficial, ][1, ]
    data.frame(conceito = d$conceito[1], modelo_receita = r$modelo, modelo_despesa = x$modelo, primario_prev_bi = r$That_bi - x$That_bi, primario_ano_ant_bi = r$T_ant_bi - x$T_ant_bi,
               primario_prev_real_bi = r$Treal_hat_bi - x$Treal_hat_bi, primario_ano_ant_real_bi = r$Treal_ant_bi - x$Treal_ant_bi)
  })
  out <- do.call(rbind, out); rownames(out) <- NULL; out
}

#' Salto na previsao quando o metodo da faixa atual difere do da faixa anterior (ex.: receita M5 -> B0 entre b4 e b5): crescimento real com o metodo atual menos o do metodo anterior,
#' nos mesmos dados do corte. Retorna data.frame(conceito, serie, modelo_atual, modelo_anterior, cresc_atual, cresc_anterior, salto_pp, salto_bi) (vazio se nao ha troca).
e5_salto_troca <- function(r, adocao) {
  f <- r$faixa; fa <- names(E5_FAIXAS)[match(f, names(E5_FAIXAS)) - 1L]; out <- list()
  if (!length(fa) || is.na(fa)) return(NULL)
  for (s in E5_ALVOS) {
    at <- adocao[adocao$faixa == f & adocao$serie == s & adocao$oficial, ]; an <- adocao[adocao$faixa == fa & adocao$serie == s & adocao$oficial, ]
    if (!nrow(at) || !nrow(an) || (at$modelo == an$modelo && at$membros == an$membros)) next
    mant <- if (an$modelo == "M5s4") paste0("prev_", s) else an$modelo
    for (cn in unique(r$cresc$conceito)) {
      x <- r$cresc[r$cresc$conceito == cn & r$cresc$serie == s, ]; xa <- x[x$modelo == at$modelo, ]; xp <- x[x$modelo == mant, ]
      if (nrow(xa) && nrow(xp)) out[[length(out) + 1]] <- data.frame(conceito = cn, serie = s, modelo_atual = at$modelo, modelo_anterior = an$modelo, cresc_atual = xa$cresc_real_pct, cresc_anterior = xp$cresc_real_pct,
        salto_pp = xa$cresc_real_pct - xp$cresc_real_pct, salto_bi = xa$That_bi - xp$That_bi)
    }
  }
  if (length(out)) do.call(rbind, out) else NULL
}
