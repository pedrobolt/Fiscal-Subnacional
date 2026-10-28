# E4.2: intervalos de previsão do P1 (modelo publicado: SRW em R$). Nível 80%, paramétrico (contrato, "Intervalos de previsão"):
# previsão ± 1,2816 × σ do corte; σ = RMSE do modelo publicado naquele corte, estimado de forma rolante (só anos < alvo),
# suavizado entre cortes vizinhos (pesos 1-2-1 sobre o RMSE², extremos refletidos), forçado a não crescer com o corte.

Z80 <- stats::qnorm(0.90)   # 1,2816
MIN_ANOS_SIGMA <- 8         # mínimo de anos de erro passado para estimar σ (igual ao mínimo de treino dos modelos)

#' Média móvel 1-2-1 (pesos 1/4, 1/2, 1/4) sobre `v`, com extremos refletidos sem repetir a borda (v[0] = v[2], v[n+1] = v[n-1]).
suavizar_121 <- function(v) {
  n <- length(v); if (n < 3) return(v)
  ext <- c(v[2], v, v[n - 1])
  (ext[1:n] + 2 * ext[2:(n + 1)] + ext[3:(n + 2)]) / 4
}

#' Ajuste isotônico não crescente (PAV): o σ² não pode crescer com o corte.
isotonica_nao_crescente <- function(v) rev(stats::isoreg(rev(v))$yf)

#' σ² por corte a partir dos erros passados (data.frame com ano, corte, erro), só anos < `ano_alvo` e fora de `excluir`.
#' NA se o corte tiver menos de `min_anos` anos de erro.
sigma2_corte <- function(erros, ano_alvo, cortes = 1:11, excluir = integer(0), min_anos = MIN_ANOS_SIGMA) {
  e <- erros[erros$ano < ano_alvo & !(erros$ano %in% excluir) & !is.na(erros$erro), ]
  vapply(cortes, function(m) { z <- e$erro[e$corte == m]; if (length(z) < min_anos) NA_real_ else mean(z^2) }, numeric(1))
}

#' σ publicado por corte para o alvo `ano_alvo` (vetor de comprimento length(cortes)); NA se faltar histórico em algum corte.
sigma_publicado <- function(erros, ano_alvo, cortes = 1:11, excluir = integer(0), min_anos = MIN_ANOS_SIGMA) {
  s2 <- sigma2_corte(erros, ano_alvo, cortes, excluir, min_anos)
  if (anyNA(s2)) return(rep(NA_real_, length(cortes)))
  sqrt(isotonica_nao_crescente(suavizar_121(s2)))
}

#' Intervalo `[inf, sup]` = previsão ± Z80 × σ.
intervalo_80 <- function(previsao, sigma) data.frame(inf = previsao - Z80 * sigma, sup = previsao + Z80 * sigma)

#' Intervalo de Wilson para uma proporção (k acertos em n). `conf`: nível (0,90 por padrão).
wilson <- function(k, n, conf = 0.90) {
  if (n == 0) return(c(inf = NA_real_, sup = NA_real_))
  z <- stats::qnorm(1 - (1 - conf) / 2); p <- k / n
  centro <- (p + z^2 / (2 * n)) / (1 + z^2 / n)
  meia <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / (1 + z^2 / n)
  c(inf = centro - meia, sup = centro + meia)
}

#' Intervalos e cobertura para todos os alvos. `bt`: backtest do modelo publicado (ano, corte, previsao, realizado, erro),
#' com anos suficientes antes do primeiro alvo. Retorna uma linha por alvo x corte com σ com e sem 2020–22 e as coberturas.
intervalos_backtest <- function(bt, alvos, cortes = 1:11, pandemia = 2020:2022, min_anos = MIN_ANOS_SIGMA) {
  linhas <- list()
  for (t in alvos) {
    s_com <- sigma_publicado(bt, t, cortes, integer(0), min_anos)
    s_sem <- sigma_publicado(bt, t, cortes, pandemia, min_anos)
    for (i in seq_along(cortes)) {
      b <- bt[bt$ano == t & bt$corte == cortes[i], ]
      if (nrow(b) != 1 || is.na(b$previsao) || is.na(s_com[i])) next
      ic <- intervalo_80(b$previsao, s_com[i]); is <- intervalo_80(b$previsao, s_sem[i])
      linhas[[length(linhas) + 1]] <- data.frame(ano = t, corte = cortes[i], previsao = b$previsao, realizado = b$realizado,
        sigma_com = s_com[i], sigma_sem = s_sem[i], inf_com = ic$inf, sup_com = ic$sup, inf_sem = is$inf, sup_sem = is$sup,
        dentro_com = b$realizado >= ic$inf & b$realizado <= ic$sup,
        dentro_sem = if (is.na(s_sem[i])) NA else b$realizado >= is$inf & b$realizado <= is$sup)
    }
  }
  do.call(rbind, linhas)
}

#' Cobertura por faixa com Wilson 90%: por ano x corte (n = pares) e por ano (n = anos, com a fração de cortes cobertos do ano
#' como acerto; os cortes de um mesmo ano são fortemente dependentes, então esta é a leitura conservadora).
cobertura_faixas <- function(iv, coluna, faixas = FAIXAS_P1, anos_fora = integer(0)) {
  do.call(rbind, lapply(names(faixas), function(f) {
    d <- iv[iv$corte %in% faixas[[f]] & !(iv$ano %in% anos_fora) & !is.na(iv[[coluna]]), ]
    if (!nrow(d)) return(NULL)
    k <- sum(d[[coluna]]); n <- nrow(d); w <- wilson(k, n)
    por_ano <- tapply(d[[coluna]], d$ano, mean); wa <- wilson(sum(por_ano), length(por_ano))
    data.frame(faixa = f, intervalo = coluna, pares = n, cobertura = k / n, wilson_inf = w[["inf"]], wilson_sup = w[["sup"]],
               contem_80 = w[["inf"]] <= 0.8 & 0.8 <= w[["sup"]], anos = length(por_ano), cobertura_anos = mean(por_ano),
               wilson_anos_inf = wa[["inf"]], wilson_anos_sup = wa[["sup"]], contem_80_anos = wa[["inf"]] <= 0.8 & 0.8 <= wa[["sup"]])
  }))
}
