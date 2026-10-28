# Torneio do P1 (E4): UMA execução, a partir de um único commit, com todas as previsões regeneradas.
# Ordem obrigatória (Pedro, 28/10/2026): commit do script e da lista final -> execução -> registro, tudo no mesmo hash.
# Uso: Rscript scripts/torneio_e4.R [--registrar]. Com --registrar, aborta se houver código/documentos sem commit.
# Sem chamadas ao Siconfi. Saídas em outputs/torneio_*.csv.
invisible(lapply(list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE), source))
registrar <- "--registrar" %in% commandArgs(TRUE)
commit <- system("git rev-parse --short HEAD", intern = TRUE)
if (registrar) {
  sujo <- system("git status --porcelain -- R scripts docs tests AGENTS.md", intern = TRUE)
  if (length(sujo)) stop("Há alterações sem commit em código/documentos; commite antes de executar com --registrar:\n", paste(sujo, collapse = "\n"), call. = FALSE)
}
cat("Commit:", commit, "\n")

# --- Fontes (mesmas do E4.1 e do FPE/FPM) ---
ultimo <- function(cod) { f <- sort(list.files("data/raw", sprintf("^bcb_sgs_%d_.*\\.json$", cod), full.names = TRUE)); f[length(f)] }
ser <- function(cod) { s <- ler_sgs(ultimo(cod)); primario_bi(s[s$data >= SGS_INICIO_ANALISE, ]) }
arq_pib <- baixar_pib_ibge()
pib <- pib_ibge_anual(arq_pib[["anual"]], arq_pib[["trimestral"]])
fontes <- list(bcb = ser(4642), bcb_est = ser(4643), bcb_mun = ser(4644), pib = pib[c("ano", "pib_bi")], stn = carregar_stn())
anos <- 2007:2025
BASE <- "srw_brl"
LISTA <- CANDIDATOS_P1                       # K = 8: base + 7 desafiantes (LDO fora, registrado em 27/10/2026)
DESAFIANTES <- setdiff(names(LISTA), BASE)
stopifnot(length(LISTA) == 8, setequal(DESAFIANTES, c("srw_pib", "acumulado_j5", "m2", "m3", "e41", "fpe_fpm", "combinacao")))

# --- Previsões (uma vez), duas amostras ---
amostras <- list("2007-2025" = integer(0), "2007-2025 sem 2020-22" = ANOS_PANDEMIA)
bts <- lapply(amostras, function(ex) backtest_p1(c(LISTA, CANDIDATOS_DIAGNOSTICO), fontes, anos, excluir = ex))
dir.create("outputs", showWarnings = FALSE)
utils::write.csv(do.call(rbind, Map(function(a, b) cbind(amostra = a, b), names(bts), bts)), "outputs/torneio_backtest.csv", row.names = FALSE)

# --- Conferência de reprodutibilidade contra o PR #25 (regra 7): aborta se algo divergir ---
PARAM_25 <- "p1;alvo=regionais;cortes=1-11;min_treino=8;fontes=bcb+bcb_est+bcb_mun"
reg <- utils::read.csv("experiments/registro.csv", stringsAsFactors = FALSE)
antigo <- reg[reg$parametros == PARAM_25 & reg$status %in% c("valido", "diagnostico"), ]
names(antigo)[names(antigo) == "candidato"] <- "modelo"
M25 <- c("srw_brl", "srw_pib", "acumulado_j5", "m2", "m3", "e41", "diag_combinacao_sem_fpe", "diag_e41_est_m3", "diag_e41_mun_m3")
novo <- do.call(rbind, lapply(names(amostras), function(a) {
  b <- bts[[a]]; b <- b[b$modelo %in% M25, ]
  cbind(amostra = a, resumir_restante(b, base = BASE))[c("modelo", "amostra", "corte", "n", "ME", "MAE", "RMSE")]
}))
novo$modelo[novo$modelo == "diag_combinacao_sem_fpe"] <- "combinacao"      # no #25 a combinação ainda não incluía fpe_fpm
div <- conferir_reproducao(novo, antigo[c("modelo", "amostra", "corte", "n", "ME", "MAE", "RMSE")])
utils::write.csv(div, "outputs/torneio_conferencia_pr25.csv", row.names = FALSE)
cat("Conferência contra o PR #25:", nrow(novo), "linhas regeneradas,", nrow(antigo), "registradas,", nrow(div), "divergências\n")
if (nrow(div) > 0 || nrow(novo) != nrow(antigo)) { print(utils::head(div, 20)); stop("As previsões regeneradas não reproduzem o PR #25; torneio abortado.", call. = FALSE) }

# --- Torneio ---
tab <- torneio_p1(bts[["2007-2025 sem 2020-22"]], bts[["2007-2025"]], DESAFIANTES, base = BASE)
esc <- escolher_por_faixa(tab, BASE)
utils::write.csv(tab, "outputs/torneio_decisao.csv", row.names = FALSE)
utils::write.csv(esc, "outputs/torneio_escolha.csv", row.names = FALSE)

# --- Resumo por corte (pareado com a base) e registro ---
resumo_corte <- function(bt, cand) {
  do.call(rbind, lapply(sort(unique(bt$corte)), function(m) {
    k <- merge(bt[bt$modelo == cand & bt$corte == m & !is.na(bt$previsao), c("ano", "erro")],
               bt[bt$modelo == BASE & bt$corte == m & !is.na(bt$previsao), c("ano", "erro")], by = "ano")
    if (!nrow(k)) return(NULL)
    data.frame(modelo = cand, corte = m, n = nrow(k), ME = mean(k$erro.x), MAE = mean(abs(k$erro.x)), RMSE = sqrt(mean(k$erro.x^2)))
  }))
}
if (registrar) {
  for (a in names(amostras)) for (n in unique(bts[[a]]$modelo)) {
    registrar_experimento(resumo_corte(bts[[a]], n), n, "torneio_e4;p1;alvo=regionais;K=8;cortes=1-11;min_treino=8;pareado_com_base", a, commit)
  }
  cat("Registrado no experiments/registro.csv com o commit", commit, "\n")
}

cat("\nDECISÃO POR FAIXA (K = 8):\n"); print(esc, row.names = FALSE)
cols <- c("faixa", "desafiante", "n_anos_sem", "rel_RMSE_sem", "share_melhor_sem", "DM_p_sem", "p_holm_sem", "rel_RMSE_com", "decisao")
cat("\nDESAFIANTES:\n"); print(tab[cols], row.names = FALSE, digits = 3)
