# Manifesto do bruto do RREO (E2.0): lista de arquivos com tamanho e MD5, contagens e datas de coleta.
# Usado para empacotar o Release e para conferir a carga inicial (scripts/empacotar_dados.R e restaurar_dados.R).

manifesto_arquivos <- function(pasta = "data/raw/rreo") {
  arqs <- sort(list.files(pasta, recursive = TRUE, full.names = FALSE))
  completos <- file.path(pasta, arqs)
  data.frame(arquivo = arqs, bytes = file.size(completos),
             md5 = unname(tools::md5sum(completos)), stringsAsFactors = FALSE)
}

#' Resumo do manifesto: contagem por esfera e ano (arquivos .json.gz) e datas de coleta (a partir dos logs).
resumo_manifesto <- function(man, pasta = "data/raw/rreo", commit = NA_character_, invalidos = NA_integer_) {
  j <- man[grepl("\\.json\\.gz$", man$arquivo), ]
  partes <- strsplit(j$arquivo, "/")
  esfera <- vapply(partes, `[`, "", 1); ano <- vapply(partes, `[`, "", 2)
  cont <- table(esfera, ano)
  logs <- list.files(pasta, pattern = "^_log.*\\.csv$", full.names = TRUE)
  momentos <- unlist(lapply(logs, function(f) { x <- utils::read.csv(f, colClasses = "character"); momento_log_numerico(x$momento) }))
  list(criado_em = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), commit_codigo = commit,
       arquivos = nrow(man), arquivos_json_gz = nrow(j), bytes_total = sum(man$bytes),
       arquivos_invalidos_na_validacao = invalidos,
       contagem_por_esfera_ano = as.list(apply(cont, 1, function(r) as.list(r))),
       coleta_inicio = if (length(momentos)) format(as.POSIXct(min(momentos, na.rm = TRUE), origin = "1970-01-01", tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ") else NA,
       coleta_fim = if (length(momentos)) format(as.POSIXct(max(momentos, na.rm = TRUE), origin = "1970-01-01", tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ") else NA,
       chamadas_registradas = length(momentos))
}
