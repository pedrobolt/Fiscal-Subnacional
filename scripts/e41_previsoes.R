# E4.1: previsões fora da amostra dos candidatos da lista (incl. E4.1 e combinação) e diagnósticos, via montar_info.
# Uso: Rscript scripts/e41_previsoes.R [--registrar]. Sem chamadas ao Siconfi. Não aplica a regra de aceitação (isso é o torneio do E4).
arqs <- list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
arqs <- c(arqs[!grepl("candidatos_p1", arqs)], arqs[grepl("candidatos_p1", arqs)])  # candidatos_p1 depende de ESPEC_RESTANTE
invisible(lapply(arqs, source))
registrar <- "--registrar" %in% commandArgs(TRUE)
commit <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) NA_character_)
ultimo <- function(cod) { f <- sort(list.files("data/raw", sprintf("^bcb_sgs_%d_.*\\.json$", cod), full.names = TRUE)); f[length(f)] }
ser <- function(cod) { s <- ler_sgs(ultimo(cod)); primario_bi(s[s$data >= SGS_INICIO_ANALISE, ]) }
arq_pib <- baixar_pib_ibge()
pib <- pib_ibge_anual(arq_pib[["anual"]], arq_pib[["trimestral"]])
fontes <- list(bcb = ser(4642), bcb_est = ser(4643), bcb_mun = ser(4644), pib = pib[c("ano", "pib_bi")])
anos <- 2007:2025
amostras <- list("2007-2025" = integer(0), "2007-2025 sem 2020-22" = ANOS_PANDEMIA)
dir.create("outputs", showWarnings = FALSE)
bts <- list(); res <- list()
for (a in names(amostras)) {
  bt <- backtest_p1(c(CANDIDATOS_P1_25, CANDIDATOS_DIAGNOSTICO[c("diag_e41_est_m3", "diag_e41_mun_m3")]), fontes, anos, excluir = amostras[[a]])
  bts[[a]] <- cbind(amostra = a, bt)
  res[[a]] <- cbind(amostra = a, resumir_restante(bt, base = "srw_brl"))
}
res <- do.call(rbind, res)
utils::write.csv(fileEncoding = "UTF-8", do.call(rbind, bts), "outputs/e41_backtest.csv", row.names = FALSE)
utils::write.csv(fileEncoding = "UTF-8", res, "outputs/e41_resumo.csv", row.names = FALSE)
if (registrar) for (a in names(amostras)) for (n in unique(res$modelo)) {
  registrar_experimento(res[res$amostra == a, ], n, "p1;alvo=regionais;cortes=1-11;min_treino=8;fontes=bcb+bcb_est+bcb_mun", a, commit)
}
r <- res[res$amostra == "2007-2025 sem 2020-22" & res$corte %in% c(3, 6, 9), ]
print(r[, intersect(c("corte", "modelo", "n", "ME", "MAE", "RMSE"), names(r))], row.names = FALSE)
