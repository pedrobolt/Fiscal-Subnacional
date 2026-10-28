library(testthat)
source_utf8("../R/models/candidatos_restante.R")
source_utf8("../R/evaluation/torneio.R")

# Backtest sintético: base com erros variados; candidato = fator x erro da base (mesmo sinal) em anos x cortes dados
fazer_bt <- function(anos, cortes, fatores, semente = 3) {
  set.seed(semente); linhas <- list()
  for (a in anos) for (m in cortes) {
    real <- 100 + a; eb <- stats::rnorm(1, 2, 5)
    linhas[[length(linhas) + 1]] <- data.frame(ano = a, corte = m, modelo = "base", previsao = real + eb, realizado = real, erro = eb)
    for (n in names(fatores)) linhas[[length(linhas) + 1]] <- data.frame(ano = a, corte = m, modelo = n,
      previsao = real + fatores[[n]] * eb, realizado = real, erro = fatores[[n]] * eb)
  }
  do.call(rbind, linhas)
}

test_that("métricas da faixa: erros pela metade => RMSE -50%, melhor em todos os anos, DM significativo", {
  bt <- fazer_bt(2007:2019, 1:4, list(bom = 0.5))
  m <- metricas_faixa(bt, "bom", "base", 1:4)
  expect_equal(m$rel_RMSE, -0.5); expect_equal(m$share_melhor, 1); expect_equal(m$n_anos, 13); expect_lt(m$DM_p, 0.05)
  expect_equal(m$sinal_c, m$sinal_b)
})

test_that("pareamento descarta anos sem todos os cortes da faixa", {
  bt <- fazer_bt(2007:2012, 1:4, list(bom = 0.5))
  bt <- bt[!(bt$modelo == "bom" & bt$ano == 2010 & bt$corte == 3), ]
  expect_false(2010 %in% parear_faixa(bt, "bom", "base", 1:4)$ano)
  expect_equal(metricas_faixa(bt, "bom", "base", 1:4)$n_anos, 5)
})

test_that("torneio: aceita quem cumpre tudo; elegibilidade e regra das duas amostras", {
  sem <- fazer_bt(2007:2019, 1:11, list(bom = 0.5, igual = 1.0, ruim = 1.3))
  com <- fazer_bt(2007:2025, 1:11, list(bom = 0.5, igual = 1.0, ruim = 1.3))
  t <- torneio_p1(sem, com, c("bom", "igual", "ruim"), base = "base")
  expect_true(all(t$decisao[t$desafiante == "bom"] == "aceito"))
  expect_true(all(t$decisao[t$desafiante == "igual"] == "rejeitado"))
  expect_true(all(t$decisao[t$desafiante == "ruim"] == "rejeitado"))
  # poucos anos => só reportado
  curto <- fazer_bt(2010:2016, 1:11, list(bom = 0.5))
  expect_true(all(torneio_p1(curto, curto, "bom", base = "base")$decisao == "so_reportado"))
  # com 2020–22 muito pior que a base (+30%) derruba a aceitação; pouco pior (+5%) não
  com_ruim <- com; k <- com_ruim$modelo == "bom" & com_ruim$ano %in% 2020:2022; com_ruim$erro[k] <- com_ruim$erro[k] * 20
  com_ruim$previsao[k] <- com_ruim$realizado[k] + com_ruim$erro[k]
  expect_true(all(torneio_p1(sem, com_ruim, "bom", base = "base")$decisao == "rejeitado"))
})

test_that("Holm: a família só tem elegíveis, e o p ajustado é maior ou igual ao bruto", {
  m <- data.frame(DM_p = c(0.01, 0.04), rel_RMSE = -0.2, share_melhor = 0.8, sinal_c = 1, sinal_b = 1, ME_c = 0, ME_b = 1)
  a <- aplicar_criterios(m, c(TRUE, TRUE)); expect_equal(a$p_holm, c(0.02, 0.04 * 1))
  b <- aplicar_criterios(m, c(TRUE, FALSE)); expect_equal(b$p_holm, c(0.01, NA)); expect_false(b$passa[2])
})

test_that("escolha por faixa: sem aceito vale a base; com vários, o de menor RMSE sem 2020–22", {
  tab <- data.frame(faixa = c("1-4", "1-4", "5-8", "5-8"), desafiante = c("a", "b", "a", "b"), decisao = c("aceito", "aceito", "rejeitado", "so_reportado"),
                    RMSE_c_sem = c(5, 4, 9, 9), n_anos_sem = 12, elegivel = c(TRUE, TRUE, TRUE, FALSE))
  e <- escolher_por_faixa(tab, "base")
  expect_equal(e$modelo, c("b", "base")); expect_equal(e$aceitos[1], "a,b"); expect_equal(e$K, c(3, 3))
})

test_that("conferência de reprodutibilidade acusa divergência e ignora diferença de arredondamento", {
  a <- data.frame(modelo = "m", amostra = "x", corte = 1:2, n = 16, ME = c(1, 2), MAE = c(1, 2), RMSE = c(1, 2))
  expect_equal(nrow(conferir_reproducao(a, a)), 0)
  b <- a; b$RMSE[2] <- 2.00005; expect_equal(nrow(conferir_reproducao(b, a)), 0)
  b$RMSE[2] <- 2.01; expect_equal(nrow(conferir_reproducao(b, a)), 1)
  b <- a; b$n[1] <- 15; expect_equal(nrow(conferir_reproducao(b, a)), 1)
})
