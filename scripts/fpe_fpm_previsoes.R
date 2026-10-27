# E4.1b: previsões fora da amostra do candidato fpe_fpm (m3 + g) e diagnósticos. Uso: Rscript scripts/fpe_fpm_previsoes.R [--registrar]
# Sem chamadas ao Siconfi. Não aplica a regra de aceitação (isso é o torneio do E4).
invisible(lapply(list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE), source))
registrar <- "--registrar" %in% commandArgs(TRUE)
commit <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) NA_character_)
ultimo <- function(cod) { f <- sort(list.files("data/raw", sprintf("^bcb_sgs_%d_.*\\.json$", cod), full.names = TRUE)); f[length(f)] }
ser <- function(cod) { s <- ler_sgs(ultimo(cod)); primario_bi(s[s$data >= SGS_INICIO_ANALISE, ]) }
arq_pib <- baixar_pib_ibge()
pib <- pib_ibge_anual(arq_pib[["anual"]], arq_pib[["trimestral"]])
stn <- carregar_stn()                                   # available_at: último dia útil de m+1
stn_lag <- stn; stn_lag$available_at <- available_at_stn(stn$ano, stn$mes, 1L)   # sensibilidade: um mês a mais de defasagem
base <- list(bcb = ser(4642), bcb_est = ser(4643), bcb_mun = ser(4644), pib = pib[c("ano", "pib_bi")])
fontes <- c(base, list(stn = stn)); fontes_lag <- c(base, list(stn = stn_lag))
anos <- 2007:2025
amostras <- list("2007-2025" = integer(0), "2007-2025 sem 2020-22" = ANOS_PANDEMIA)
cands <- CANDIDATOS_P1[c("srw_brl", "m3", "fpe_fpm")]
dir.create("outputs", showWarnings = FALSE)
bts <- list(); res <- list(); res_m3 <- list(); res_lag <- list(); elig <- list(); diag <- list()
for (a in names(amostras)) {
  ex <- amostras[[a]]
  bt <- backtest_p1(cands, fontes, anos, excluir = ex)
  bl <- backtest_p1(list(fpe_fpm_lag1 = prever_fpe_fpm_lag1), fontes_lag, anos, excluir = ex)
  bts[[a]] <- cbind(amostra = a, rbind(bt, bl))
  # Pareamento: só ano x corte em que fpe_fpm tem previsão (sem imputação das lacunas); todos os modelos na mesma base.
  res[[a]] <- cbind(amostra = a, resumir_restante(bt, base = "srw_brl"))
  res_m3[[a]] <- cbind(amostra = a, resumir_restante(bt[bt$modelo %in% c("m3", "fpe_fpm"), ], base = "m3"))  # valor marginal de g
  res_lag[[a]] <- cbind(amostra = a, resumir_restante(rbind(bt[bt$modelo %in% c("srw_brl", "m3"), ], bl), base = "srw_brl"))
  ok <- bt[bt$modelo == "fpe_fpm" & !is.na(bt$previsao), ]
  elig[[a]] <- data.frame(amostra = a, corte = sort(unique(bt$corte)),
    anos_alvo = vapply(sort(unique(bt$corte)), function(m) length(unique(ok$ano[ok$corte == m])), integer(1)))
  # Diagnóstico de g (corte 5, 8, 11): coeficiente, t, correlação com a, VIF de g sobre (a, r_lag, E), amostra de treino completa
  for (m in c(5, 8, 11)) {
    info <- montar_info(fontes, 2025, m); info$excluir <- ex
    pm <- painel_restante(base$bcb, base$pib, cortes = m)
    pm$g <- vapply(pm$ano, function(y) g_stn(montar_info(fontes, 2025, m), y, m), numeric(1))
    pm <- pm[pm$ano < 2025 & !(pm$ano %in% ex) & stats::complete.cases(pm[c("r", "a", "r_lag", "g")]), ]
    if (nrow(pm) < 10) next
    f <- stats::lm(r ~ a + r_lag + E + g, data = pm); cf <- summary(f)$coefficients["g", ]
    r2 <- summary(stats::lm(g ~ a + r_lag + E, data = pm))$r.squared
    diag[[length(diag) + 1]] <- data.frame(amostra = a, corte = m, n = nrow(pm), coef_g = cf[1], t_g = cf[3],
                                          cor_a_g = stats::cor(pm$a, pm$g), VIF_g = 1 / (1 - r2))
  }
}
res <- do.call(rbind, res); res_m3 <- do.call(rbind, res_m3); res_lag <- do.call(rbind, res_lag); elig <- do.call(rbind, elig); diag <- do.call(rbind, diag)
utils::write.csv(do.call(rbind, bts), "outputs/fpe_fpm_backtest.csv", row.names = FALSE)
utils::write.csv(res, "outputs/fpe_fpm_resumo.csv", row.names = FALSE)
utils::write.csv(res_m3, "outputs/fpe_fpm_vs_m3.csv", row.names = FALSE)
utils::write.csv(res_lag, "outputs/fpe_fpm_sensibilidade_lag1.csv", row.names = FALSE)
utils::write.csv(elig, "outputs/fpe_fpm_elegibilidade.csv", row.names = FALSE)
utils::write.csv(diag, "outputs/fpe_fpm_diag_g.csv", row.names = FALSE)
if (registrar) {
  if (!nrow(res_lag) || !all(c("srw_brl", "m3", "fpe_fpm_lag1") %in% res_lag$modelo)) stop("Sensibilidade vazia: nada foi registrado.", call. = FALSE)
  for (a in names(amostras)) {
    for (n in c("srw_brl", "m3", "fpe_fpm")) registrar_experimento(res[res$amostra == a, ], n,
      "p1;alvo=regionais;cortes=1-11;min_treino=8;fontes=bcb+stn;pareado_com_fpe_fpm", paste(a, "pareado fpe_fpm"), commit)
    registrar_experimento(res_lag[res_lag$amostra == a, ], "fpe_fpm_lag1", "p1;alvo=regionais;stn_available_at=m+2", paste(a, "pareado fpe_fpm"), commit, status = "diagnostico")
  }
}
cat("Elegibilidade (anos-alvo com previsao fpe_fpm):\n"); print(reshape(elig, idvar = "corte", timevar = "amostra", direction = "wide"), row.names = FALSE)
cat("\nDiagnostico de g:\n"); print(diag, row.names = FALSE, digits = 3)
r <- res[res$amostra == "2007-2025 sem 2020-22" & res$corte %in% c(3, 6, 9), c("corte", "modelo", "n", "ME", "RMSE", "DM_p")]; print(r, row.names = FALSE)
r <- res_m3[res_m3$amostra == "2007-2025 sem 2020-22" & res_m3$corte %in% c(3, 6, 9) & res_m3$modelo == "fpe_fpm", c("corte", "modelo", "n", "RMSE", "MASE_srw", "DM_stat", "DM_p")]; cat("\nfpe_fpm vs m3 (MASE_srw = relativo ao m3):\n"); print(r, row.names = FALSE)
