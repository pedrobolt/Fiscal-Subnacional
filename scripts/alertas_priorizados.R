# E2.8 (itens do #43): marca quebras inventariadas como "conhecida", ordena os demais por materialidade e dimensiona a revisão por rodada.
# Entrada: outputs/alertas_rodada.csv (scripts/quebras_e28.R) e o RREO bruto (receita total por bimestre). Saídas: outputs/alertas_priorizados.csv,
# outputs/alertas_resumo.csv, outputs/alertas_novos_por_rodada.csv.
# Uso: LC_ALL=C.UTF-8 Rscript scripts/alertas_priorizados.R
source("R/utils_io.R", encoding = "UTF-8")
for (f in c("R/download/snapshots.R", "R/download/siconfi_rreo.R", "R/transform/rreo.R", "R/transform/dicionario_contas.R", "R/quality/alertas.R")) source(f, encoding = "UTF-8")
dic <- ler_dicionario("data/dicionario_contas_estados.csv"); dc <- ler_dicionario("data/dicionario_colunas_estados.csv")
rreo <- ler_rreo_pasta("data/raw/rreo", "E")
fl <- fluxos_a6_categorias(rreo, dic, dc)
rt <- aggregate(valor ~ cod_ibge + exercicio + periodo, fl[grepl("^rec:", fl$serie), ], sum); names(rt)[4] <- "rec_total"
al <- ler_csv("outputs/alertas_rodada.csv")
p <- priorizar_alertas(al, rt)
gravar_csv(p$alertas, "outputs/alertas_priorizados.csv"); gravar_csv(p$resumo, "outputs/alertas_resumo.csv")
cat("Total:", nrow(p$alertas), "| conhecidas:", sum(p$alertas$status == "conhecida"), "| novas:", sum(p$alertas$status == "nova"), "\n")
print(p$resumo, row.names = FALSE)
ab <- aba_alertas(p); gravar_csv(ab$lista, "outputs/alertas_aba_lista.csv"); gravar_csv(ab$contagem, "outputs/alertas_aba_contagem.csv")
cat("\nAba do Excel: lista", nrow(ab$lista), "| contagem (demais novos):", sum(ab$contagem$n), "\n")
# Rodada tipica = um bimestre (exercicio, periodo) entre 2022 b1 e 2026 b4; por bimestre: itens na lista da aba e total de novos
rod <- expand.grid(exercicio = 2022:2026, periodo = 1:6); rod <- rod[!(rod$exercicio == 2026 & rod$periodo > 4), ]
por <- function(d) { k <- table(factor(paste(d$exercicio, d$periodo), levels = paste(rod$exercicio, rod$periodo))); c(mediana = median(k), p90 = unname(quantile(k, 0.9)), max = max(k)) }
novas <- p$alertas[p$alertas$status == "nova" & p$alertas$exercicio >= 2022, ]
res <- rbind(novas_total = por(novas), novas_b = por(novas[novas$tipo == "b", ]), lista_da_aba = por(ab$lista[ab$lista$exercicio >= 2022, ]))
print(res); gravar_csv(data.frame(medida = rownames(res), res), "outputs/alertas_novos_por_rodada.csv")
