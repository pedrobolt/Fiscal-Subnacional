# Leitura e escrita de CSV em UTF-8, independentes do locale (Windows com code page != 65001, locale C).
# read.csv/write.csv com fileEncoding convertem pelo encoding nativo e perdem texto fora dele; fread/fwrite tratam o arquivo como UTF-8.
# Formato de saida igual ao de write.csv (texto entre aspas, NA como "NA", data/hora como write.csv), para nao mudar arquivos ja versionados.

#' Le um CSV como UTF-8. `colClasses` como no fread (ex.: "character"). Retorna data.frame.
ler_csv <- function(arquivo, colClasses = NULL, ...) {
  data.table::fread(arquivo, sep = ",", encoding = "UTF-8", data.table = FALSE, colClasses = colClasses, ...)
}

#' Grava um CSV em UTF-8 sem BOM. Com `append = TRUE` acrescenta linhas sem repetir o cabecalho.
gravar_csv <- function(x, arquivo, append = FALSE) {
  anexar <- append && file.exists(arquivo)
  data.table::fwrite(x, arquivo, append = anexar, col.names = !anexar, quote = TRUE, na = "NA", row.names = FALSE, bom = FALSE,
                     dateTimeAs = "write.csv", qmethod = "double")
}

# ---- Raiz de dados (FISCAL_DADOS) ---------------------------------------------------------------------------------------------------
# Tudo o que persiste entre versoes do codigo (data/raw, snapshots, quarentena, data/processed, outputs, arquivo de previsoes, premissas.yml)
# fica sob a raiz de dados. Padrao: a pasta do repositorio (desenvolvimento). No Windows, uma vez: setx FISCAL_DADOS C:\fiscal_dados
# (cmd; vale para as janelas abertas depois). O codigo versionado (R/, scripts/, data/dicionario_*.csv) continua relativo ao repositorio.

#' Raiz de dados: a variavel de ambiente FISCAL_DADOS, ou "." (pasta de trabalho) se nao definida. Barras invertidas viram barras.
raiz_dados <- function() {
  r <- Sys.getenv("FISCAL_DADOS", unset = "")
  if (!nzchar(r)) "." else sub("/+$", "", gsub("\\\\", "/", r))
}

#' Caminho sob a raiz de dados. Com a raiz padrao devolve o caminho relativo como esta (comportamento antigo, sem "./").
dados <- function(...) {
  rel <- file.path(...)
  r <- raiz_dados()
  if (identical(r, ".")) rel else file.path(r, rel)
}

# ---- Carregador de codigo (UTF-8 em qualquer locale) --------------------------------------------------------------------------------
# source(arquivo, encoding = "UTF-8") converte para a codificacao nativa e, no Windows (code page != 65001), TRUNCA o arquivo no primeiro
# caractere fora do CP1252. Este carregador le como UTF-8 e avalia sem traducao. Usar em TODOS os scripts, no lugar de source(); o proprio
# utils_io.R e carregado com source(..., encoding = "UTF-8") e por isso so pode ter caracteres do CP1252 (um teste confere isso).

#' Carrega arquivos .R (UTF-8) em `envir`, na ordem dada. Retorna os arquivos, invisivel.
carregar_r <- function(arquivos, envir = globalenv()) {
  for (a in arquivos) {
    linhas <- readLines(a, encoding = "UTF-8", warn = FALSE)
    for (e in parse(text = linhas, keep.source = FALSE, encoding = "UTF-8")) eval(e, envir)
  }
  invisible(arquivos)
}

#' Arredonda a 1 casa, metade para cima (8,85 -> 8,9; o round/sprintf do R dariam 8,8 pela representacao binaria). Usada em todo numero de 1 casa do resumo e do texto do informe (sem -0).
arred1 <- function(x) sign(x) * floor(abs(x) * 10 + 0.5 + 1e-9) / 10 + 0
