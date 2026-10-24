# Carga histórica do RREO (E2.5). Rodar em DOIS terminais (2 conexões, o máximo autorizado), na raiz do repositório:
#   Rscript scripts/carga_historica.R 1
#   Rscript scripts/carga_historica.R 2
# Retomável: interrompeu (fechou o terminal, queda de energia ou de rede)? Basta rodar de novo.
# Progresso: Rscript scripts/carga_historica_progresso.R
source("_targets.R")
fatia <- as.integer(commandArgs(TRUE)[1])
if (is.na(fatia) || !(fatia %in% 1:2)) stop("Uso: Rscript scripts/carga_historica.R 1   (ou 2)")
executar_carga(fatia)
cat("Fatia", fatia, "concluída.\n")
