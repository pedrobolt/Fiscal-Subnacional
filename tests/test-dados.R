library(testthat)

test_that("FISCAL_DADOS define a raiz de dados; sem ela, o caminho relativo fica como está", {
  ant <- Sys.getenv("FISCAL_DADOS", unset = NA)
  on.exit(if (is.na(ant)) Sys.unsetenv("FISCAL_DADOS") else Sys.setenv(FISCAL_DADOS = ant))
  Sys.unsetenv("FISCAL_DADOS")
  expect_equal(raiz_dados(), "."); expect_equal(dados("data/raw/rreo"), "data/raw/rreo"); expect_equal(dados("outputs", "teste"), "outputs/teste")
  Sys.setenv(FISCAL_DADOS = "C:\\fiscal_dados")                                   # como vem do setx no Windows
  expect_equal(raiz_dados(), "C:/fiscal_dados"); expect_equal(dados("data/raw"), "C:/fiscal_dados/data/raw")
  Sys.setenv(FISCAL_DADOS = "/tmp/dados/"); expect_equal(dados("outputs/x.csv"), "/tmp/dados/outputs/x.csv")
})

test_that("funções de download e leitura usam a raiz de dados nos padrões de pasta", {
  source_utf8("../R/download/siconfi_rreo.R"); source_utf8("../R/transform/rreo.R")
  ant <- Sys.getenv("FISCAL_DADOS", unset = NA)
  on.exit(if (is.na(ant)) Sys.unsetenv("FISCAL_DADOS") else Sys.setenv(FISCAL_DADOS = ant))
  Sys.setenv(FISCAL_DADOS = "/tmp/raiz_x")
  expect_equal(eval(formals(ler_rreo_pasta)$pasta), "/tmp/raiz_x/data/raw/rreo")
  expect_equal(eval(formals(baixar_entes)$pasta), "/tmp/raiz_x/data/raw/rreo")
})
