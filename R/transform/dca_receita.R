# DCA Anexo I-C dos estados: receita bruta e deduções por imposto. Os códigos de conta mudam com a classificação
# (2015-17, 2018-2021 e 2022+); a conta é identificada pelo código sem o prefixo "RO"/"RO ".
CODIGOS_DCA <- list(
  ICMS = c("1.1.1.3.00.00.00", "1.1.1.8.02.0.0", "1.1.1.4.50.0.0"),
  IPVA = c("1.1.1.2.05.00.00", "1.1.1.8.01.2.0", "1.1.1.2.51.0.0"),
  ITCD = c("1.1.1.2.07.00.00", "1.1.1.8.01.3.0", "1.1.1.2.52.0.0"),
  FPE  = c("1.7.2.1.01.01.00", "1.7.1.8.01.1.0", "1.7.1.1.50.0.0"))

#' Lê a DCA dos estados (pasta data/raw/dca/E) e devolve, por UF x ano x imposto, bruto e deduções.
ler_dca_impostos <- function(pasta = "data/raw/dca") {
  arqs <- list.files(file.path(pasta, "E"), "_i_c\\.json\\.gz$", recursive = TRUE, full.names = TRUE)
  cod2cat <- unlist(lapply(names(CODIGOS_DCA), function(n) setNames(rep(n, length(CODIGOS_DCA[[n]])), CODIGOS_DCA[[n]])))
  out <- lapply(arqs, function(a) {
    x <- ler_dca(a); x$cod <- sub("^RO ?", "", x$cod_conta); x <- x[x$cod %in% names(cod2cat), ]
    if (!NROW(x)) return(NULL)
    x$categoria <- unname(cod2cat[x$cod])
    x[, c("cod_ibge", "uf", "exercicio", "categoria", "cod", "coluna", "valor")]
  })
  do.call(rbind, out)
}
