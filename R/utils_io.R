# Leitura e escrita de CSV em UTF-8, independentes do locale (Windows com code page != 65001, locale C).
# read.csv/write.csv com fileEncoding convertem pelo encoding nativo e perdem texto fora dele; fread/fwrite tratam o arquivo como UTF-8.
# Formato de saída igual ao de write.csv (texto entre aspas, NA como "NA", data/hora como write.csv), para não mudar arquivos já versionados.

#' Lê um CSV como UTF-8. `colClasses` como no fread (ex.: "character"). Retorna data.frame.
ler_csv <- function(arquivo, colClasses = NULL, ...) {
  data.table::fread(arquivo, sep = ",", encoding = "UTF-8", data.table = FALSE, colClasses = colClasses, ...)
}

#' Grava um CSV em UTF-8 sem BOM. Com `append = TRUE` acrescenta linhas sem repetir o cabeçalho.
gravar_csv <- function(x, arquivo, append = FALSE) {
  anexar <- append && file.exists(arquivo)
  data.table::fwrite(x, arquivo, append = anexar, col.names = !anexar, quote = TRUE, na = "NA", row.names = FALSE, bom = FALSE,
                     dateTimeAs = "write.csv", qmethod = "double")
}
