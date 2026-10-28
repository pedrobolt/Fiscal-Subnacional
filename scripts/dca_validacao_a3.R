# Valida com a DCA (Anexo I-C) o bruto do RREO Anexo 3 e o conceito (bruto / líquido de cota-parte) do Anexo 6, por UF x ano x imposto.
# Declarado antes de rodar (28/10/2026): A3 12 meses (6º bimestre) = receita bruta realizada da DCA; A6 = bruto - FUNDEB (conceito
# "bruto de cota-parte") ou bruto - FUNDEB - transferências constitucionais (conceito "líquido de cota-parte"); tolerância 0,5% do bruto.
# Uso: LC_ALL=C.UTF-8 Rscript scripts/dca_validacao_a3.R
source("R/utils_io.R", encoding = "UTF-8")
for (f in c("R/download/snapshots.R", "R/download/siconfi_rreo.R", "R/download/siconfi_dca.R", "R/transform/dca_receita.R")) source(f, encoding = "UTF-8")
TOL <- 0.005
d <- ler_dca_impostos()
d$tipo <- c("Receitas Brutas Realizadas" = "bruto", "Deduções - FUNDEB" = "fundeb", "Deduções - Transferências Constitucionais" = "transf", "Outras Deduções da Receita" = "outras")[d$coluna]
d <- d[!duplicated(d[, c("cod_ibge", "exercicio", "categoria", "tipo")]), ]
w <- reshape(d[, c("cod_ibge", "uf", "exercicio", "categoria", "tipo", "valor")], idvar = c("cod_ibge", "uf", "exercicio", "categoria"), timevar = "tipo", direction = "wide")
names(w) <- sub("^valor\\.", "", names(w))
for (n in c("fundeb", "transf", "outras")) if (!n %in% names(w)) w[[n]] <- NA_real_
for (n in c("fundeb", "transf", "outras")) w[[n]][is.na(w[[n]])] <- 0

r <- ler_csv("outputs/a3_a6_regra_legal.csv")[, c("cod_ibge", "exercicio", "categoria", "a3_12m", "a6_acum")]
m <- merge(w, r, by = c("cod_ibge", "exercicio", "categoria"))
m$a3_sobre_bruto <- m$a3_12m / m$bruto
m$a3_confere <- abs(m$a3_sobre_bruto - 1) <= TOL
m$liq_fundeb <- m$bruto - m$fundeb - m$outras
m$liq_total <- m$liq_fundeb - m$transf
m$conceito_a6 <- ifelse(m$transf != 0 & abs(m$a6_acum - m$liq_total) <= TOL * m$bruto, "liquido_cota_parte",
                  ifelse(abs(m$a6_acum - m$liq_fundeb) <= TOL * m$bruto, "bruto_cota_parte",
                  ifelse(abs(m$a6_acum - m$bruto) <= TOL * m$bruto, "bruto_sem_deducao", "fora")))
gravar_csv(m, "outputs/dca_a3_a6.csv")
cat("UF x ano x imposto comparados:", nrow(m), "\n")
print(aggregate(a3_confere ~ categoria, m, function(x) c(n = length(x), pct = round(100 * mean(x), 1))))
print(table(m$categoria, m$conceito_a6))
ic <- m[m$categoria == "ICMS", ]
print(table(ic$exercicio, ic$conceito_a6))
gravar_csv(m[!m$a3_confere, ], "outputs/dca_a3_excecoes_bruto.csv")
