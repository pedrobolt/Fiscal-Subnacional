# Baixa o RREO Anexo 3 (RCL) dos 27 estados, 2015-2026. Sequencial (1 conexão), retomável, log em data/raw/rreo/_log.csv.
# Uso: Rscript scripts/baixar_anexo3.R
source("R/utils_io.R", encoding = "UTF-8")
invisible(lapply(list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE), source))
entes <- ler_entes(baixar_entes("data/raw/rreo", Sys.Date()))
estados <- listar_estados(entes); stopifnot(nrow(estados) == 27)
# Amostra primeiro: uma UF (SP) por layout
invisible(baixar_rreo_lote(35, c(2015, 2018, 2019, 2022, 2024), periodos = 6, anexos = c(anexo03 = "RREO-Anexo 03")))
invisible(baixar_rreo_lote(estados$cod_ibge, 2015:2026, anexos = c(anexo03 = "RREO-Anexo 03")))
cat("fim\n")
