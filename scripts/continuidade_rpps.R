# E3.6 (cont.): continuidade da serie com RPPS por UF. Criterio fixado em docs/nota_gap.md (secao 5.4) em commit anterior ao calculo.
# delta_i = (resultado/receita)_2023 - (resultado/receita)_2022, versao com RPPS; x_i = R_i / receita_i, R = XXXIV - XXXV (Anexo 6, 2023).
# Regressao MQO delta ~ x, 27 UFs, HC3, t(n-2); decisao pelo IC 95% (0 dentro e 1 fora = continua; 1 dentro e 0 fora = nao continua; resto = inconclusivo).
# Robustez: 2024 contra 2022. Saidas (git-ignored): outputs/continuidade_rpps_uf.csv, continuidade_rpps_resumo.csv.
# Uso: LC_ALL=C.UTF-8 Rscript scripts/continuidade_rpps.R
source("R/utils_io.R", encoding = "UTF-8"); source("R/transform/continuidade_rpps.R", encoding = "UTF-8")
for (f in c("R/download/snapshots.R", "R/download/siconfi_rreo.R", "R/transform/rreo.R")) source(f, encoding = "UTF-8")
a6 <- ler_rreo_pasta("data/raw/rreo", "E"); a6 <- a6[a6$anexo == "RREO-Anexo 06" & a6$periodo == 6L, ]
cu <- ler_csv("outputs/conceito_unico_bimestral.csv"); d <- razao_com_rpps(a6, cu[cu$exercicio == 2022, ]); gravar_csv(d, "outputs/continuidade_rpps_uf.csv")
res <- do.call(rbind, lapply(c(2023, 2024), function(ex) { r <- continuidade_regressao(d, ex); r$decisao <- decidir_continuidade(r$ic_inf, r$ic_sup); r }))
gravar_csv(res, "outputs/continuidade_rpps_resumo.csv"); options(width = 200); print(res, row.names = FALSE)
