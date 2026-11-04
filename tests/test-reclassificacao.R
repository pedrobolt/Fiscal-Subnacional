library(testthat)
source_utf8("../R/quality/reclassificacao.R")

mk <- function(uf, ex, per, rreo, rgf) data.frame(cod_ibge = uf, exercicio = ex, periodo = per, rreo_yoy = rreo, rgf_yoy = rgf)

test_that("a regra esta fixada nos valores registrados antes de computar", {
  expect_equal(RECLASS_X, 0.25); expect_equal(RECLASS_PP, 0.20); expect_equal(RECLASS_PERSIST, 2L)
  expect_equal(RECLASS_JANELA, c(2024L, 1L))
})

test_that("um bimestre isolado nao e inicio; dois consecutivos sao, inclusive atravessando a virada de ano", {
  y <- rbind(mk(33, 2024, 2, 0.28, 0.03),                                   # salto isolado (falso positivo tipico)
             mk(33, 2025, 5, 0.40, 0.05), mk(33, 2025, 6, 0.35, 0.04), mk(33, 2026, 1, 0.50, 0.04),
             mk(41, 2025, 1, 0.50, 0.05), mk(41, 2025, 3, 0.50, 0.05))      # bimestres nao consecutivos
  r <- runs_reclassificacao(y)
  expect_equal(nrow(r), 1L); expect_equal(r$cod_ibge, 33)
  expect_equal(c(r$ini_exercicio, r$ini_periodo, r$fim_exercicio, r$fim_periodo, r$n_bim), c(2025, 5, 2026, 1, 3))
})

test_that("o RGF acompanhando o RREO (sem salto correspondente) nao sinaliza; RGF ausente quebra a corrida", {
  y <- rbind(mk(11, 2025, 1, 0.40, 0.35), mk(11, 2025, 2, 0.40, 0.35),         # RGF sobe junto: nao e reclassificacao
             mk(12, 2025, 1, 0.40, 0.02), mk(12, 2025, 2, 0.40, NA), mk(12, 2025, 3, 0.40, 0.02))
  expect_equal(nrow(runs_reclassificacao(y)), 0L)
})

test_that("limiares: abaixo de 25% no RREO ou menos de 20 p.p. sobre o RGF nao sinaliza; persistencia 3 exclui corrida de 2", {
  y <- rbind(mk(21, 2025, 1, 0.24, 0.00), mk(21, 2025, 2, 0.24, 0.00),            # abaixo de x
             mk(22, 2025, 1, 0.30, 0.15), mk(22, 2025, 2, 0.30, 0.15),            # dif de 15 p.p.
             mk(23, 2025, 1, 0.30, 0.05), mk(23, 2025, 2, 0.30, 0.05))
  r <- runs_reclassificacao(y); expect_equal(r$cod_ibge, 23)
  expect_equal(nrow(runs_reclassificacao(y, persist = 3L)), 0L)
})

test_that("janela de interesse e excedente da corrida", {
  y <- rbind(mk(43, 2020, 3, 0.40, 0.00), mk(43, 2020, 4, 0.40, 0.00),
             mk(43, 2025, 5, 0.50, 0.10), mk(43, 2025, 6, 0.50, 0.10))
  r <- marcar_janela(runs_reclassificacao(y))
  expect_equal(r$na_janela, c(FALSE, TRUE))
  pes <- data.frame(cod_ibge = 43, exercicio = 2025, periodo = 5:6, valor = c(150, 150))     # base 100, RGF +10% => esperado 110
  dsp <- data.frame(cod_ibge = 43, exercicio = 2025, periodo = 5:6, valor = c(400, 400))
  e <- excedente_runs(r[r$na_janela, ], pes, dsp, y)
  expect_equal(e$excedente, 80); expect_equal(e$excedente_sobre_despesa, 0.1)
})

test_that("a grade de sensibilidade devolve o inicio por UF e combinacao, e NA quando nao ha corrida", {
  y <- rbind(mk(33, 2025, 1, 0.50, 0.02), mk(33, 2025, 2, 0.50, 0.02), mk(41, 2025, 1, 0.20, 0.02), mk(41, 2025, 2, 0.20, 0.02))
  g <- grade_inicio(y, c(33, 41))
  expect_equal(nrow(g), 3 * 3 * 2 * 2)
  a <- g[g$x == 0.25 & g$pp == 0.20 & g$persist == 2, ]
  expect_equal(a$inicio[a$cod_ibge == 33], "2025 b1"); expect_true(is.na(a$inicio[a$cod_ibge == 41]))
  b <- g[g$x == 0.15 & g$pp == 0.10 & g$persist == 2, ]; expect_equal(b$inicio[b$cod_ibge == 41], "2025 b1")
})
