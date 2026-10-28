# Acrescenta a coluna `status` ao experiments/registro.csv (E3.7) sem apagar linha alguma. Idempotente.
# valido: candidato da lista fechada do P1; diagnostico: fora da lista; obsoleto_pib4382: candidatos em % do PIB
# registrados em 27/10/2026 (commit 96645c6) com o PIB 12 meses do SGS 4382, vedado pelo contrato.
source("R/utils_io.R", encoding = "UTF-8")
source("R/evaluation/registro.R", encoding = "UTF-8")
arq <- "experiments/registro.csv"
d <- ler_csv(arq)
if (!("status" %in% names(d))) {
  d$status <- status_candidato(d$candidato)
  d$status[d$commit == "96645c6" & d$candidato %in% c("srw_pib", "m2", "m3")] <- "obsoleto_pib4382"
  gravar_csv(d[, COLUNAS_REGISTRO], arq)
}
print(table(d$status))
print(validar_registro(arq))
