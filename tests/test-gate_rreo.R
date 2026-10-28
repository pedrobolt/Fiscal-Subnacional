library(testthat)
source_utf8("../R/models/fatia_minima.R")
source_utf8("../R/evaluation/backtest_fatia.R")
source_utf8("../R/evaluation/gate_rreo.R")

serie_sint <- function(anos, f) {
  d <- expand.grid(mes = 1:12, ano = anos)
  data.frame(data = as.Date(sprintf("%d-%02d-01", d$ano, d$mes)), valor_bi = f(d$ano, d$mes))
}

test_that("SRW = acumulado até o corte + restante do ano anterior (janela 1)", {
  s <- serie_sint(2020:2021, function(a, m) ifelse(a == 2020, m, 10))
  # 2021, corte 3: acumulado 3*10 = 30; resto de 2020 (meses 4..12) = 4+...+12 = 72
  expect_equal(prever_srw(s, 2021, 3), 30 + 72)
})

test_that("bimestres no corte: bimestre b só entra com o mês 2b+1", {
  expect_equal(bimestres_no_corte(1:11), c(0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5))
})

test_that("primário dos estados soma 27 UFs e usa a coluna certa por layout", {
  linha <- function(uf, ano, per, cod, col, v) data.frame(anexo = "RREO-Anexo 06", exercicio = ano, periodo = per, cod_ibge = uf,
                                                       cod_conta = cod, coluna = col, valor = v, stringsAsFactors = FALSE)
  l <- rbind(
    do.call(rbind, lapply(1:27, function(u) linha(u, 2019, 6, "RREO6ResultadoPrimarioEstadosMunicipios", "VALOR INCORRIDO", 1e9))),
    do.call(rbind, lapply(1:27, function(u) linha(u, 2021, 6, "RREO6ResultadoPrimarioEstadosMunicipios", "VALOR", 2e9))),
    do.call(rbind, lapply(1:27, function(u) linha(u, 2024, 6, "ResultadoPrimarioSemRPPSAcimaDaLinha", "VALOR", -1e9))),
    do.call(rbind, lapply(1:26, function(u) linha(u, 2018, 6, "RREO6ResultadoPrimarioEstadosMunicipios", "VALOR INCORRIDO", 1e9))))
  x <- rreo_primario_estados(l)
  expect_equal(x$valor_bi[x$ano == 2019], 27); expect_equal(x$valor_bi[x$ano == 2021], 54)
  expect_equal(x$valor_bi[x$ano == 2024], -27); expect_true(is.na(x$valor_bi[x$ano == 2018]))
})

test_that("resumo_vs_srw compara só ano x corte em que todos os modelos têm previsão", {
  bt <- rbind(
    data.frame(ano = 2020:2021, corte = 3, modelo = "srw", previsao = c(1, 1), realizado = c(0, 0), erro = c(1, 1)),
    data.frame(ano = 2020:2021, corte = 3, modelo = "m", previsao = c(NA, 0.5), realizado = c(0, 0), erro = c(NA, 0.5)))
  r <- resumo_vs_srw(bt)
  expect_equal(r$n[r$modelo == "m"], 1); expect_equal(r$n[r$modelo == "srw"], 1)
  expect_equal(r$rmse_rel_srw[r$modelo == "m"], 0.5)
})
