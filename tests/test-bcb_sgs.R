library(testthat)
source_utf8("../R/download/bcb_sgs.R")

test_that("ler_sgs lê o JSON do SGS e ordena por data", {
  f <- tempfile(fileext = ".json")
  writeLines('[{"data":"01/02/2020","valor":"-200.5"},{"data":"01/01/2020","valor":"100"}]', f)
  d <- ler_sgs(f)
  expect_equal(d$data, as.Date(c("2020-01-01", "2020-02-01")))
  expect_equal(d$valor, c(100, -200.5))
})

test_that("ler_sgs falha com formato inesperado", {
  f <- tempfile(fileext = ".json")
  writeLines('{"erro":"x"}', f)
  expect_error(ler_sgs(f), "inesperado")
})

test_that("primario_bi inverte o sinal (superávit positivo) e converte para R$ bi", {
  d <- primario_bi(data.frame(data = as.Date("2021-12-01"), valor = -12798.31))
  expect_equal(d$valor_bi, 12.79831)
})

test_that("baixar_sgs reaproveita o arquivo do mesmo dia sem baixar de novo", {
  pasta <- tempfile(); dir.create(pasta)
  hoje <- as.Date("2026-10-23")
  alvo <- file.path(pasta, "bcb_sgs_4642_20261023.json")
  writeLines("[]", alvo)
  expect_equal(baixar_sgs(4642, as.Date("2020-01-01"), hoje, pasta = pasta, hoje = hoje), alvo)
  expect_equal(readLines(alvo), "[]")
})

test_that("url_sgs usa o formato de data do SGS", {
  expect_match(url_sgs(4642, as.Date("2005-01-01"), as.Date("2026-10-23")),
               "sgs.4642/dados\\?formato=json&dataInicial=01/01/2005&dataFinal=23/10/2026")
})
