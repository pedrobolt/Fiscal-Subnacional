# Carrega arquivos R em UTF-8 sem depender do locale (Windows com code page != 65001, ou locale C).
# source(encoding = "UTF-8") falha em locale C; aqui o texto é lido como UTF-8 e avaliado sem tradução.
source_utf8 <- function(arquivo, envir = globalenv()) {
  linhas <- readLines(arquivo, encoding = "UTF-8", warn = FALSE)
  for (e in parse(text = linhas, keep.source = FALSE, encoding = "UTF-8")) eval(e, envir)
  invisible(NULL)
}
