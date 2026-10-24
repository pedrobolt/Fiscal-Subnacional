# Consolidação do RREO bruto em tabela longa (E2.1/E2.4). Sem somar contas, sem interpolar, sem reclassificar.

#' Lê a versão vigente (a mais recente) de cada demonstrativo de uma esfera em `pasta` e empilha
#' (uma linha por conta x coluna). Acrescenta: `tipo_demonstrativo` ("RREO" ou "RREO Simplificado"),
#' `arquivo` (caminho relativo a `pasta`) e `baixado_em` (UTC) da versão usada.
#' Arquivos vazios (ente sem declaração) não geram linhas; a ausência aparece em cobertura_rreo().
ler_rreo_pasta <- function(pasta = "data/raw/rreo", esfera = "E") {
  arqs <- list.files(file.path(pasta, esfera), pattern = "\\.json\\.gz$", recursive = TRUE, full.names = TRUE)
  if (length(arqs) == 0) return(data.frame())
  base <- sub(paste0(PADRAO_SUFIXO_SNAPSHOT, "(\\.json\\.gz)$"), "\\1", arqs)
  vigentes <- unlist(lapply(split(arqs, base), arquivo_vigente_de_lista))
  partes <- lapply(vigentes, function(a) {
    d <- ler_rreo(a)
    if (nrow(d) == 0) return(NULL)
    d$tipo_demonstrativo <- if (grepl("_simpl(_s[0-9]{8}T[0-9]{6}Z)?\\.json\\.gz$", a)) "RREO Simplificado" else "RREO"
    d$arquivo <- substring(a, nchar(pasta) + 2)   # relativo a `pasta`
    d$baixado_em <- versao_baixado_em(a)
    d
  })
  do.call(rbind, partes)
}

#' Dentre os arquivos de um mesmo demonstrativo (base + snapshots), o mais recente.
arquivo_vigente_de_lista <- function(arqs) {
  t <- vapply(arqs, function(a) as.numeric(versao_baixado_em(a)), numeric(1))
  arqs[order(t, arqs)][length(arqs)]
}

versao_baixado_em <- function(arquivo) {
  m <- regmatches(arquivo, regexpr("_s[0-9]{8}T[0-9]{6}Z", arquivo))
  if (length(m) == 1) as.POSIXct(substring(m, 3), format = "%Y%m%dT%H%M%SZ", tz = "UTC")
  else as.POSIXct(file.mtime(arquivo), tz = "UTC")
}

#' Ids dos 27 entes estaduais a partir do arquivo de entes mais recente já baixado (sem rede).
ids_estados_local <- function(pasta = "data/raw/rreo") {
  arqs <- sort(list.files(pasta, pattern = "^_entes_.*\\.json$", full.names = TRUE))
  if (length(arqs) == 0) stop("Sem arquivo de entes em ", pasta, ": rode baixar_rreo_estados().", call. = FALSE)
  listar_estados(ler_entes(arqs[length(arqs)]))$cod_ibge
}
