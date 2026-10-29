# E2.8: roda os alertas automáticos sobre o histórico (o que a rodada mensal teria alertado) e quantifica as quebras conhecidas.
# Regras e limites: docs/contrato.md (29/10/2026). Saídas em outputs/ (git-ignored): alertas_rodada.csv, quebras_rpps_2023.csv, quebras_pessoal_rgf.csv.
# Uso: LC_ALL=C.UTF-8 Rscript scripts/quebras_e28.R   (precisa do bruto local: RREO estados, Anexo 3, DCA, RGF, extrato)
source("R/utils_io.R", encoding = "UTF-8")
for (f in c("R/download/snapshots.R", "R/download/siconfi_rreo.R", "R/download/extrato.R", "R/transform/rreo.R", "R/transform/dicionario_contas.R",
            "R/quality/alertas.R")) source(f, encoding = "UTF-8")
dir.create("outputs", showWarnings = FALSE)
dic <- ler_dicionario("data/dicionario_contas_estados.csv"); dc <- ler_dicionario("data/dicionario_colunas_estados.csv")
rreo <- ler_rreo_pasta("data/raw/rreo", "E")
estados <- unique(rreo$cod_ibge)

# (a) dicionário
al <- alerta_dicionario_rreo(rreo, dic, dc)
cat("(a) contas/colunas sem dicionário:", nrow(al), "\n")

# (b) salto de categoria (conceito original do Anexo 6)
fl <- fluxos_a6_categorias(rreo, dic, dc)
rt <- aggregate(valor ~ cod_ibge + exercicio + periodo, fl[grepl("^rec:", fl$serie), ], sum); names(rt)[4] <- "rec_total"
ab <- alerta_salto(fl, rt)
cat("(b) saltos:", nrow(ab), "\n")
al <- rbind(al, ab)

# (c) flags do conceito único e da calibração (se as saídas existem)
x <- if (file.exists("outputs/conceito_unico_bimestral.csv")) ler_csv("outputs/conceito_unico_bimestral.csv") else NULL
rb <- if (file.exists("outputs/receita_mensal_bruta_liquida.csv")) { r <- ler_csv("outputs/receita_mensal_bruta_liquida.csv"); r$mes <- as.Date(r$mes); r } else NULL
ac <- alerta_flags(x, rb); cat("(c) flags:", nrow(ac), "\n"); al <- rbind(al, ac)

# (d) entrega (extrato dos estados)
ext <- do.call(rbind, lapply(estados, function(id) do.call(rbind, lapply(2015:as.integer(format(Sys.Date(), "%Y")), function(a) {
  v <- extrato_vigente("data/raw/rreo", id, a); if (nrow(v)) ler_extrato(v$arquivo) else NULL }))))
esp <- expand.grid(cod_ibge = estados, exercicio = 2015:as.integer(format(Sys.Date(), "%Y")), periodo = 1:6)
ad <- alerta_entrega(ext, esp); cat("(d) entrega:", nrow(ad), "\n"); al <- rbind(al, ad)
gravar_csv(al, "outputs/alertas_rodada.csv")
print(table(al$tipo, al$subtipo))

# Detecção das quebras conhecidas pelo alerta (b)
b <- ab[ab$exercicio == 2023, ]
cat("\n(b) em 2023 (RPPS):", nrow(b), "alertas em", length(unique(b$cod_ibge)), "UFs; séries:", paste(names(sort(table(b$serie), decreasing = TRUE))[1:5], collapse = ", "), "\n")
p25 <- ab[ab$exercicio == 2025 & ab$serie == "desp:pessoal" & ab$cod_ibge %in% c(33, 41, 43), ]
cat("(b) pessoal em 2025, RJ/PR/RS:\n"); print(p25[, c("cod_ibge", "exercicio", "periodo", "valor", "limite")], row.names = FALSE)

# RPPS: totais com e sem, 2022-2025
tr <- totais_rpps(rreo, dic, dc)
tr$parcela_rpps_rec <- (tr$rec_com - tr$rec_sem) / tr$rec_com
tr$parcela_rpps_desp <- (tr$desp_com - tr$desp_sem) / tr$desp_com
gravar_csv(tr, "outputs/quebras_rpps_2023.csv")
cat("\nParcela do RPPS na receita primária total (2023-25): mediana", round(median(tr$parcela_rpps_rec[tr$exercicio >= 2023], na.rm = TRUE), 3),
    "| UFs com valor:", length(unique(tr$cod_ibge[tr$exercicio >= 2023 & !is.na(tr$rec_sem)])), "\n")
