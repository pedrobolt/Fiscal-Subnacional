# Registro de experimentos (experiments/registro.csv): uma linha por candidato x cutoff.
# Colunas: data, candidato, parametros, amostra, corte, n, ME, MAE, RMSE, commit.
# `corte` = dados até o mês m. Valores em R$ bi (superávit positivo).

COLUNAS_REGISTRO <- c("data", "candidato", "parametros", "amostra", "corte", "n", "ME", "MAE", "RMSE", "commit")

#' Acrescenta ao registro as linhas do resumo (saída de resumir_erros) de um candidato.
#' `commit` deve ser o commit do código que gerou o resultado.
registrar_experimento <- function(resumo, candidato, parametros, amostra, commit,
                                  arquivo = "experiments/registro.csv", data = Sys.Date()) {
  r <- resumo[resumo$modelo == candidato, ]
  if (nrow(r) == 0) stop("Candidato ausente no resumo: ", candidato, call. = FALSE)
  novas <- data.frame(data = format(data), candidato = candidato, parametros = parametros,
                      amostra = amostra, corte = r$corte, n = r$n, ME = round(r$ME, 4),
                      MAE = round(r$MAE, 4), RMSE = round(r$RMSE, 4), commit = commit)
  dir.create(dirname(arquivo), showWarnings = FALSE, recursive = TRUE)
  existe <- file.exists(arquivo)
  utils::write.table(novas[, COLUNAS_REGISTRO], arquivo, sep = ",", row.names = FALSE,
                     col.names = !existe, append = existe, qmethod = "double")
  invisible(arquivo)
}
