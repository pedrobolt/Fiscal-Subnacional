# Baixa o RREO Anexo 4 (receitas e despesas previdenciarias do RPPS) dos 27 estados, 6o bimestre (acumulado anual), 2019-2024.
# Sequencial (1 conexao), retomavel, log em data/raw/rreo/_log.csv. Uso: Rscript scripts/baixar_anexo4.R
source("R/utils_io.R", encoding = "UTF-8")
invisible(lapply(list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE), source))
entes <- ler_entes(baixar_entes("data/raw/rreo", Sys.Date()))
estados <- listar_estados(entes); stopifnot(nrow(estados) == 27)
invisible(baixar_rreo_lote(estados$cod_ibge, 2019:2024, periodos = 6, anexos = c(anexo04 = "RREO-Anexo 04")))
cat("fim\n")
