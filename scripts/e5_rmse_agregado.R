# E6.2 (pedido de 05/11/2026): erro tipico do crescimento real projetado do TOTAL dos estados, por serie, corte e modelo, nos anos-alvo do backtest do E5 (amostra A).
# RMSE em p.p. do crescimento real: 100 * (soma Thatreal - soma Treal) / soma Treal_ant, nas 27 UFs do ano; por ano-alvo e corte. "sem 2020-21" tira esses anos-alvo.
# Resultado congelado do backtest: data/protocolo/e5_rmse_agregado.csv (a rodada le; refeito na revisao anual). Uso: LC_ALL=C.UTF-8 Rscript scripts/e5_rmse_agregado.R
source("R/utils_io.R", encoding = "UTF-8"); carregar_r("scripts/e5_dados.R"); carregar_r("R/models/e5_producao.R")
D <- e5_montar(); base <- D$base; adocao <- e5_ler_adocao()
pred <- ler_csv(dados("outputs/e5_previsoes.csv")); pred <- pred[pred$amostra == "A" & pred$serie %in% E5_ALVOS & pred$modelo %in% c("B0", "M1", "M2", "M3"), ]
mem <- unique(adocao[adocao$modelo == "M5s4", c("membros")])
P <- pred[, c("serie", "amostra", "faixa", "cod_ibge", "exercicio", "corte", "modelo", "logr_hat")]; P$membros <- ""
for (m in mem) { x <- pred[pred$modelo %in% strsplit(m, "+", fixed = TRUE)[[1]], ]; g <- aggregate(logr_hat ~ serie + amostra + faixa + cod_ibge + exercicio + corte, x, mean); g$modelo <- "M5s4"; g$membros <- m; P <- rbind(P, g[, names(P)]) }
E <- e5_erros(P[, setdiff(names(P), "membros")], base); E$membros <- P$membros[match(paste(E$serie, E$cod_ibge, E$exercicio, E$corte, E$modelo), paste(P$serie, P$cod_ibge, P$exercicio, P$corte, P$modelo))]
E$membros[is.na(E$membros)] <- ""
out <- list()
for (k in split(E, list(E$serie, E$corte, E$modelo, E$membros), drop = TRUE)) {
  a <- do.call(rbind, lapply(split(k, k$exercicio), function(d) if (length(unique(d$cod_ibge)) < 27L) NULL else data.frame(exercicio = d$exercicio[1], e_pp = 100 * (sum(d$Thatreal) - sum(d$Treal)) / sum(d$Treal_ant))))
  if (is.null(a) || !nrow(a)) next
  s <- a[!a$exercicio %in% 2020:2021, ]
  out[[length(out) + 1]] <- data.frame(serie = k$serie[1], corte = k$corte[1], modelo = k$modelo[1], membros = k$membros[1], n_anos = nrow(a), rmse_pp = sqrt(mean(a$e_pp^2)), me_pp = mean(a$e_pp),
    n_anos_sem_2020_21 = nrow(s), rmse_pp_sem_2020_21 = if (nrow(s)) sqrt(mean(s$e_pp^2)) else NA_real_, anos = paste(range(a$exercicio), collapse = "-"))
}
out <- do.call(rbind, out); out <- out[order(out$serie, out$corte, out$modelo, out$membros), ]
gravar_csv(out, file.path("data", "protocolo", "e5_rmse_agregado.csv")); print(out[out$modelo %in% c("B0", "M3", "M5s4") & out$corte %in% c(2, 4, 5), ], digits = 3)
