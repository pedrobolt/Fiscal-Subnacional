# Versões (snapshots) do bruto do RREO (E2.4).
# Arquivo existente nunca é sobrescrito. Uma retificação entra como arquivo novo com sufixo
# `_s<AAAAMMDDTHHMMSSZ>` (UTC): `123_b6_a01.json.gz` (versão original) -> `123_b6_a01_s20261101T120000Z.json.gz`.
# A versão vigente é a mais recente; a original tem como data a do arquivo (mtime).

PADRAO_SUFIXO_SNAPSHOT <- "_s[0-9]{8}T[0-9]{6}Z"

carimbo_utc <- function(momento = Sys.time()) format(momento, "%Y%m%dT%H%M%SZ", tz = "UTC")

caminho_snapshot <- function(base, momento = Sys.time()) {
  sub("\\.json\\.gz$", paste0("_s", carimbo_utc(momento), ".json.gz"), base)
}

#' Todas as versões de um demonstrativo (base + snapshots), da mais antiga para a mais recente.
#' Retorna data.frame(arquivo, baixado_em [POSIXct UTC]); vazio se não houver nenhuma.
versoes_rreo <- function(base) {
  vazio <- data.frame(arquivo = character(0), baixado_em = as.POSIXct(character(0), tz = "UTC"))
  dir <- dirname(base)
  if (!dir.exists(dir)) return(vazio)
  stem <- sub("\\.json\\.gz$", "", basename(base))
  arqs <- list.files(dir, pattern = paste0("^", stem, "(", PADRAO_SUFIXO_SNAPSHOT, ")?\\.json\\.gz$"), full.names = TRUE)
  if (length(arqs) == 0) return(vazio)
  quando <- vapply(arqs, function(a) {
    m <- regmatches(a, regexpr("_s[0-9]{8}T[0-9]{6}Z", a))
    if (length(m) == 1) as.numeric(as.POSIXct(substring(m, 3), format = "%Y%m%dT%H%M%SZ", tz = "UTC"))
    else as.numeric(file.mtime(a))
  }, numeric(1))
  out <- data.frame(arquivo = arqs, baixado_em = as.POSIXct(quando, origin = "1970-01-01", tz = "UTC"), row.names = NULL)
  out[order(out$baixado_em, out$arquivo), ]
}

#' Caminho da versão vigente (mais recente) ou NA.
arquivo_vigente <- function(base) {
  v <- versoes_rreo(base)
  if (nrow(v) == 0) NA_character_ else v$arquivo[nrow(v)]
}

baixado_em_vigente <- function(base) {
  v <- versoes_rreo(base)
  if (nrow(v) == 0) as.POSIXct(NA, tz = "UTC") else v$baixado_em[nrow(v)]
}

#' Versão vigente do demonstrativo de um ente (ou NA).
vigente_rreo <- function(pasta, esfera, id_ente, ano, periodo, anexo, tipo = "RREO") {
  arquivo_vigente(caminho_rreo(pasta, esfera, id_ente, ano, periodo, anexo, tipo))
}
