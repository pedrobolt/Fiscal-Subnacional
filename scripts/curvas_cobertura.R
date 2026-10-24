# Curvas de cobertura municipal (E2.0): 2025 e 2019, 6º bimestre. Saídas em outputs/ (não versionado).
source("_targets.R")
entes <- ler_entes(baixar_entes()); m <- entes[entes$esfera == "M", ]
b <- lapply(c(`2025` = 2025, `2019` = 2019), function(a) montar_base_municipal(m, a))
saveRDS(b, "outputs/base_municipal_cobertura.rds")
for (a in names(b)) {
  d <- b[[a]]
  cat("\n==== ", a, " ====\n")
  cat("com dados:", sum(!is.na(d$tipo)), " RREO:", sum(d$tipo %in% "RREO"), " Simplificado:", sum(d$tipo %in% "RREO Simplificado"),
      " sem dados:", sum(is.na(d$tipo)), "\n")
  cat("receita NA entre os com tipo:", sum(is.na(d$receita) & !is.na(d$tipo)), " primario NA entre os com tipo:", sum(is.na(d$primario) & !is.na(d$tipo)), "\n")
  print(table(tipo = d$tipo, primario_NA = is.na(d$primario), useNA = "ifany"))
}
