# Baixa o extrato_entregas dos 27 estados, 2015 até o ano corrente (1 conexão; retoma: extrato com até 7 dias é reaproveitado).
# Uso: Rscript scripts/extrato_estados.R
source("_targets.R")
ids <- ids_estados_local()
anos <- 2015:as.integer(format(Sys.Date(), "%Y"))
n <- 0
for (a in anos) for (id in ids) {
  tryCatch(extrato_atualizado("data/raw/rreo", id, a), error = function(e) message("falha ", id, "/", a, ": ", conditionMessage(e)))
  n <- n + 1; if (n %% 50 == 0) cat(n, "de", length(ids) * length(anos), "\n")
}
cat("Extrato dos estados concluído.\n")
