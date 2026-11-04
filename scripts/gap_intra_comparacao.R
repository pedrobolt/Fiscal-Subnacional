# Quanto o gap P1 x P2 muda com o P2 consolidado (sem intraorcamentarias de 2023 em diante). Le gap.csv (consolidado) e gap_bruto.csv de uma rodada.
# Uso: LC_ALL=C.UTF-8 Rscript scripts/gap_intra_comparacao.R [pasta da rodada, ex.: outputs/teste/rodada/2026-11-04]
source("R/utils_io.R", encoding = "UTF-8")
carregar_r("R/transform/gap_p1_p2.R")
a <- commandArgs(TRUE); pasta <- if (length(a)) a[1] else dados("outputs/teste/rodada/2026-11-04")
h <- ler_csv(file.path(pasta, "gap.csv")); b <- ler_csv(file.path(pasta, "gap_bruto.csv"))
b$apos_reclass <- b$exercicio > GAP_INICIO_RECLASS[1] | (b$exercicio == GAP_INICIO_RECLASS[1] & b$periodo >= GAP_INICIO_RECLASS[2])
rot <- function(d, ex) { cb <- classificar_gap(d, "r", ex); ifelse(d$apos_reclass & cb$classe != "excluido", "quebra_conhecida", cb$classe) }
b$classe_informe <- rot(b, integer(0)); b$classe_sem_2020_22 <- rot(b, 2020:2022)
m <- merge(b[, c("exercicio", "periodo", "p2", "g", "r", "classe_informe", "classe_sem_2020_22")], h[, c("exercicio", "periodo", "p2", "g", "r", "classe_informe", "classe_sem_2020_22")],
           by = c("exercicio", "periodo"), suffixes = c("_bruto", "_consol"))
m$dif_g <- m$g_consol - m$g_bruto; m$dif_r_pp <- 100 * (m$r_consol - m$r_bruto)
gravar_csv(m, dados("outputs/gap_intra_comparacao.csv"))
cat("==== Gap P1 x P2 dos estados: bruto (com intra de 2023+) x consolidado ====\n")
res <- do.call(rbind, lapply(split(m, m$exercicio), function(d) data.frame(exercicio = d$exercicio[1], n_bim = nrow(d), gap_medio_bruto_bi = round(mean(d$g_bruto), 2), gap_medio_consol_bi = round(mean(d$g_consol), 2),
  dif_media_bi = round(mean(d$dif_g), 2), dif_media_abs_bi = round(mean(abs(d$dif_g)), 2), dif_r_media_pp = round(mean(d$dif_r_pp), 2),
  muda_classe = sum(d$classe_informe_bruto != d$classe_informe_consol), muda_classe_sem_2020_22 = sum(d$classe_sem_2020_22_bruto != d$classe_sem_2020_22_consol))))
print(res, row.names = FALSE)
cat("\nBimestres de 2026:\n"); print(transform(m[m$exercicio == 2026, c("exercicio", "periodo", "g_bruto", "g_consol", "r_bruto", "r_consol", "classe_informe_bruto", "classe_informe_consol")],
  g_bruto = round(g_bruto, 2), g_consol = round(g_consol, 2), r_bruto = round(100 * r_bruto, 2), r_consol = round(100 * r_consol, 2)), row.names = FALSE)
cat("\nBimestres cuja classe do informe muda:\n"); print(m[m$classe_informe_bruto != m$classe_informe_consol, c("exercicio", "periodo", "classe_informe_bruto", "classe_informe_consol")], row.names = FALSE)
