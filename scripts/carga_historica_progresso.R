# Relatório de progresso da carga histórica (não faz chamadas à API). Rodar a qualquer momento:
#   Rscript scripts/carga_historica_progresso.R
source("_targets.R")
p <- progresso_carga()
print(p, row.names = FALSE)
r <- attr(p, "resumo")
cat(sprintf("\nChamadas restantes (estimativa): %s\nRitmo da última hora: %s chamadas/s\nTempo restante (estimativa): %s h\n",
            format(round(r$chamadas_restantes), big.mark = "."),
            ifelse(is.na(r$chamadas_por_s_ultima_hora), "n/d", round(r$chamadas_por_s_ultima_hora, 2)),
            ifelse(is.na(r$horas_restantes), "n/d", round(r$horas_restantes, 1))))
