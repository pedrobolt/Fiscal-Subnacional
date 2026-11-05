# E6.2: congela em data/protocolo/p1_rmse_relativo.csv o RMSE relativo ao SRW por faixa de corte e candidato do torneio do P1 (docs/nota_p1.md; torneio de 28/10/2026).
# Le outputs/torneio_decisao.csv (rel_RMSE = RMSE do candidato / RMSE da base - 1; sem 2020-22 e todos os anos). Uso: Rscript scripts/p1_rmse_relativo.R
source("R/utils_io.R", encoding = "UTF-8")
x <- ler_csv(dados("outputs/torneio_decisao.csv"))
out <- data.frame(faixa = x$faixa, candidato = x$desafiante, n_anos_sem_2020_22 = x$n_anos_sem, rel_rmse_sem_2020_22 = x$rel_RMSE_sem, n_anos_todos = x$n_anos_com, rel_rmse_todos = x$rel_RMSE_com,
                  rmse_srw_sem_2020_22_bi = x$RMSE_b_sem, rmse_srw_todos_bi = x$RMSE_b_com, decisao = x$decisao, stringsAsFactors = FALSE)
gravar_csv(out, file.path("data", "protocolo", "p1_rmse_relativo.csv")); print(out[out$faixa == "9-11", ], digits = 3)
