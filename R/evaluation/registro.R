# Registro de experimentos (experiments/registro.csv): uma linha por candidato x cutoff.
# Colunas: data, candidato, parametros, amostra, corte, n, ME, MAE, RMSE, commit, status.
# `status`: valido (candidato da lista fechada do P1, método vigente), diagnostico (fora da lista fechada) ou
# obsoleto_pib4382 (calculado com o PIB 12 meses do SGS 4382, vedado pelo contrato). Linhas nunca são apagadas.
# `corte` = dados até o mês m. Valores em R$ bi (superávit positivo).

COLUNAS_REGISTRO <- c("data", "candidato", "parametros", "amostra", "corte", "n", "ME", "MAE", "RMSE", "commit", "status")
STATUS_REGISTRO <- c("valido", "diagnostico", "obsoleto_pib4382", "obsoleto_execucao_incompleta", "obsoleto_leitor_stn")

# Lista fechada do P1 (contrato, 27/10/2026): K = 9 = base + 8 desafiantes. Nomes usados no registro; os desafiantes
# ainda não implementados entram por prefixo (e41_, fpe_fpm_, ldo_, combinacao).
LISTA_P1 <- c("srw_brl", "srw_pib", "acumulado_j5", "m2", "m3", "e41", "fpe_fpm", "ldo", "combinacao")
K_P1 <- length(LISTA_P1)
NOMES_P1_ALIAS <- c(srw = "srw_brl", acumulado = "acumulado_j5")   # nomes antigos do registro

#' O candidato pertence à lista fechada do P1? (por nome exato ou prefixo dos desafiantes futuros)
na_lista_p1 <- function(candidato) {
  nome <- ifelse(candidato %in% names(NOMES_P1_ALIAS), NOMES_P1_ALIAS[candidato], candidato)
  vapply(nome, function(n) n %in% LISTA_P1 || any(startsWith(n, paste0(c("e41", "fpe_fpm", "ldo", "combinacao"), "_"))), logical(1), USE.NAMES = FALSE)
}
status_candidato <- function(candidato) ifelse(na_lista_p1(candidato), "valido", "diagnostico")

#' Acrescenta ao registro as linhas do resumo (saída de resumir_erros) de um candidato.
#' `commit` deve ser o commit do código que gerou o resultado.
registrar_experimento <- function(resumo, candidato, parametros, amostra, commit,
                                  arquivo = "experiments/registro.csv", data = Sys.Date(), status = status_candidato(candidato)) {
  r <- resumo[resumo$modelo == candidato, ]
  if (nrow(r) == 0) stop("Candidato ausente no resumo: ", candidato, call. = FALSE)
  novas <- data.frame(data = format(data), candidato = candidato, parametros = parametros,
                      amostra = amostra, corte = r$corte, n = r$n, ME = round(r$ME, 4),
                      MAE = round(r$MAE, 4), RMSE = round(r$RMSE, 4), commit = commit, status = status)
  dir.create(dirname(arquivo), showWarnings = FALSE, recursive = TRUE)
  existe <- file.exists(arquivo)
  utils::write.table(novas[, COLUNAS_REGISTRO], arquivo, sep = ",", row.names = FALSE,
                     col.names = !existe, append = existe, qmethod = "double")
  invisible(arquivo)
}

#' Valida o registro de experimentos. Retorna data.frame(linha, problema); vazio = sem problemas.
#' Checa: colunas, status permitido, candidato `valido` dentro da lista fechada, amostra preenchida, corte 1-11,
#' métricas numéricas (MAE e RMSE >= 0), linhas duplicadas (candidato x parametros x amostra x corte x commit) e, se
#' `checar_git`, que o commit existe no repositório.
validar_registro <- function(arquivo = "experiments/registro.csv", checar_git = TRUE) {
  d <- utils::read.csv(arquivo, stringsAsFactors = FALSE)
  prob <- function(i, txt) if (length(i)) data.frame(linha = i + 1L, problema = txt) else NULL
  out <- list()
  if (!identical(names(d), COLUNAS_REGISTRO)) {
    return(data.frame(linha = 0L, problema = paste("colunas diferentes de", paste(COLUNAS_REGISTRO, collapse = ","))))
  }
  out[[1]] <- prob(which(!(d$status %in% STATUS_REGISTRO)), paste("status fora de", paste(STATUS_REGISTRO, collapse = "/")))
  out[[2]] <- prob(which(d$status == "valido" & !na_lista_p1(d$candidato)), "status valido para candidato fora da lista fechada")
  out[[3]] <- prob(which(is.na(d$amostra) | d$amostra == ""), "amostra vazia")
  out[[4]] <- prob(which(!(d$corte %in% 1:11)), "corte fora de 1-11")
  out[[5]] <- prob(which(!is.finite(d$ME) | !is.finite(d$MAE) | !is.finite(d$RMSE) | d$MAE < 0 | d$RMSE < 0), "métrica inválida")
  chave <- paste(d$candidato, d$parametros, d$amostra, d$corte, d$commit, sep = "|")
  out[[6]] <- prob(which(duplicated(chave)), "linha duplicada (candidato, parametros, amostra, corte, commit)")
  if (checar_git) {
    ok <- vapply(unique(d$commit), function(h) !is.na(h) && nzchar(h) &&
                   suppressWarnings(system2("git", c("cat-file", "-e", paste0(h, "^{commit}")), stdout = FALSE, stderr = FALSE)) == 0, logical(1))
    ruins <- unique(d$commit)[!ok]
    out[[7]] <- prob(which(d$commit %in% ruins), "commit inexistente no repositório")
  }
  r <- do.call(rbind, out)
  if (is.null(r)) data.frame(linha = integer(0), problema = character(0)) else r
}
