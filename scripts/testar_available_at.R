# Aplica available_at_rreo() ao extrato real dos estados e resume a defasagem (E3.7 / insumo da E2.7).
# Uso: Rscript scripts/testar_available_at.R   (requer scripts/extrato_estados.R já executado)
invisible(lapply(list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE), source))
pasta <- "data/raw/rreo"
ids <- ids_estados_local(pasta)
ext <- do.call(rbind, lapply(2015:as.integer(format(Sys.Date(), "%Y")), function(a) do.call(rbind, lapply(ids, function(id) {
  v <- extrato_vigente(pasta, id, a)
  if (nrow(v) == 0) return(NULL)
  e <- ler_extrato(v$arquivo); if (nrow(e) == 0) return(NULL)
  e$uf <- id; e
}))))
if (is.null(ext)) stop("Extrato ausente: rode scripts/extrato_estados.R", call. = FALSE)
ext <- ext[ext$tipo == "RREO" & ext$periodo %in% 1:6, ]
cat("Entregas:", nrow(ext), "| HO:", sum(ext$status == "HO"), "| RE:", sum(ext$status == "RE"), "\n")
r <- available_at_rreo(ext)
print(table(r$fonte_available_at))
fim <- as.Date(sprintf("%d-%02d-01", r$exercicio, 2 * r$periodo)); fim <- as.Date(vapply(fim, function(d) as.numeric(seq(d, by = "month", length.out = 2)[2] - 1), numeric(1)), origin = "1970-01-01")
r$atraso_dias <- as.numeric(r$available_at - (fim + 30))
cat("\nAtraso (available_at - prazo legal), dias, por período (todos / só HO):\n")
print(do.call(rbind, lapply(1:6, function(p) { x <- r$atraso_dias[r$periodo == p]; h <- r$atraso_dias[r$periodo == p & r$status == "HO"]
  data.frame(periodo = p, n = length(x), mediana = median(x), p90 = unname(quantile(x, .9)), n_HO = length(h), mediana_HO = median(h), pct_apos_prazo_HO = round(100 * mean(h > 0), 1)) })))
cat("\nFração RE por ano:\n"); print(round(tapply(r$status == "RE", r$exercicio, mean), 2))
utils::write.csv(fileEncoding = "UTF-8", r[, c("uf", "exercicio", "periodo", "status", "data_status", "available_at", "fonte_available_at", "atraso_dias")], "outputs/available_at_rreo_estados.csv", row.names = FALSE)
