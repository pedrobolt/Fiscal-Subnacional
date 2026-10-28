# Torneio do P1 (E4): aplica a regra de aceitação congelada em docs/contrato.md ("Protocolo do P1") às previsões
# fora da amostra de backtest_p1(). Nada aqui ajusta modelo: só mede, compara com a base e decide por faixa.
# Entrada: `bt` = saída de backtest_p1() (ano, corte, modelo, previsao, realizado, erro). Base: SRW em R$.

FAIXAS_P1 <- list("1-4" = 1:4, "5-8" = 5:8, "9-11" = 9:11)
MIN_ANOS_ELEGIVEL <- 10     # anos-alvo sem 2020–22 na faixa (contrato)
HOLM_ALFA <- 0.10
EXIGE_MELHORA_RMSE <- 0.10  # RMSE pelo menos 10% menor que o da base
TOLERA_PIORA_COM_PANDEMIA <- 0.10

#' DM com perda quadrática média da faixa por ano-alvo (d = L_base - L_cand), correção de Harvey-Leybourne-Newbold (h = 1),
#' t com n-1 gl, p bilateral (a direção da melhora é exigida à parte pelo critério 1). Retorna c(stat, p).
dm_hln <- function(d) {
  n <- length(d)
  if (n < 4 || stats::sd(d) == 0) return(c(stat = NA_real_, p = NA_real_))
  stat <- mean(d) / sqrt(stats::var(d) / n) * sqrt((n - 1) / n)
  c(stat = stat, p = 2 * stats::pt(-abs(stat), df = n - 1))
}

#' Pares ano x corte da faixa em que o candidato E a base têm previsão, mantendo só anos com todos os cortes da faixa.
parear_faixa <- function(bt, cand, base, cortes) {
  b <- bt[bt$modelo == base & bt$corte %in% cortes & !is.na(bt$previsao), ]
  c <- bt[bt$modelo == cand & bt$corte %in% cortes & !is.na(bt$previsao), ]
  k <- merge(c[c("ano", "corte", "previsao", "realizado", "erro")], b[c("ano", "corte", "previsao", "erro")],
             by = c("ano", "corte"), suffixes = c("_c", "_b"))
  n_por_ano <- table(k$ano)
  k[k$ano %in% as.integer(names(n_por_ano)[n_por_ano == length(cortes)]), ]
}

#' Métricas de um desafiante contra a base numa faixa (os 4 critérios, sem Holm). NA se não houver par.
metricas_faixa <- function(bt, cand, base, cortes) {
  k <- parear_faixa(bt, cand, base, cortes)
  if (nrow(k) == 0) return(data.frame(n_anos = 0L, RMSE_c = NA_real_, RMSE_b = NA_real_, rel_RMSE = NA_real_, share_melhor = NA_real_,
                                     DM_stat = NA_real_, DM_p = NA_real_, sinal_c = NA_real_, sinal_b = NA_real_, ME_c = NA_real_, ME_b = NA_real_))
  por_ano <- function(f) tapply(f, k$ano, mean)
  Lc <- por_ano(k$erro_c^2); Lb <- por_ano(k$erro_b^2); Mc <- por_ano(abs(k$erro_c)); Mb <- por_ano(abs(k$erro_b))
  dm <- dm_hln(Lb - Lc)
  data.frame(n_anos = length(Lc), RMSE_c = sqrt(mean(k$erro_c^2)), RMSE_b = sqrt(mean(k$erro_b^2)),
             rel_RMSE = sqrt(mean(k$erro_c^2)) / sqrt(mean(k$erro_b^2)) - 1, share_melhor = mean(Mc < Mb),
             DM_stat = dm[["stat"]], DM_p = dm[["p"]],
             sinal_c = mean(sign(k$previsao_c) == sign(k$realizado)), sinal_b = mean(sign(k$previsao_b) == sign(k$realizado)),
             ME_c = mean(k$erro_c), ME_b = mean(k$erro_b))
}

#' Critérios 1, 2 e 4 e o 3 (Holm entre os elegíveis da faixa, nesta amostra). `elegivel`: vetor lógico por desafiante.
aplicar_criterios <- function(m, elegivel) {
  m$p_holm <- NA_real_
  ok <- elegivel & !is.na(m$DM_p)
  if (any(ok)) m$p_holm[ok] <- stats::p.adjust(m$DM_p[ok], method = "holm")
  m$c1_rmse <- !is.na(m$rel_RMSE) & m$rel_RMSE <= -EXIGE_MELHORA_RMSE
  m$c2_anos <- !is.na(m$share_melhor) & m$share_melhor > 0.5
  m$c3_dm <- !is.na(m$p_holm) & m$p_holm < HOLM_ALFA
  m$c4_sinal_vies <- !is.na(m$sinal_c) & m$sinal_c >= m$sinal_b & abs(m$ME_c) <= abs(m$ME_b)
  m$passa <- elegivel & m$c1_rmse & m$c2_anos & m$c3_dm & m$c4_sinal_vies
  m
}

#' Torneio completo. `bt_sem` e `bt_com`: backtests sem e com 2020–22 (mesmos candidatos). Retorna data.frame
#' faixa x desafiante com métricas das duas amostras, elegibilidade, critérios e decisão ("aceito", "rejeitado", "so_reportado").
torneio_p1 <- function(bt_sem, bt_com, desafiantes, base = "srw_brl", faixas = FAIXAS_P1) {
  out <- list()
  for (f in names(faixas)) {
    ms <- do.call(rbind, lapply(desafiantes, function(d) cbind(desafiante = d, metricas_faixa(bt_sem, d, base, faixas[[f]]))))
    mc <- do.call(rbind, lapply(desafiantes, function(d) cbind(desafiante = d, metricas_faixa(bt_com, d, base, faixas[[f]]))))
    elig <- ms$n_anos >= MIN_ANOS_ELEGIVEL
    ms <- aplicar_criterios(ms, elig); mc <- aplicar_criterios(mc, elig)    # a família do Holm é a mesma nas duas amostras
    aceito <- elig & ms$passa & (mc$passa | (!is.na(mc$rel_RMSE) & mc$rel_RMSE <= TOLERA_PIORA_COM_PANDEMIA))
    names(ms)[-1] <- paste0(names(ms)[-1], "_sem"); names(mc)[-1] <- paste0(names(mc)[-1], "_com")
    r <- cbind(faixa = f, ms, mc[-1], elegivel = elig, aceito = aceito)
    r$decisao <- ifelse(!elig, "so_reportado", ifelse(aceito, "aceito", "rejeitado"))
    out[[f]] <- r
  }
  do.call(rbind, out)
}

#' Escolha por faixa: sem aceito, vale a base; com mais de um aceito, o de menor RMSE sem 2020–22 (desempate fixado em
#' 28/10/2026 antes da execução; todos os aceitos são reportados).
escolher_por_faixa <- function(tab, base = "srw_brl") {
  do.call(rbind, lapply(unique(tab$faixa), function(f) {
    a <- tab[tab$faixa == f & tab$decisao == "aceito", ]
    data.frame(faixa = f, modelo = if (nrow(a)) a$desafiante[which.min(a$RMSE_c_sem)] else base,
               aceitos = if (nrow(a)) paste(a$desafiante, collapse = ",") else "(nenhum)",
               K = length(unique(tab$desafiante)) + 1L, com_previsao = sum(tab$faixa == f & tab$n_anos_sem > 0),
               elegiveis = sum(tab$faixa == f & tab$elegivel))
  }))
}

#' Conferência de reprodutibilidade (regra 7): resumo por modelo x amostra x corte regenerado contra o registrado no PR #25.
#' `novo` e `antigo`: data.frames com modelo, amostra, corte, n, ME, MAE, RMSE. Retorna as linhas que divergem além de `tol`.
conferir_reproducao <- function(novo, antigo, tol = 1.1e-4) {
  m <- merge(novo, antigo, by = c("modelo", "amostra", "corte"), suffixes = c("_novo", "_antigo"), all = TRUE)
  dif <- is.na(m$n_novo) | is.na(m$n_antigo) | m$n_novo != m$n_antigo |
    abs(m$ME_novo - m$ME_antigo) > tol | abs(m$MAE_novo - m$MAE_antigo) > tol | abs(m$RMSE_novo - m$RMSE_antigo) > tol
  m[dif, ]
}
