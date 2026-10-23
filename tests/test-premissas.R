library(testthat)
source("../R/premissas.R")

escreve <- function(ipca = "0.045", pib_real = "0.02", pib_nom = "13000", extra = "") {
  f <- tempfile(fileext = ".yml")
  writeLines(c('versao: "2026-10-01"', 'fonte: "teste"',
               "ipca:", paste0("  2026: ", ipca), "  2027: null",
               "pib_real:", paste0("  2026: ", pib_real), "  2027: null",
               "pib_nominal:", paste0("  2026: ", pib_nom), "  2027: null", extra), f)
  f
}

test_that("lê premissas válidas e mantém anos futuros em branco como NA", {
  p <- ler_premissas(escreve(), ano_t = 2026)
  expect_equal(p$anos$pib_nominal[p$anos$ano == 2026], 13000)
  expect_true(is.na(p$anos$ipca[p$anos$ano == 2027]))
  expect_equal(p$versao, "2026-10-01")
})

test_that("falha se o ano t estiver em branco", {
  expect_error(ler_premissas(escreve(pib_nom = "null"), ano_t = 2026), "pib_nominal")
})

test_that("falha se o ano t não existir", {
  expect_error(ler_premissas(escreve(), ano_t = 2030), "ausente")
})

test_that("falha com erro de unidade", {
  expect_error(ler_premissas(escreve(ipca = "4.5"), ano_t = 2026), "IPCA")
  expect_error(ler_premissas(escreve(pib_nom = "13"), ano_t = 2026), "PIB nominal")
})

test_that("falha com arquivo inexistente", {
  expect_error(ler_premissas("nao_existe.yml", ano_t = 2026), "encontrado")
})
