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

# Pessoal: RREO x RGF (Executivo), variação anual por UF x bimestre
rg <- pessoal_rgf_mensal()
yy <- yoy_pessoal_rreo_rgf(fl, rg)
gravar_csv(yy, "outputs/quebras_pessoal_rgf.csv")
cat("\nPessoal RREO x RGF: UF-bimestres comparáveis:", nrow(yy[!is.na(yy$dif), ]), "| suspeita de reclassificação (> 20 p.p.):", sum(yy$suspeita_reclassificacao), "\n")
print(table(yy$exercicio[yy$suspeita_reclassificacao], yy$cod_ibge[yy$suspeita_reclassificacao]))
print(yy[yy$exercicio == 2025 & yy$cod_ibge %in% c(33, 41, 43), c("cod_ibge", "periodo", "rreo_yoy", "rgf_yoy", "dif", "suspeita_reclassificacao")], digits = 3, row.names = FALSE)

# Harmonização de pessoal (sensibilidade) para RJ/PR/RS: início detectado nos dados (primeiro bimestre de 2025 com salto e suspeita)
ini <- data.frame(cod_ibge = c(33, 41, 43), exercicio = 2025, periodo = c(1, 6, 5))
ph <- pessoal_harmonizado(fl[fl$serie == "desp:pessoal", c("cod_ibge", "exercicio", "periodo", "valor")], yy, ini)
ph <- ph[ph$cod_ibge %in% ini$cod_ibge & ph$exercicio >= 2024, ]
desp <- aggregate(valor ~ cod_ibge + exercicio + periodo, fl[grepl("^desp:", fl$serie), ], sum); names(desp)[4] <- "desp_total"
ph <- merge(ph, desp, by = c("cod_ibge", "exercicio", "periodo"), all.x = TRUE); ph$excedente_sobre_despesa <- ph$excedente / ph$desp_total
gravar_csv(ph, "outputs/quebras_pessoal_harmonizado.csv")
cat("\nExcedente de pessoal (reclassificação) 2025, R$ bi e % da despesa total do bimestre:\n")
print(transform(ph[ph$excedente > 0, ], excedente_bi = round(excedente / 1e9, 2), pct = round(100 * excedente_sobre_despesa, 1))[, c("cod_ibge", "exercicio", "periodo", "excedente_bi", "pct")], row.names = FALSE)

# Inventário consolidado das quebras (outputs/quebras_e28.csv): números lidos das saídas acima, nunca digitados.
inv <- list()
add <- function(quebra, ufs, periodo, n, magnitude, tratamento, alerta) inv[[length(inv) + 1]] <<-
  data.frame(quebra, ufs, periodo, n, magnitude, tratamento, alerta, stringsAsFactors = FALSE)
rs <- fl[fl$cod_ibge == 43 & fl$exercicio == 2018, ]
add("A6 vazio na API", "RS", "2018 b1-b5", 5 - length(setdiff(unique(rs$periodo), 6)),
    "fluxos NA; total anual vem do b6", "fluxo NA; agregado 'parcial'; conceito_original", "d (extrato) / c")
est <- ler_csv("outputs/a3_fatores_estabilidade.csv")
tr <- ler_csv("outputs/conceito_unico_trocas.csv")
add("fator bruto/liquido do A3 (mudanca anual > 2%)", "UF x imposto", "anual", sum(est$n_quebras),
    paste0("UF-imposto com ao menos 1: ", sum(est$n_quebras > 0), " de ", nrow(est)),
    "flag_quebra_fator; ano corrente menos confiavel; nao bloqueia", "c (fator_instavel)")
rp <- ler_csv("outputs/quebras_rpps_2023.csv"); rp <- rp[rp$exercicio >= 2023 & !is.na(rp$parcela_rpps_rec), ]
add("RPPS separado no A6 (layout 2023+)", "27", "2023 em diante", length(unique(rp$cod_ibge)),
    paste0("RPPS/receita: mediana ", round(median(rp$parcela_rpps_rec), 3), "; max ", round(max(rp$parcela_rpps_rec), 3)),
    "usar totais 'sem RPPS' do layout 2023+; categorias demais receitas e pessoal nao separaveis", "b (227 alertas em 2023)")
hm <- ler_csv("outputs/quebras_pessoal_harmonizado.csv")
for (u in c(33, 41, 43)) { h <- hm[hm$cod_ibge == u & hm$excedente > 0, ]
  add("reclassificacao de pessoal no RREO", c("33" = "RJ", "41" = "PR", "43" = "RS")[as.character(u)],
      paste0(min(h$exercicio), " b", h$periodo[which.min(h$exercicio * 10 + h$periodo)], " em diante (persiste em 2026)"), nrow(h),
      paste0("excedente de pessoal ate ", round(max(h$excedente) / 1e9, 2), " bi/bimestre (", round(100 * max(h$excedente_sobre_despesa), 1), "% da despesa)"),
      "degrau na despesa total/primario; categoria pessoal harmonizada por linha de excedente; RGF so em sensibilidade", "b + RGF>20pp")
}
for (s in c("conceito_original", "custeio_nao_positivo", "quebra_na_troca_de_conceito"))
  add(paste0("flag ", s), "varias", "varios", sum(al$subtipo == s), "", "flag automatico, sem correcao manual", "c")
gravar_csv(do.call(rbind, inv), "outputs/quebras_e28.csv")
print(do.call(rbind, inv)[, c("quebra", "ufs", "n", "magnitude")])
