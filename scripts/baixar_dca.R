# Baixa a DCA Anexo I-C dos 27 estados, 2015-2025 (1 conexão, retomável). Uso: Rscript scripts/baixar_dca.R
source("R/utils_io.R", encoding = "UTF-8")
invisible(lapply(list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE), source))
baixar_dca_estados(); cat("fim\n")
