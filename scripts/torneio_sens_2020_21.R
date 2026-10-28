# Sensibilidade declarada do torneio do P1 (28/10/2026): mesma lista (K = 8), mesma regra congelada, mas com a amostra
# "sem 2020–21" (2022 permanece) no lugar de "sem 2020–22" como amostra principal. NÃO altera a decisão do torneio nem
# entra no registro de experimentos. Ordem obrigatória: commit do script e da declaração -> execução -> resultado no STATUS.
# Uso: Rscript scripts/torneio_sens_2020_21.R. Aborta se houver código/documentos sem commit. Saídas: outputs/torneio_sens_2020_21_*.csv.
source("R/utils_io.R", encoding = "UTF-8")
invisible(lapply(list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE), source))
sujo <- system("git status --porcelain -- R scripts docs tests AGENTS.md", intern = TRUE)
if (length(sujo)) stop("Há alterações sem commit em código/documentos; commite antes de executar:\n", paste(sujo, collapse = "\n"), call. = FALSE)
cat("Commit:", system("git rev-parse --short HEAD", intern = TRUE), "\n")

ultimo <- function(cod) { f <- sort(list.files("data/raw", sprintf("^bcb_sgs_%d_.*\\.json$", cod), full.names = TRUE)); f[length(f)] }
ser <- function(cod) { s <- ler_sgs(ultimo(cod)); primario_bi(s[s$data >= SGS_INICIO_ANALISE, ]) }
arq_pib <- baixar_pib_ibge()
pib <- pib_ibge_anual(arq_pib[["anual"]], arq_pib[["trimestral"]])
fontes <- list(bcb = ser(4642), bcb_est = ser(4643), bcb_mun = ser(4644), pib = pib[c("ano", "pib_bi")], stn = carregar_stn())
anos <- 2007:2025; BASE <- "srw_brl"; LISTA <- CANDIDATOS_P1
DESAFIANTES <- setdiff(names(LISTA), BASE)
stopifnot(length(LISTA) == 8, setequal(DESAFIANTES, c("srw_pib", "acumulado_j5", "m2", "m3", "e41", "fpe_fpm", "combinacao")))

ANOS_SENS <- 2020:2021
bt_sens <- backtest_p1(LISTA, fontes, anos, excluir = ANOS_SENS)          # treino e teste sem 2020–21
bt_com <- backtest_p1(LISTA, fontes, anos, excluir = integer(0))          # amostra completa (igual à do torneio)
tab <- torneio_p1(bt_sens, bt_com, DESAFIANTES, base = BASE)
esc <- escolher_por_faixa(tab, BASE)
dir.create("outputs", showWarnings = FALSE)
gravar_csv(tab, "outputs/torneio_sens_2020_21_decisao.csv")
gravar_csv(esc, "outputs/torneio_sens_2020_21_escolha.csv")

# Comparação com a decisão congelada (sem 2020–22)
cong <- ler_csv("outputs/torneio_decisao.csv")
chave <- c("faixa", "desafiante")
cmp <- merge(cong[, c(chave, "n_anos_sem", "rel_RMSE_sem", "share_melhor_sem", "p_holm_sem", "decisao")],
             tab[, c(chave, "n_anos_sem", "rel_RMSE_sem", "share_melhor_sem", "p_holm_sem", "decisao")],
             by = chave, suffixes = c("_congelado", "_sens"))
cmp$decisao_igual <- cmp$decisao_congelado == cmp$decisao_sens
gravar_csv(cmp, "outputs/torneio_sens_2020_21_comparacao.csv")
print(esc, row.names = FALSE)
cat("\nDecisões iguais às do torneio congelado:", sum(cmp$decisao_igual), "de", nrow(cmp), "\n")
print(cmp[, c("faixa", "desafiante", "n_anos_sem_sens", "rel_RMSE_sem_congelado", "rel_RMSE_sem_sens", "p_holm_sem_congelado", "p_holm_sem_sens", "decisao_congelado", "decisao_sens")], row.names = FALSE, digits = 3)
