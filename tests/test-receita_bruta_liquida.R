library(testthat)
source_utf8("../R/transform/receita_bruta_liquida.R")

mk <- function(ex, bruto, transf, a3_12m, cod = 35, cat = "ICMS")
  data.frame(cod_ibge = cod, uf = "XX", exercicio = ex, categoria = cat, bruto = bruto, fundeb = bruto * .15, transf = transf, outras = 0, a3_12m = a3_12m)

test_that("fator, origem, regime e disponibilidade", {
  dca <- do.call(rbind, lapply(list(c(2022, 100, 25, 100), c(2023, 120, 30, 100)), function(v) {
    d <- data.frame(cod_ibge = 35, uf = "SP", exercicio = v[1], categoria = "ICMS", cod = "x", valor = c(v[2], v[2] * .15, v[3]),
                    coluna = c("Receitas Brutas Realizadas", "Dedu - FUNDEB", "Dedu - Transfer_ncias Constitucionais")); d }))
  a3 <- data.frame(cod_ibge = 35, uf = "SP", exercicio = c(2022, 2023), periodo = 6, categoria = "ICMS", tipo = "total12m", mes = as.Date(NA), valor = c(100, 100))
  f <- fatores_dca(dca, a3)
  expect_equal(f$fator, c(1, 1.2)); expect_equal(f$origem, c("a3_direto", "a3_calibrado_dca"))
  expect_equal(f$regime, rep("liquido_cota_parte", 2)); expect_equal(f$disponivel_em, as.Date(c("2023-05-31", "2024-05-31")))
  expect_equal(f$quebra, c(FALSE, TRUE))               # variação de 20% > limite
})

test_that("tempo real usa só fator já disponível", {
  f <- data.frame(exercicio = c(2022, 2023), fator = c(1, 1.2), disponivel_em = as.Date(c("2023-05-31", "2024-05-31")), stringsAsFactors = FALSE)
  expect_equal(fator_disponivel(f, 2023, as.Date("2023-06-15"))$exercicio, 2022)
  expect_equal(fator_disponivel(f, 2024, as.Date("2024-03-01"))$exercicio, 2022)    # 2023 só sai em 31/05/2024
  expect_equal(fator_disponivel(f, 2024, as.Date("2024-06-15"))$exercicio, 2023)
  expect_null(fator_disponivel(f, 2022, as.Date("2022-12-01")))
})

test_that("DF tem regime próprio e quebra de 2022 é sinalizada", {
  dca <- data.frame(cod_ibge = 53, uf = "DF", exercicio = c(2021, 2022), categoria = "ICMS", cod = "x", coluna = "Receitas Brutas Realizadas", valor = c(12, 10))
  a3 <- data.frame(cod_ibge = 53, uf = "DF", exercicio = c(2021, 2022), periodo = 6, categoria = "ICMS", tipo = "total12m", mes = as.Date(NA), valor = c(9.6, 10))
  f <- fatores_dca(dca, a3)
  expect_equal(f$regime, rep("sem_cota_parte", 2)); expect_equal(f$quebra, c(FALSE, TRUE))
})

test_that("data de publicação do mês: fim do bimestre + 30 dias", {
  expect_equal(data_publicacao_mes(as.Date("2024-01-01")), as.Date("2024-03-31"))
  expect_equal(data_publicacao_mes(as.Date("2024-12-01")), as.Date("2025-01-31"))
})
