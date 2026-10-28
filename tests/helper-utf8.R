# Carrega arquivos R em UTF-8 sem depender do locale (Windows com code page != 65001, ou locale C).
# source(encoding = "UTF-8") falha em locale C; aqui o texto é lido como UTF-8 e avaliado sem tradução.
source_utf8 <- function(arquivo, envir = globalenv()) {
  linhas <- readLines(arquivo, encoding = "UTF-8", warn = FALSE)
  for (e in parse(text = linhas, keep.source = FALSE, encoding = "UTF-8")) eval(e, envir)
  invisible(NULL)
}

source_utf8("../R/utils_io.R")

# Grava um JSON (texto) como .gz em bytes UTF-8, sem passar pelo encoding nativo (fixtures iguais em qualquer locale).
grava_gz_utf8 <- function(json, arquivo) {
  dir.create(dirname(arquivo), showWarnings = FALSE, recursive = TRUE)
  con <- gzfile(arquivo, "wb"); on.exit(close(con))
  writeBin(charToRaw(enc2utf8(as.character(json))), con)
  invisible(arquivo)
}
