# Anexo 3 (RCL) x Anexo 6 dos estados: (1) teste da regra legal do FUNDEB, (A3 - A6) / A3 por UF x ano, e
# (2) conferência dos fluxos bimestrais do Anexo 6 contra a soma dos dois meses do Anexo 3.
# Regra declarada antes de rodar (28/10/2026): ICMS ~15% (20% x 75%), IPVA 10% (20% x 50%), ITCD 20%, FPE ~20%, IRRF 0%.
# Uso: LC_ALL=C.UTF-8 Rscript scripts/anexo3_conciliacao.R   (precisa de data/raw/rreo/E com Anexos 3 e 6)
source("R/utils_io.R", encoding = "UTF-8")
for (f in c("R/download/snapshots.R", "R/download/siconfi_rreo.R", "R/transform/rreo.R", "R/transform/dicionario_contas.R", "R/transform/receita_mensal_a3.R"))
  source(f, encoding = "UTF-8")
dir.create("outputs", showWarnings = FALSE)
ESPERADO <- c(ICMS = 0.15, IPVA = 0.10, ITCD = 0.20, FPE = 0.20, IRRF = 0)
TOL <- 0.005   # 0,5 ponto percentual

a3 <- ler_a3_estados()
cat("linhas A3 (contas acompanhadas):", nrow(a3), "| UFs:", length(unique(a3$cod_ibge)), "| exercícios:", paste(range(a3$exercicio), collapse = "-"), "\n")
mensal <- receita_mensal_a3(a3)
gravar_csv(mensal, "outputs/a3_receita_mensal_uf.csv")

rreo <- ler_rreo_pasta("data/raw/rreo", "E")
dc <- ler_dicionario("data/dicionario_colunas_estados.csv"); dcont <- ler_dicionario("data/dicionario_contas_estados.csv")
a6 <- aplicar_dicionario(rreo[rreo$anexo == "RREO-Anexo 06", ], dcont, dc)
cat6 <- c(RREO6ICMS = "ICMS", RREO6IPVA = "IPVA", RREO6ITCD = "ITCD", RREO6IRRF = "IRRF", RREO6CotaParteDoFPE = "FPE", RREO6FPE = "FPE")
a6 <- a6[a6$cod_conta %in% names(cat6) & a6$papel_coluna %in% "receita_p2" & a6$ano_rel %in% c("corrente", "nao_se_aplica"), ]
a6$categoria <- unname(cat6[a6$cod_conta])
a6 <- a6[!duplicated(a6[, c("cod_ibge", "exercicio", "periodo", "categoria")]), c("cod_ibge", "uf", "exercicio", "periodo", "categoria", "valor")]
names(a6)[names(a6) == "valor"] <- "a6_acum"

# (1) Regra legal: total 12 meses do bimestre 6 (= exercício) do A3 contra o acumulado no 6º bimestre do A6
t12 <- a3[a3$tipo == "total12m" & a3$periodo == 6 & a3$categoria %in% names(ESPERADO), c("cod_ibge", "exercicio", "categoria", "valor")]
t12 <- t12[!duplicated(t12[, c("cod_ibge", "exercicio", "categoria")]), ]
names(t12)[4] <- "a3_12m"
r <- merge(t12, a6[a6$periodo == 6, c("cod_ibge", "uf", "exercicio", "categoria", "a6_acum")], by = c("cod_ibge", "exercicio", "categoria"))
r$razao <- (r$a3_12m - r$a6_acum) / r$a3_12m
r$esperado <- ESPERADO[r$categoria]
r$dif_pp <- 100 * (r$razao - r$esperado)
r$confere <- is.finite(r$razao) & abs(r$razao - r$esperado) <= TOL
gravar_csv(r, "outputs/a3_a6_regra_legal.csv")
res <- do.call(rbind, lapply(split(r, r$categoria), function(z) data.frame(categoria = z$categoria[1], esperado = z$esperado[1], n = nrow(z),
  confere = sum(z$confere), pct_confere = round(100 * mean(z$confere), 1), mediana_razao = round(median(z$razao, na.rm = TRUE), 4))))
print(res, row.names = FALSE)
gravar_csv(res, "outputs/a3_a6_regra_legal_resumo.csv")
por_ano <- aggregate(confere ~ categoria + exercicio, r, function(x) round(100 * mean(x), 0))
print(reshape(por_ano, idvar = "exercicio", timevar = "categoria", direction = "wide"), row.names = FALSE)
gravar_csv(r[!r$confere, ], "outputs/a3_a6_regra_legal_excecoes.csv")

# (2) Fluxo bimestral do A6 x soma dos 2 meses do A3 (já líquida da regra: A6 ~ A3 x (1 - esperado))
fl <- acumulado_para_fluxo(a6, serie = c("cod_ibge", "categoria"))
m2 <- mensal; m2$ex <- as.integer(format(m2$mes, "%Y")); m2$p <- (as.integer(format(m2$mes, "%m")) + 1L) %/% 2L
m2 <- aggregate(valor ~ cod_ibge + categoria + ex + p, m2, sum); names(m2) <- c("cod_ibge", "categoria", "exercicio", "periodo", "a3_2m")
f2 <- merge(fl, m2, by = c("cod_ibge", "categoria", "exercicio", "periodo"))
f2 <- f2[!f2$acum_anterior_ausente & f2$categoria %in% names(ESPERADO), ]
f2$razao <- (f2$a3_2m - f2$fluxo) / f2$a3_2m; f2$esperado <- ESPERADO[f2$categoria]
f2$confere <- is.finite(f2$razao) & abs(f2$razao - f2$esperado) <= 0.01
gravar_csv(f2, "outputs/a3_a6_fluxo_bimestral.csv")
print(aggregate(confere ~ categoria, f2, function(x) c(n = length(x), pct = round(100 * mean(x), 1))))
