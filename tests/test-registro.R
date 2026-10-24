library(testthat)
source("../R/evaluation/registro.R")

resumo <- data.frame(modelo = c("naive", "acumulado", "naive"), corte = c(1, 1, 2),
                     n = 10, ME = 0.1, MAE = 2, RMSE = 3)

test_that("registra linhas do candidato e acrescenta sem sobrescrever", {
  f <- tempfile(fileext = ".csv")
  registrar_experimento(resumo, "naive", "-", "2016-2025", "abc1234", f, data = as.Date("2026-10-23"))
  registrar_experimento(resumo, "acumulado", "janela=5", "2016-2025", "abc1234", f, data = as.Date("2026-10-23"))
  d <- read.csv(f)
  expect_equal(names(d), COLUNAS_REGISTRO)
  expect_equal(nrow(d), 3)
  expect_equal(d$candidato, c("naive", "naive", "acumulado"))
})

test_that("falha para candidato inexistente", {
  expect_error(registrar_experimento(resumo, "ets", "-", "x", "c", tempfile()), "ausente")
})
