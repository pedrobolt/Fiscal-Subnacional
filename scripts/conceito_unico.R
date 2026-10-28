# Conceito único de receita/despesa do Anexo 6 dos estados (receita líquida de FUNDEB e cota-parte; despesa sem esses repasses),
# com os testes que validam o ajuste. Entradas: Anexos 3 e 6 (data/raw/rreo/E), DCA (data/raw/dca), saídas de receita_bruta_liquida.R.
# Uso: LC_ALL=C.UTF-8 Rscript scripts/conceito_unico.R
source("R/utils_io.R", encoding = "UTF-8")
for (f in c("R/download/snapshots.R", "R/download/siconfi_rreo.R", "R/download/siconfi_dca.R", "R/transform/rreo.R", "R/transform/dicionario_contas.R",
            "R/transform/receita_mensal_a3.R", "R/transform/dca_receita.R", "R/transform/receita_bruta_liquida.R", "R/transform/conceito_unico.R")) source(f, encoding = "UTF-8")
a3 <- ler_a3_estados(); fat <- fatores_dca(ler_dca_impostos(), a3)
rb <- receita_bruta_liquida(receita_mensal_a3(a3), fat)
rreo <- ler_rreo_pasta("data/raw/rreo", "E")
fl <- fluxos_a6_conceito(rreo, ler_dicionario("data/dicionario_contas_estados.csv"), ler_dicionario("data/dicionario_colunas_estados.csv"))
con <- conceito_deducoes_a6(fat, fl$a6_anual)
gravar_csv(con[, c("cod_ibge", "uf", "exercicio", "categoria", "conceito", "ded_fundeb_a6", "ded_transf_a6", "bruto", "a6_acum")], "outputs/conceito_a6_dca.csv")
print(table(con$categoria, con$conceito))
# Bruto por bimestre (ex-post; no ano corrente, sem DCA, vale o fator em tempo real)
rb$bruto <- ifelse(is.na(rb$bruto_ex_post), rb$bruto_tr, rb$bruto_ex_post)
rb$periodo <- (as.integer(format(rb$mes, "%m")) + 1L) %/% 2L
bb <- aggregate(bruto ~ cod_ibge + categoria + ano + periodo, rb, sum); names(bb)[3] <- "exercicio"
# Conceito do ano corrente (sem DCA ainda): último conceito observado da UF x imposto
ult <- do.call(rbind, lapply(split(con, paste(con$cod_ibge, con$categoria)), function(z) z[which.max(z$exercicio), ]))
anos_sem <- setdiff(unique(bb$exercicio), con$exercicio)
if (length(anos_sem)) {
  extra <- do.call(rbind, lapply(anos_sem, function(a) { u <- ult; u$exercicio <- a; u$conceito <- paste0(u$conceito, "*"); u }))
  con2 <- rbind(con, extra)
} else con2 <- con
aj <- ajuste_conceito_unico(bb, con2, parcelas_medianas(fat))
ajt <- ajuste_total(aj)
x <- aplicar_conceito_unico(fl$fluxos, ajt)
gravar_csv(x, "outputs/conceito_unico_bimestral.csv")
cat("\nbimestres UF:", nrow(x), "| não reconstruíveis:", sum(x$nao_reconstruivel, na.rm = TRUE), "| sem ajuste (sem A3):", sum(is.na(x$ajuste_total)), "\n")
v <- validar_conceito_unico(x[x$exercicio >= 2018, ], con)
gravar_csv(v$positividade, "outputs/conceito_unico_violacoes_positividade.csv"); gravar_csv(v$trocas, "outputs/conceito_unico_trocas.csv")
cat("custeio reconstruído <= 0:", nrow(v$positividade), "bimestres UF\n")
cat("trocas de conceito (UF x ano):", nrow(v$trocas), "| violam o limite (p90 das variações sem troca =", round(v$limite, 4), "):", sum(v$trocas$viola), "| melhora vs A6 bruto:", sum(v$trocas$melhora_vs_a6), "\n")
