# Candidatos do E3.4/E4 que modelam só o restante do ano (corte+1..dez) em % do PIB (24-27/10/2026).
# Total previsto = acumulado até o corte (observado) + restante previsto. Valores em R$ bi, superávit positivo.
# Estimação rolante: para o alvo t usa só anos y < t. Denominador: PIB nominal realizado de cada ano
# (no backtest não há vintage da projeção de PIB; a operação usa o PIB de `premissas.yml`).

ANOS_PANDEMIA <- 2020:2022

#' Painel ano x corte: acumulado A, restante R, total Y, PIB, razões em % do PIB, restante do ano anterior em % do PIB
#' (`r_lag`), dummies de eleição e tendência. `serie`: data.frame(data, valor_bi); `pib`: data.frame(ano, pib_bi).
painel_restante <- function(serie, pib, cortes = 1:11) {
  anos <- sort(unique(as.integer(format(serie$data, "%Y"))))
  anos <- anos[vapply(anos, function(a) !is.na(soma_meses(serie, a, 1:12)), logical(1))]
  linhas <- list()
  for (m in cortes) for (a in anos) {
    P <- pib$pib_bi[pib$ano == a]; Pl <- pib$pib_bi[pib$ano == a - 1]
    A <- soma_meses(serie, a, 1:m); R <- soma_meses(serie, a, (m + 1):12)
    Rl <- if ((a - 1) %in% anos) soma_meses(serie, a - 1, (m + 1):12) else NA_real_
    linhas[[length(linhas) + 1]] <- data.frame(
      ano = a, corte = m, A = A, R = R, Y = A + R, pib = if (length(P)) P else NA_real_,
      a = if (length(P)) A / P else NA_real_, r = if (length(P)) R / P else NA_real_,
      r_lag = if (length(Pl) && !is.na(Rl)) Rl / Pl else NA_real_,
      E = as.integer(a %% 4 == 2),     # eleição estadual/federal: 2002, 2006, ..., 2026
      Emun = as.integer(a %% 4 == 0),  # eleição municipal: 2000, 2004, ..., 2024
      tend = a - 2000)
  }
  do.call(rbind, linhas)
}

#' Especificações: fórmula do restante em % do PIB (NULL = SRW em % do PIB) e janela (NA = expansiva).
ESPEC_RESTANTE <- list(
  srw_pib    = list(formula = NULL),
  m2         = list(formula = r ~ r_lag + E),
  m3         = list(formula = r ~ a + r_lag + E),
  m3_tend    = list(formula = r ~ a + r_lag + E + tend),
  m3_jan10   = list(formula = r ~ a + r_lag + E, janela = 10),
  m3_2eleic  = list(formula = r ~ a + r_lag + E + Emun)
)

#' Previsão do restante (fração do PIB) para o alvo `t` no painel de um corte; NA se faltar treino.
prever_restante <- function(painel_m, t, espec, excluir = integer(0), min_treino = 8) {
  alvo <- painel_m[painel_m$ano == t, ]
  if (nrow(alvo) != 1 || anyNA(alvo[c("a", "r_lag", "pib")])) return(NA_real_)
  if (is.null(espec$formula)) return(alvo$r_lag)
  tr <- painel_m[painel_m$ano < t & !(painel_m$ano %in% excluir), ]
  tr <- tr[stats::complete.cases(tr[c("r", "a", "r_lag")]), ]
  if (!is.null(espec$janela) && nrow(tr) > espec$janela) tr <- tr[order(tr$ano), ][(nrow(tr) - espec$janela + 1):nrow(tr), ]
  if (nrow(tr) < min_treino) return(NA_real_)
  as.numeric(stats::predict(stats::lm(espec$formula, data = tr), newdata = alvo))
}

#' Backtest rolante dos candidatos para todos os cortes. Retorna uma linha por ano x corte x modelo, com erros em R$ bi e % do PIB.
#' `excluir`: anos fora do treino E do teste (ex.: 2020:2022).
backtest_restante <- function(painel, anos_alvo, especs = ESPEC_RESTANTE, excluir = integer(0), min_treino = 8) {
  linhas <- list()
  for (m in sort(unique(painel$corte))) {
    pm <- painel[painel$corte == m, ]
    for (t in setdiff(anos_alvo, excluir)) {
      al <- pm[pm$ano == t, ]
      if (nrow(al) != 1) next
      for (nome in names(especs)) {
        rhat <- prever_restante(pm, t, especs[[nome]], excluir, min_treino)
        prev <- al$A + rhat * al$pib
        linhas[[length(linhas) + 1]] <- data.frame(ano = t, corte = m, modelo = nome, previsao = prev, realizado = al$Y,
                                                   erro = prev - al$Y, erro_pp = (prev - al$Y) / al$pib * 100, pib = al$pib)
      }
    }
  }
  do.call(rbind, linhas)
}

#' Teste de Diebold-Mariano (perda quadrática, h = 1, correção de Harvey-Leybourne-Newbold, t com n-1 gl).
#' d = e_base^2 - e_modelo^2: estatística positiva = modelo melhor que a base. Retorna c(stat, p).
dm_teste <- function(erro_modelo, erro_base) {
  d <- erro_base^2 - erro_modelo^2; n <- length(d)
  if (n < 4 || stats::sd(d) == 0) return(c(stat = NA_real_, p = NA_real_))
  stat <- mean(d) / sqrt(stats::var(d) / n) * sqrt((n - 1) / n)
  c(stat = stat, p = 2 * stats::pt(-abs(stat), df = n - 1))
}

#' Resumo por modelo e corte (só ano x corte em que todos os modelos têm previsão): ME/MAE/RMSE em R$ bi e em % do PIB,
#' MASE relativo à base (MAE / MAE da base, em % do PIB), DM contra a base e acerto de sinal do total anual.
resumir_restante <- function(bt, base = "srw_pib") {
  chave <- paste(bt$ano, bt$corte)
  ok <- names(which(table(chave[!is.na(bt$previsao)]) == length(unique(bt$modelo))))
  bt <- bt[chave %in% ok, ]
  out <- list()
  for (m in sort(unique(bt$corte))) {
    b <- bt[bt$corte == m & bt$modelo == base, ]
    for (nome in unique(bt$modelo)) {
      d <- bt[bt$corte == m & bt$modelo == nome, ]
      if (nrow(d) == 0) next
      dm <- if (nome == base) c(stat = NA_real_, p = NA_real_) else dm_teste(d$erro_pp, b$erro_pp[match(d$ano, b$ano)])
      out[[length(out) + 1]] <- data.frame(
        modelo = nome, corte = m, n = nrow(d),
        ME = mean(d$erro), MAE = mean(abs(d$erro)), RMSE = sqrt(mean(d$erro^2)),
        ME_pp = mean(d$erro_pp), MAE_pp = mean(abs(d$erro_pp)), RMSE_pp = sqrt(mean(d$erro_pp^2)),
        MASE_srw = mean(abs(d$erro_pp)) / mean(abs(b$erro_pp)), DM_stat = dm[["stat"]], DM_p = dm[["p"]],
        acerto_sinal = mean(sign(d$previsao) == sign(d$realizado)))
    }
  }
  do.call(rbind, out)
}
