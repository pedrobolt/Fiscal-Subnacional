library(testthat)
source("../R/download/snapshots.R")
source("../R/download/siconfi_rreo.R")
source("../R/download/extrato.R")
source("../R/download/atualizacao_rreo.R")
source("../R/download/carga_historica.R")

test_that("faixas seguem a ordem aprovada", {
  f <- faixas_carga()
  expect_equal(vapply(f, `[[`, "", "esfera"), c("E", "M", "M"))
  expect_equal(f[[2]]$periodos, 6)
  expect_equal(f[[2]]$anos, 2025:2015)                 # mais recente primeiro
  expect_equal(f[[3]]$anos, 2026:2023)
  expect_equal(f[[3]]$periodos, 1:5)
  expect_false(any(f[[3]]$anos < 2023))                # 2015-2022 b1-5 fica fora (pendência condicionada)
})

test_that("ids_da_esfera: municípios sem o DF; estados com 26 E + DF", {
  entes <- data.frame(cod_ibge = c(1, 11, 53, 5300108, 3550308, 1100015), ente = "x", esfera = c("U", "E", "D", "M", "M", "M"))
  expect_equal(ids_da_esfera(entes, "M"), c(1100015, 3550308))
  expect_equal(ids_da_esfera(entes, "E"), c(11, 53))
})

test_that("trava impede segunda execução da mesma fatia", {
  f <- tempfile(); writeLines("x", f)
  expect_true(trava_ocupada(f))
  Sys.setFileTime(f, Sys.time() - 600)
  expect_false(trava_ocupada(f))
  expect_false(trava_ocupada(tempfile()))
})

test_that("executar_carga exige exatamente 2 processos", {
  expect_error(executar_carga(1, de = 3), "2 processos")
})

test_that("progresso_carga estima as chamadas restantes sem extratos locais", {
  pasta <- tempfile(); dir.create(pasta)
  writeLines(jsonlite::toJSON(list(items = data.frame(cod_ibge = c(11, 12, 53), ente = "x", esfera = c("E", "E", "D")), hasMore = FALSE)),
             file.path(pasta, "_entes_20261024.json"))
  f <- list(list(nome = "t", esfera = "E", anos = 2025, periodos = 6))
  p <- progresso_carga(pasta, f, hoje = as.Date("2026-10-24"))
  expect_equal(p$com_extrato, 0)
  expect_equal(p$chamadas_restantes, 3 * (1 + 2 * 1))
  expect_true(is.na(attr(p, "resumo")$horas_restantes))
})
