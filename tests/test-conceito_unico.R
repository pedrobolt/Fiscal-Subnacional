library(testthat)
source_utf8("../R/transform/conceito_unico.R")

fat <- data.frame(cod_ibge = 35, exercicio = 2022:2023, categoria = "ICMS", bruto = 100, fundeb = c(0, 15), transf = c(0, 0), outras = 0,
                  sh_fundeb = c(0, .15), sh_transf = c(0, 0))

test_that("conceito do Anexo 6 pelas deducoes da DCA", {
  a6 <- data.frame(cod_ibge = 35, exercicio = 2022:2023, categoria = "ICMS", a6_acum = c(100, 85))
  r <- conceito_deducoes_a6(fat, a6)
  expect_equal(r$conceito, c("nenhuma", "fundeb"))
  expect_equal(r$ded_fundeb_a6, c(FALSE, TRUE)); expect_equal(r$ded_transf_a6, c(FALSE, FALSE))
  r2 <- conceito_deducoes_a6(fat, data.frame(cod_ibge = 35, exercicio = 2022:2023, categoria = "ICMS", a6_acum = c(70, 85)))
  expect_equal(r2$conceito[1], "fora"); expect_true(is.na(r2$ded_fundeb_a6[1]))
})

test_that("ajuste retira o que o A6 nao deduziu, com parcela observada ou mediana", {
  con <- data.frame(cod_ibge = 35, exercicio = 2022:2023, categoria = "ICMS", sh_fundeb = c(0, .15), sh_transf = c(0, 0),
                    ded_fundeb_a6 = c(FALSE, TRUE), ded_transf_a6 = c(FALSE, FALSE), conceito = c("nenhuma", "fundeb"))
  med <- data.frame(categoria = "ICMS", sh_fundeb = .15, sh_transf = .25)
  bb <- data.frame(cod_ibge = 35, categoria = "ICMS", exercicio = 2022:2023, periodo = 1, bruto = 100)
  aj <- ajuste_conceito_unico(bb, con, med)
  expect_equal(aj$ajuste, c(100 * (.15 + .25), 100 * .25))      # 2022: nada deduzido; 2023: só falta a cota-parte
})

test_that("conceito unico nao muda o primario e custeio reconstruido nao quebra na troca", {
  fluxos <- data.frame(cod_ibge = 35, exercicio = rep(2022:2023, each = 1), periodo = 6, rec_total = c(1000, 850), desp_total = c(950, 800), desp_custeio = c(400, 330))
  ajt <- data.frame(cod_ibge = 35, exercicio = 2022:2023, periodo = 6, ajuste_total = c(150, 0), nao_reconstruivel = FALSE)
  x <- aplicar_conceito_unico(fluxos, ajt)
  expect_equal(x$primario_unico, x$primario_a6)
  expect_equal(x$custeio_unico, c(250, 330)); expect_equal(x$rec_unica, c(850, 850))
})

test_that("validacao: custeio nao positivo e quebra na troca sao listados", {
  x <- data.frame(cod_ibge = 35, exercicio = 2018:2021, periodo = 6, rec_total = 1000, rec_unica = 1000, desp_custeio = 400, custeio_unico = c(400, 400, -5, 700),
                  ajuste_total = 0, nao_reconstruivel = FALSE)
  con <- data.frame(cod_ibge = 35, exercicio = 2018:2021, categoria = "ICMS", conceito = c("a", "a", "a", "b"))
  v <- validar_conceito_unico(x, con)
  expect_equal(v$positividade$exercicio, 2020)
  expect_true(nrow(v$trocas) == 1 && v$trocas$exercicio == 2021)
})
