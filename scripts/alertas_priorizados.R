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
nr <- alertas_novos_por_rodada(p$alertas, 2022L); gravar_csv(nr, "outputs/alertas_novos_por_rodada.csv")
# Rodada típica = um bimestre (exercicio, periodo) entre 2022 b1 e 2026 b4
rod <- expand.grid(exercicio = 2022:2026, periodo = 1:6); rod <- rod[!(rod$exercicio == 2026 & rod$periodo > 4), ]
cnt <- function(sub) { n <- merge(rod, aggregate(n ~ exercicio + periodo, nr[sub(nr), ], sum), all.x = TRUE); n$n[is.na(n$n)] <- 0; n$n }
q <- function(x) c(mediana = median(x), p90 = unname(quantile(x, 0.9)), max = max(x))
cat("\nAlertas novos por rodada (2022 b1 a 2026 b4):\n")
print(rbind(todos = q(cnt(function(d) rep(TRUE, nrow(d)))),
            sem_fator_defasado = q(cnt(function(d) d$subtipo != "fator_defasado")),
            so_b_c_instavel_d = q(cnt(function(d) d$subtipo %in% c("salto_vs_ano_anterior", "fator_instavel", "entrega_atrasada", "retificacao")))))
b <- p$alertas[p$alertas$status == "nova" & p$alertas$tipo == "b" & p$alertas$exercicio >= 2022, ]
cat("\n(b) novos desde 2022:", nrow(b), "| materialidade mediana:", round(median(b$materialidade, na.rm = TRUE), 3), "| acima de 5% da receita:", sum(b$materialidade > 0.05, na.rm = TRUE), "\n")
print(head(p$alertas[p$alertas$status == "nova", c("tipo", "subtipo", "cod_ibge", "serie", "exercicio", "periodo", "materialidade")], 8), row.names = FALSE)
