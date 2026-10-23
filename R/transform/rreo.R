# Consolidação do RREO bruto em tabela longa (E2.1). Sem somar contas, sem interpolar, sem reclassificar.

#' Lê todos os arquivos do RREO de uma esfera em `pasta` e empilha (uma linha por conta x coluna).
#' Arquivos vazios (ente sem declaração) não geram linhas; a ausência aparece em cobertura_rreo().
ler_rreo_pasta <- function(pasta = "data/raw/rreo", esfera = "E") {
  arqs <- list.files(file.path(pasta, esfera), pattern = "\\.json\\.gz$", recursive = TRUE, full.names = TRUE)
  if (length(arqs) == 0) return(data.frame())
  do.call(rbind, lapply(arqs, ler_rreo))
}

#' Ids dos 27 entes estaduais a partir do arquivo de entes mais recente já baixado (sem rede).
ids_estados_local <- function(pasta = "data/raw/rreo") {
  arqs <- sort(list.files(pasta, pattern = "^_entes_.*\\.json$", full.names = TRUE))
  if (length(arqs) == 0) stop("Sem arquivo de entes em ", pasta, ": rode baixar_rreo_estados().", call. = FALSE)
  listar_estados(ler_entes(arqs[length(arqs)]))$cod_ibge
}
