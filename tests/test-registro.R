library(testthat)
source_utf8("../R/evaluation/registro.R")

resumo <- data.frame(modelo = c("naive", "acumulado", "naive"), corte = c(1, 1, 2),
                     n = 10, ME = 0.1, MAE = 2, RMSE = 3)

test_that("registra linhas do candidato e acrescenta sem sobrescrever", {
  f <- tempfile(fileext = ".csv")
  registrar_experimento(resumo, "naive", "-", "2016-2025", "abc1234", f, data = as.Date("2026-10-23"))
  registrar_experimento(resumo, "acumulado", "janela=5", "2016-2025", "abc1234", f, data = as.Date("2026-10-23"))
  d <- read.csv(fileEncoding = "UTF-8", f)
  expect_equal(names(d), COLUNAS_REGISTRO)
  expect_equal(nrow(d), 3)
  expect_equal(d$candidato, c("naive", "naive", "acumulado"))
})

test_that("falha para candidato inexistente", {
  expect_error(registrar_experimento(resumo, "ets", "-", "x", "c", tempfile()), "ausente")
})

test_that("status automático: lista fechada = valido; fora dela = diagnostico", {
  expect_equal(status_candidato(c("srw", "srw_brl", "m3", "naive", "m3_tend", "mom_rreo_g1", "ldo_corrigida", "combinacao")),
               c("valido", "valido", "valido", "diagnostico", "diagnostico", "diagnostico", "valido", "valido"))
  expect_equal(K_P1, 9)
})

test_that("validar_registro aponta os problemas e não acusa um registro correto", {
  f <- tempfile(fileext = ".csv")
  registrar_experimento(resumo, "naive", "-", "2016-2025", "abc1234", f, data = as.Date("2026-10-23"))
  expect_equal(nrow(validar_registro(f, checar_git = FALSE)), 0)
  d <- read.csv(fileEncoding = "UTF-8", f, stringsAsFactors = FALSE)
  ruim <- rbind(d, d[1, ])                                # duplicada
  ruim$status[2] <- "valido"                              # naive não está na lista
  ruim$amostra[2] <- ""; ruim$RMSE[2] <- -1; ruim$corte[2] <- 12
  write.csv(fileEncoding = "UTF-8", ruim, f, row.names = FALSE)
  p <- validar_registro(f, checar_git = FALSE)$problema
  expect_true(all(c("amostra vazia", "corte fora de 1-11", "métrica inválida") %in% p))
  expect_true(any(grepl("fora da lista fechada", p))); expect_true(any(grepl("duplicada", p)))
  d$status <- "ok"; write.csv(fileEncoding = "UTF-8", d, f, row.names = FALSE)
  expect_true(any(grepl("status fora", validar_registro(f, checar_git = FALSE)$problema)))
  d$status <- "valido"; d$commit <- "0000000"; write.csv(fileEncoding = "UTF-8", d, f, row.names = FALSE)
  expect_true(any(grepl("commit inexistente", validar_registro(f, checar_git = TRUE)$problema)))
})
