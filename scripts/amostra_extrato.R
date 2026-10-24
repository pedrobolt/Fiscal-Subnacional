# Amostra do extrato_entregas (E2.0): períodos entregues e status por município Simplificado.
source("_targets.R")
ANO <- as.integer(commandArgs(TRUE)[1])
entes <- ler_entes(baixar_entes()); m <- entes[entes$esfera == "M", ]
simpl <- Filter(function(id) isTRUE(linhas_rreo(caminho_rreo("data/raw/rreo", "M", id, ANO, 6, "RREO-Anexo 01", "RREO Simplificado")) > 0), m$cod_ibge)
cat("Simplificados", ANO, ":", length(simpl), "de", nrow(m), "\n")
set.seed(7); amostra <- sample(simpl, 120)
res <- lapply(amostra, function(id) {
  x <- jsonlite::fromJSON(sprintf("%s/extrato_entregas?id_ente=%d&an_referencia=%d", SICONFI_URL, id, ANO))$items
  r <- x[grepl("Resumido", x$entregavel), ]
  Sys.sleep(0.3)
  data.frame(id = id, n_periodos = length(unique(r$periodo)), periodos = paste(sort(unique(r$periodo)), collapse = ""),
             n_re = sum(r$status_relatorio %in% "RE"), n = nrow(r))
})
res <- do.call(rbind, res)
print(table(res$periodos)); cat("linhas RE / total:", sum(res$n_re), "/", sum(res$n), "\n")
