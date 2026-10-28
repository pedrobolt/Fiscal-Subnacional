# E4.2b: intervalos do SRW em R$ com σ em % do PIB (mudança de protocolo pós-resultado, contrato 28/10/2026). UMA execução.
# Uso: Rscript scripts/intervalos_e42_pib.R. Aborta se houver código/documentos sem commit. Sem chamadas ao Siconfi.
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
iv <- intervalos_backtest(bt, 2008:2025, escala = "pib")
dir.create("outputs", showWarnings = FALSE)
utils::write.csv(fileEncoding = "UTF-8", iv, "outputs/e42b_intervalos_backtest.csv", row.names = FALSE)
cob <- rbind(
  cbind(amostra = "publicado (σ com 2020-22), alvos 2008-2025", cobertura_faixas(iv, "dentro_com")),
  cbind(amostra = "publicado (σ com 2020-22), sem alvos 2020-22", cobertura_faixas(iv, "dentro_com", anos_fora = ANOS_PANDEMIA)),
  cbind(amostra = "σ sem 2020-22, sem alvos 2020-22", cobertura_faixas(iv, "dentro_sem", anos_fora = ANOS_PANDEMIA)))
utils::write.csv(fileEncoding = "UTF-8", cob, "outputs/e42b_cobertura.csv", row.names = FALSE)
pub <- cob[cob$amostra == "publicado (σ com 2020-22), alvos 2008-2025", ]
div <- texto_divulgacao(pub); utils::write.csv(fileEncoding = "UTF-8", div, "outputs/e42b_divulgacao.csv", row.names = FALSE)
err_pct <- bt; err_pct$erro <- bt$erro / bt$pib
sig <- data.frame(corte = 1:11, sigma_com_pct_pib = 100 * sigma_publicado(err_pct, 2026), sigma_sem_pct_pib = 100 * sigma_publicado(err_pct, 2026, excluir = ANOS_PANDEMIA))
utils::write.csv(fileEncoding = "UTF-8", sig, "outputs/e42b_sigma_2026.csv", row.names = FALSE)
cat("\nσ de produção (alvo 2026, % do PIB):\n"); print(round(sig, 3), row.names = FALSE)
cat("\nCobertura (nominal 80%):\n"); print(cob[c("amostra", "faixa", "pares", "cobertura", "wilson_inf", "wilson_sup", "contem_80", "anos", "cobertura_anos", "wilson_anos_inf", "wilson_anos_sup", "contem_80_anos")], row.names = FALSE, digits = 3)
cat("\nDivulgação por faixa (alvos 2008-2025, intervalo publicado):\n"); print(div, row.names = FALSE)
# Ilustração (não é previsão oficial): PIB 2026 aproximado pelos 4 últimos trimestres do IBGE
ult <- max(reg$data[format(reg$data, "%Y") == "2026"]); m <- as.integer(format(ult, "%m"))
pib26 <- pib_ultimos_4_trimestres(arq_pib[["trimestral"]])$pib_bi
prev <- prever_srw(reg, 2026, m); ic <- intervalo_80(prev, sig$sigma_com_pct_pib[m] / 100 * pib26)
cat(sprintf("\nIlustração 2026 (dados até o mês %d; PIB aprox. %.0f bi): SRW %.1f bi | faixa publicada [%.1f; %.1f]\n", m, pib26, prev, ic$inf, ic$sup))
