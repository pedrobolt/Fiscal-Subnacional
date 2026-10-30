# E3.6 (cont.): teste da hipotese do RPPS. Criterio fixado em docs/nota_gap.md (secao 5) antes de calcular. Nao troca a serie oficial.
# Saidas (git-ignored): outputs/gap_rpps_bimestral.csv, gap_rpps_mediana_bimestre.csv, gap_rpps_anual.csv, gap_primeiro_classificavel.csv.
# Uso: LC_ALL=C.UTF-8 Rscript scripts/gap_rpps.R
source("R/utils_io.R", encoding = "UTF-8"); source("R/download/bcb_sgs.R", encoding = "UTF-8"); source("R/transform/gap_p1_p2.R", encoding = "UTF-8")
for (f in c("R/download/snapshots.R", "R/download/siconfi_rreo.R", "R/transform/rreo.R")) source(f, encoding = "UTF-8")
x <- ler_csv("outputs/conceito_unico_bimestral.csv"); p2 <- p2_estados_bim(x[x$exercicio >= 2018, ])
arq <- sort(list.files("data/raw", "^bcb_sgs_4643_.*\\.json$", full.names = TRUE), decreasing = TRUE)[1]
p1 <- p1_estados_bim(ler_sgs(arq))
h <- ler_csv("outputs/quebras_pessoal_harmonizado.csv"); exc <- aggregate(excedente ~ exercicio + periodo, h, sum)
cm <- p2_com_rpps_bim(ler_rreo_pasta("data/raw/rreo", "E"))
A <- gap_bimestral(p2, p1, exc); A <- A[!is.na(A$g), ]
B <- merge(A[, c("exercicio", "periodo", "p1", "exc", "p2", "rec")], cm[, c("exercicio", "periodo", "p2_com", "rec_com")], by = c("exercicio", "periodo"), all.x = TRUE)
B$p2_b <- ifelse(B$exercicio >= 2023, B$p2_com, B$p2); B$rec_b <- ifelse(B$exercicio >= 2023, B$rec_com, B$rec)
B$g_b <- B$p2_b - B$p1; B$r_b <- B$g_b / B$rec_b; B$g_b_sem <- B$g_b + B$exc; B$r_b_sem <- B$g_b_sem / B$rec_b
B$r_a <- A$r[match(paste(B$exercicio, B$periodo), paste(A$exercicio, A$periodo))]; B$g_a <- A$g[match(paste(B$exercicio, B$periodo), paste(A$exercicio, A$periodo))]
B$rec_a <- B$rec; B$r_a_sem <- A$r_sem[match(paste(B$exercicio, B$periodo), paste(A$exercicio, A$periodo))]
gravar_csv(B, "outputs/gap_rpps_bimestral.csv")
# (i) mediana por bimestre antes (2019-22) e depois (2023-24)
med <- function(r, ex, per, a, b) tapply(r[ex >= a & ex <= b], per[ex >= a & ex <= b], median)
tab <- data.frame(periodo = 1:6,
  A_antes = med(B$r_a, B$exercicio, B$periodo, 2019, 2022), A_depois = med(B$r_a, B$exercicio, B$periodo, 2023, 2024),
  B_antes = med(B$r_b, B$exercicio, B$periodo, 2019, 2022), B_depois = med(B$r_b, B$exercicio, B$periodo, 2023, 2024))
tab$A_dif <- tab$A_depois - tab$A_antes; tab$B_dif <- tab$B_depois - tab$B_antes
r2 <- B[B$exercicio >= 2023, ]
tab$A_depois_2326_sem <- tapply(r2$r_a_sem, r2$periodo, median); tab$B_depois_2326_sem <- tapply(r2$r_b_sem, r2$periodo, median)
tab$A_dif_2326_sem <- tab$A_depois_2326_sem - tab$A_antes; tab$B_dif_2326_sem <- tab$B_depois_2326_sem - tab$B_antes
gravar_csv(tab, "outputs/gap_rpps_mediana_bimestre.csv")
cat("Soma |dif| 2023-24: A =", round(sum(abs(tab$A_dif)) * 100, 2), "p.p. | B =", round(sum(abs(tab$B_dif)) * 100, 2), "p.p.\n")
cat("Soma |dif| 2023-26 sem reclass: A =", round(sum(abs(tab$A_dif_2326_sem)) * 100, 2), "| B =", round(sum(abs(tab$B_dif_2326_sem)) * 100, 2), "\n")
# (ii) gap anual
an <- do.call(rbind, lapply(split(B, B$exercicio), function(z) data.frame(exercicio = z$exercicio[1], n_bim = nrow(z),
  g_a = sum(z$g_a), g_b = sum(z$g_b), rec_a = sum(z$rec_a), rec_b = sum(z$rec_b), r_a = sum(z$g_a) / sum(z$rec_a), r_b = sum(z$g_b) / sum(z$rec_b),
  r_a_sem = sum(z$g_a + z$exc) / sum(z$rec_a), r_b_sem = sum(z$g_b_sem) / sum(z$rec_b))))
gravar_csv(an, "outputs/gap_rpps_anual.csv")
op <- options(width = 220)
cat("\nMediana de r por bimestre (%):\n"); print(cbind(periodo = tab$periodo, round(tab[, 2:7] * 100, 2)), row.names = FALSE)
cat("\nGap anual (bimestres completos; 2026 parcial):\n"); a2 <- an; a2[, c("g_a", "g_b", "rec_a", "rec_b")] <- round(a2[, c("g_a", "g_b", "rec_a", "rec_b")], 1)
a2[, c("r_a", "r_b", "r_a_sem", "r_b_sem")] <- round(a2[, c("r_a", "r_b", "r_a_sem", "r_b_sem")] * 100, 2); print(a2, row.names = FALSE)
v <- an$r_a[an$exercicio %in% 2019:2023]; w <- an$r_b[an$exercicio %in% 2019:2023]
cat("\nVariacoes anuais (p.p.): A =", paste(round(diff(v) * 100, 2), collapse = " | "), "\n                         B =", paste(round(diff(w) * 100, 2), collapse = " | "), " (19-20, 20-21, 21-22, 22-23)\n")
pc <- primeiro_classificavel(); gravar_csv(pc, "outputs/gap_primeiro_classificavel.csv"); cat("\nPrimeiro bimestre classificavel do gap bruto (quebras escalonadas):\n"); print(pc, row.names = FALSE)
