# E4.2: intervalos de 80% do SRW em R$ (modelo publicado do P1). Uso: Rscript scripts/intervalos_e42.R
# Ordem: commit do script -> execução (o hash e a situação da árvore saem no início). Sem chamadas ao Siconfi.
source("R/utils_io.R", encoding = "UTF-8")
invisible(lapply(list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE), source))
commit <- system("git rev-parse --short HEAD", intern = TRUE)
sujo <- system("git status --porcelain -- R scripts docs tests AGENTS.md", intern = TRUE)
cat("Commit:", commit, "| árvore de código limpa:", length(sujo) == 0, "\n")
if (length(sujo)) stop("Há alterações sem commit em código/documentos; commite antes de executar.", call. = FALSE)
ultimo <- function(cod) { f <- sort(list.files("data/raw", sprintf("^bcb_sgs_%d_.*\\.json$", cod), full.names = TRUE)); f[length(f)] }
s <- ler_sgs(ultimo(4642)); reg <- primario_bi(s[s$data >= SGS_INICIO_ANALISE, ])
arq_pib <- baixar_pib_ibge(); pib <- pib_ibge_anual(arq_pib[["anual"]], arq_pib[["trimestral"]])
fontes <- list(bcb = reg, pib = pib[c("ano", "pib_bi")])
bt <- backtest_p1(CANDIDATOS_P1["srw_brl"], fontes, 2000:2025)
cat("Previsões do SRW:", nrow(bt), "linhas; alvos", min(bt$ano), "-", max(bt$ano), "\n")
iv <- intervalos_backtest(bt, 2008:2025)
dir.create("outputs", showWarnings = FALSE)
gravar_csv(iv, "outputs/e42_intervalos_backtest.csv")
cob <- rbind(
  cbind(amostra = "publicado (σ com 2020-22), alvos 2008-2025", cobertura_faixas(iv, "dentro_com")),
  cbind(amostra = "publicado (σ com 2020-22), sem alvos 2020-22", cobertura_faixas(iv, "dentro_com", anos_fora = ANOS_PANDEMIA)),
  cbind(amostra = "σ sem 2020-22, sem alvos 2020-22", cobertura_faixas(iv, "dentro_sem", anos_fora = ANOS_PANDEMIA)))
gravar_csv(cob, "outputs/e42_cobertura.csv")
sig <- data.frame(corte = 1:11, sigma_com_bi = sigma_publicado(bt, 2026), sigma_sem_bi = sigma_publicado(bt, 2026, excluir = ANOS_PANDEMIA))
gravar_csv(sig, "outputs/e42_sigma_2026.csv")
cat("\nσ de produção (alvo 2026, R$ bi):\n"); print(round(sig, 2), row.names = FALSE)
cat("\nCobertura (nominal 80%):\n"); print(cob[c("amostra", "faixa", "pares", "cobertura", "wilson_inf", "wilson_sup", "contem_80", "anos", "cobertura_anos", "wilson_anos_inf", "wilson_anos_sup", "contem_80_anos")], row.names = FALSE, digits = 3)
# Ilustração (não é previsão oficial): SRW de 2026 no último corte com dado
ult <- max(reg$data[format(reg$data, "%Y") == "2026"]); m <- as.integer(format(ult, "%m"))
prev <- prever_srw(reg, 2026, m); ic <- intervalo_80(prev, sig$sigma_com_bi[m]); is <- intervalo_80(prev, sig$sigma_sem_bi[m])
cat(sprintf("\nIlustração 2026 (dados até o mês %d): SRW %.1f bi | IC80 publicado [%.1f; %.1f] | sem 2020-22 [%.1f; %.1f]\n", m, prev, ic$inf, ic$sup, is$inf, is$sup))
