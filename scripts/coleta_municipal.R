# Coleta do RREO municipal (E2.0): 6º bimestre, Anexos 1 e 6, de 2025 e 2019, todos os municípios.
# Uso (2 conexões no máximo, um processo por fatia; retomável):
#   Rscript scripts/coleta_municipal.R 1
#   Rscript scripts/coleta_municipal.R 2
source("_targets.R")
args <- commandArgs(TRUE); fatia <- as.integer(args[1])
entes <- ler_entes(baixar_entes())
ids <- sort(entes$cod_ibge[entes$esfera == "M"])
baixar_rreo_municipios(ids, c(2025, 2019), 6, ANEXOS_RREO, fatia = fatia, de = 2, tag = paste0("_coleta", fatia))
