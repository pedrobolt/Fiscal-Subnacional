# E3.6 (cont.): fluxo liquido do RPPS pelo Anexo 4 (2019-2024, 27 UFs, 6o bimestre) contra "com - sem RPPS" do Anexo 6 (2023-24).
# Entradas: data/raw/rreo (Anexo 4, scripts/baixar_anexo4.R) e outputs/gap_rpps_anual.csv. Saidas (git-ignored): outputs/rpps_a4_uf.csv, rpps_a4_anual.csv.
# Uso: LC_ALL=C.UTF-8 Rscript scripts/rpps_anexo4.R
source("R/utils_io.R", encoding = "UTF-8"); source("R/transform/rpps_anexo4.R", encoding = "UTF-8")
for (f in c("R/download/snapshots.R", "R/download/siconfi_rreo.R", "R/transform/rreo.R")) source(f, encoding = "UTF-8")
r <- ler_rreo_pasta("data/raw/rreo", "E"); r <- r[r$anexo == "RREO-Anexo 04" & r$exercicio %in% 2019:2024, ]
d <- rpps_liquido_a4(r); gravar_csv(d, "outputs/rpps_a4_uf.csv")
ok <- !is.na(d$liquido)
an <- do.call(rbind, lapply(split(d, d$exercicio), function(z) data.frame(exercicio = z$exercicio[1], ufs_com_dado = sum(!is.na(z$liquido)),
  rec = sum(z$rec, na.rm = TRUE) / 1e9, desp_liquidada = sum(z$desp_liquidada, na.rm = TRUE) / 1e9, liquido = sum(z$liquido, na.rm = TRUE) / 1e9,
  liquido_pago = if (all(is.na(z$liquido_pago))) NA_real_ else sum(z$liquido_pago, na.rm = TRUE) / 1e9, ufs_pago = sum(!is.na(z$liquido_pago)),
  rendimentos = sum(z$rendimentos, na.rm = TRUE) / 1e9, aportes = sum(z$aportes, na.rm = TRUE) / 1e9, liquido_consolidado = sum(z$liquido_consolidado, na.rm = TRUE) / 1e9, ufs_com_aporte = sum(z$aportes > 0), liquido_sem_rendimentos = sum(z$liquido_sem_rendimentos, na.rm = TRUE) / 1e9)))
g <- ler_csv("outputs/gap_rpps_anual.csv"); an$a6_com_menos_sem <- ifelse(an$exercicio >= 2023, (g$g_b - g$g_a)[match(an$exercicio, g$exercicio)], NA_real_)
gravar_csv(an, "outputs/rpps_a4_anual.csv"); options(width = 200); print(round(an, 1), row.names = FALSE)
cat("\nUFs sem dado de liquido por ano:\n"); print(tapply(is.na(d$liquido), d$exercicio, sum))
cat("\nMaiores contribuicoes (liquido, R$ bi) em 2023:\n"); z <- d[d$exercicio == 2023, ]; z <- z[order(z$liquido), c("cod_ibge", "rec", "desp_liquidada", "liquido")]; z[, 2:4] <- round(z[, 2:4] / 1e9, 2); print(head(z, 6), row.names = FALSE); print(tail(z, 4), row.names = FALSE)

# Corte transversal por UF (2023 e 2024): "com - sem RPPS" do Anexo 6 (XXXIV - XXXV, 6o bimestre) contra o liquido do Anexo 4.
a6 <- ler_rreo_pasta("data/raw/rreo", "E"); a6 <- a6[a6$anexo == "RREO-Anexo 06" & a6$periodo == 6L & a6$exercicio %in% 2023:2024 &
        a6$cod_conta %in% c("ResultadoPrimarioComRPPSAcimaDaLinha", "ResultadoPrimarioSemRPPSAcimaDaLinha") & a6$coluna == "VALOR", ]
a6 <- a6[order(a6$baixado_em), ]; a6 <- a6[!duplicated(a6[, c("cod_ibge", "exercicio", "cod_conta")], fromLast = TRUE), ]
w <- reshape(a6[, c("cod_ibge", "exercicio", "cod_conta", "valor")], idvar = c("cod_ibge", "exercicio"), timevar = "cod_conta", direction = "wide")
w$a6_dif <- (w$valor.ResultadoPrimarioComRPPSAcimaDaLinha - w$valor.ResultadoPrimarioSemRPPSAcimaDaLinha) / 1e9
x <- merge(w[, c("cod_ibge", "exercicio", "a6_dif")], d, by = c("cod_ibge", "exercicio")); x$liq <- x$liquido / 1e9; x$cons <- x$liquido_consolidado / 1e9
gravar_csv(x, "outputs/rpps_a4_a6_uf.csv")
cat("\nCorte transversal (27 UFs por ano): a6_dif ~ A4\n")
for (ex in 2023:2024) { z <- x[x$exercicio == ex, ]
  for (v in c("liq", "cons")) { m <- lm(z$a6_dif ~ z[[v]]); cat(ex, v, "| inclinacao", round(coef(m)[2], 2), "| R2", round(summary(m)$r.squared, 2), "| soma A6", round(sum(z$a6_dif), 1), "| soma A4", round(sum(z[[v]]), 1), "\n") } }
