# Consolidação do RREO bruto em tabela longa (E2.1/E2.4). Sem somar contas, sem interpolar, sem reclassificar.

#' Lê a versão vigente (a mais recente) de cada demonstrativo de uma esfera em `pasta` e empilha
#' (uma linha por conta x coluna). Acrescenta: `tipo_demonstrativo` ("RREO" ou "RREO Simplificado"),
#' `arquivo` (caminho relativo a `pasta`), `baixado_em` (UTC) da versão usada e `baixado_em_fonte`
#' ("nome", "log" ou "mtime"; ver `datas_versoes`).
#' Arquivos vazios (ente sem declaração) não geram linhas; a ausência aparece em cobertura_rreo().
ler_rreo_pasta <- function(pasta = "data/raw/rreo", esfera = "E") {
  arqs <- list.files(file.path(pasta, esfera), pattern = "\\.json\\.gz$", recursive = TRUE, full.names = TRUE)
  if (length(arqs) == 0) return(data.frame())
  base <- sub(paste0(PADRAO_SUFIXO_SNAPSHOT, "(\\.json\\.gz)$"), "\\1", arqs)
  vigentes <- vapply(split(arqs, base), function(x) { sn <- sort(x[grepl(PADRAO_SUFIXO_SNAPSHOT, x)]); if (length(sn)) sn[length(sn)] else x[1] }, character(1))
  datas <- datas_versoes(unname(vigentes), pasta)
  datas$arquivo <- unname(vigentes)
  partes <- lapply(vigentes, function(a) {
    d <- ler_rreo(a)
    if (nrow(d) == 0) return(NULL)
    d$tipo_demonstrativo <- if (grepl("_simpl(_s[0-9]{8}T[0-9]{6}Z)?\\.json\\.gz$", a)) "RREO Simplificado" else "RREO"
    d$arquivo <- substring(a, nchar(pasta) + 2)   # relativo a `pasta`
    k <- match(a, datas$arquivo)
    d$baixado_em <- datas$baixado_em[k]
    d$baixado_em_fonte <- datas$fonte[k]
    d
  })
  do.call(rbind, partes)
}

#' Ids dos 27 entes estaduais a partir do arquivo de entes mais recente já baixado (sem rede).
ids_estados_local <- function(pasta = "data/raw/rreo") {
  arqs <- sort(list.files(pasta, pattern = "^_entes_.*\\.json$", full.names = TRUE))
  if (length(arqs) == 0) stop("Sem arquivo de entes em ", pasta, ": rode baixar_rreo_estados().", call. = FALSE)
  listar_estados(ler_entes(arqs[length(arqs)]))$cod_ibge
}
