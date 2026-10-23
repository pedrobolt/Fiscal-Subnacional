library(testthat)
source("../R/models/fatia_minima.R")
source("../R/evaluation/backtest_fatia.R")

# Série sintética: padrão sazonal fixo 1..12 todo ano (total anual = 78), 2010-2026
serie_sazonal <- function(fator = function(ano) 1) {
  datas <- seq(as.Date("2010-01-01"), as.Date("2026-12-01"), by = "month")
  mes <- as.integer(format(datas, "%m")); ano <- as.integer(format(datas, "%Y"))
  data.frame(data = datas, valor_bi = mes * fator(ano))
}

test_that("naive devolve o total do ano anterior", {
  expect_equal(prever_naive(serie_sazonal(), 2020, 6), 78)
})

test_that("acumulado é exato quando a sazonalidade é fixa", {
  s <- serie_sazonal()
  for (m in 1:11) expect_equal(prever_acumulado(s, 2020, m), 78)
})

test_that("sem vazamento: alterar dados após o cutoff não muda a previsão", {
  s <- serie_sazonal()
  s2 <- s; s2$valor_bi[s2$data > as.Date("2020-06-01")] <- 9999
  # só meses > cutoff do ano t e posteriores mudam; anos anteriores seguem iguais
  s2$valor_bi[s2$data < as.Date("2020-01-01")] <- s$valor_bi[s$data < as.Date("2020-01-01")]
  expect_equal(prever_acumulado(s2, 2020, 6), prever_acumulado(s, 2020, 6))
  expect_equal(prever_naive(s2, 2020, 6), prever_naive(s, 2020, 6))
})

test_that("info_disponivel corta no mês do cutoff", {
  s <- info_disponivel(serie_sazonal(), 2020, 3)
  expect_equal(max(s$data), as.Date("2020-03-01"))
})

test_that("backtest: erro zero com sazonalidade fixa e estrutura correta", {
  bt <- rodar_backtest(serie_sazonal(), anos = 2016:2025)
  expect_equal(nrow(bt), 10 * 11 * 2)
  expect_true(all(abs(bt$erro) < 1e-9))
  r <- resumir_erros(bt)
  expect_equal(nrow(r), 11 * 2)
  expect_true(all(r$RMSE < 1e-9))
})

test_that("backtest: nível diferente por ano gera viés no naive igual à variação", {
  s <- serie_sazonal(function(ano) 1 + 0.1 * (ano - 2010))   # total cresce 7.8 por ano
  bt <- rodar_backtest(s, anos = 2016:2020)
  nv <- bt[bt$modelo == "naive", ]
  expect_equal(unique(round(nv$erro, 8)), -7.8)
})

test_that("prever_ano_corrente usa o último mês publicado de ano_t", {
  s <- serie_sazonal(); s <- s[s$data <= as.Date("2026-08-01"), ]
  p <- prever_ano_corrente(s, 2026)
  expect_equal(unique(p$corte), 8)
  expect_equal(p$previsao, c(78, 78))
})

test_that("com_pct_pib divide pelo PIB nominal do ano", {
  prem <- list(anos = data.frame(ano = 2026, pib_nominal = 13641))
  r <- com_pct_pib(data.frame(ano = 2026, previsao = 136.41), prem)
  expect_equal(r$pct_pib, 1)
})
