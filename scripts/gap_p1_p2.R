# E3.6: gap P1 x P2 dos estados (SGS 4643 vs Anexo 6 dos 27 UFs), classificado pela regra congelada em docs/contrato.md (30/10/2026).
# Entradas: outputs/conceito_unico_bimestral.csv, data/raw/bcb_sgs_4643_*.json (mais recente), outputs/quebras_pessoal_harmonizado.csv.
# Saidas (git-ignored): outputs/gap_estados_bimestral.csv, outputs/gap_resumo_classes.csv.
# Uso: LC_ALL=C.UTF-8 Rscript scripts/gap_p1_p2.R
source("R/utils_io.R", encoding = "UTF-8"); source("R/download/bcb_sgs.R", encoding = "UTF-8"); source("R/transform/gap_p1_p2.R", encoding = "UTF-8")
x <- ler_csv("outputs/conceito_unico_bimestral.csv")
p2 <- p2_estados_bim(x[x$exercicio >= 2018, ])
arq <- sort(list.files("data/raw", "^bcb_sgs_4643_.*\\.json$", full.names = TRUE), decreasing = TRUE)[1]
p1 <- p1_estados_bim(ler_sgs(arq)); cat("SGS 4643:", basename(arq), "\n")
h <- ler_csv("outputs/quebras_pessoal_harmonizado.csv")
exc <- aggregate(excedente ~ exercicio + periodo, h, sum)
d <- gap_bimestral(p2, p1, exc)
d <- d[!is.na(d$g), ]
cat("bimestres com gap:", nrow(d), "| de", paste(d$exercicio[1], d$periodo[1]), "a", paste(d$exercicio[nrow(d)], d$periodo[nrow(d)]), "\n")

out <- list(); res <- list()
for (v in c("com_2020_22", "sem_2020_22")) {
  ex <- if (v == "sem_2020_22") 2020:2022 else integer(0)
  cb <- classificar_gap(d, "r", ex); cs <- classificar_gap(d, "r_sem", ex)
  inf <- ifelse(d$apos_reclass & cb$classe != "excluido", "quebra_conhecida", cb$classe)
  o <- cbind(d, variante = v, classe_bruto = cb$classe, classe_sem_reclass = cs$classe, classe_informe = inf, med_ref = cb$med_ref, mad_ref = cb$mad_ref, n_ref = cb$n_ref)
  out[[v]] <- o
  res[[v]] <- rbind(cbind(variante = v, serie = "informe (bruto; quebra conhecida desde 2025 b1)", resumo_classes(inf)),
                    cbind(variante = v, serie = "bruto (sem rotulo de quebra)", resumo_classes(cb$classe)),
                    cbind(variante = v, serie = "sem reclassificacao", resumo_classes(cs$classe)))
}
o <- do.call(rbind, out); r <- do.call(rbind, res)
gravar_csv(o, "outputs/gap_estados_bimestral.csv"); gravar_csv(r, "outputs/gap_resumo_classes.csv")
print(r, row.names = FALSE)
o1 <- out$com_2020_22
cat("\nGap r (% da receita): resumo\n"); print(summary(o1$r)); cat("Degrau medio 2025+ (excedente/receita):", round(mean(o1$exc[o1$apos_reclass] / o1$rec[o1$apos_reclass]), 4), "\n")
f <- function(x) sprintf("%.1f", x * 100)
print(data.frame(ano = o1$exercicio, bim = o1$periodo, p2 = round(o1$p2, 2), p1 = round(o1$p1, 2), g = round(o1$g, 2), r_pct = f(o1$r), r_sem_pct = f(o1$r_sem),
                 bruto = o1$classe_bruto, sem_reclass = o1$classe_sem_reclass, informe = o1$classe_informe, sem2022 = out$sem_2020_22$classe_informe), row.names = FALSE)
