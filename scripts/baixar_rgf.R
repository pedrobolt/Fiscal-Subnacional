# Baixa o RGF Anexo 01 (pessoal) do Executivo dos 27 estados, 2015 em diante (1 conexão, retomável). Uso: Rscript scripts/baixar_rgf.R
source("R/utils_io.R", encoding = "UTF-8")
carregar_r(list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE))
baixar_rgf_estados(); cat("fim\n")
