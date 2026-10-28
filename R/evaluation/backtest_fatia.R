# Backtest de evento fixo da fatia mínima (E1.5): erro do total anual por mês de cutoff.
# Cutoff m = dados publicados até o mês m do ano-alvo (m = 12 é o próprio realizado, fica fora).
# Limitação declarada: usa o histórico atual do BCB (revisado), sem `available_at` (vem na E3).

total_anual <- function(serie, ano) soma_meses(serie, ano, 1:12)

rodar_backtest <- function(serie, anos = 2016:2025, cortes = 1:11, modelos = MODELOS_FATIA) {
  linhas <- list()
  for (ano in anos) {
    real <- total_anual(serie, ano)
    if (is.na(real)) next
    for (m in cortes) {
      for (nome in names(modelos)) {
        prev <- modelos[[nome]](serie, ano, m)
        linhas[[length(linhas) + 1]] <- data.frame(
          ano = ano, corte = m, modelo = nome, previsao = prev, realizado = real, erro = prev - real)
      }
    }
  }
  do.call(rbind, linhas)
}

#' ME (viés), MAE e RMSE em R$ bi, por modelo e por mês de cutoff.
resumir_erros <- function(bt) {
  bt <- bt[!is.na(bt$erro), ]
  agg <- function(d) data.frame(n = nrow(d), ME = mean(d$erro), MAE = mean(abs(d$erro)),
                                RMSE = sqrt(mean(d$erro^2)))
  partes <- split(bt, list(bt$modelo, bt$corte), drop = TRUE)
  out <- do.call(rbind, lapply(partes, function(d) cbind(modelo = d$modelo[1], corte = d$corte[1], agg(d))))
  rownames(out) <- NULL
  out[order(out$corte, out$modelo), ]
}

#' Previsão do ano corrente com a informação disponível hoje (último mês publicado do ano_t).
prever_ano_corrente <- function(serie, ano_t, modelos = MODELOS_FATIA) {
  meses <- as.integer(format(serie$data[as.integer(format(serie$data, "%Y")) == ano_t], "%m"))
  if (length(meses) == 0) stop("Sem dados de ", ano_t, " na série.", call. = FALSE)
  m <- max(meses)
  if (m == 12) {
    return(data.frame(ano = ano_t, corte = 12, modelo = "realizado", previsao = total_anual(serie, ano_t)))
  }
  do.call(rbind, lapply(names(modelos), function(n)
    data.frame(ano = ano_t, corte = m, modelo = n, previsao = modelos[[n]](serie, ano_t, m))))
}

#' Acrescenta % do PIB usando o PIB nominal do ano t das premissas (contrato, "Unidades de saída").
com_pct_pib <- function(previsao, premissas) {
  pib <- premissas$anos$pib_nominal[match(previsao$ano, premissas$anos$ano)]
  previsao$pct_pib <- 100 * previsao$previsao / pib
  previsao
}

#' Grava as tabelas em outputs/ (não versionado). Retorna os caminhos.
gravar_saidas_fatia <- function(bt, resumo, previsao, pasta = "outputs") {
  dir.create(pasta, showWarnings = FALSE, recursive = TRUE)
  arqs <- c(file.path(pasta, "fatia_erros.csv"), file.path(pasta, "fatia_resumo.csv"),
            file.path(pasta, "fatia_previsao_ano_corrente.csv"))
  utils::write.csv(fileEncoding = "UTF-8", bt, arqs[1], row.names = FALSE)
  utils::write.csv(fileEncoding = "UTF-8", resumo, arqs[2], row.names = FALSE)
  utils::write.csv(fileEncoding = "UTF-8", previsao, arqs[3], row.names = FALSE)
  arqs
}
