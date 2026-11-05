library(testthat)
source_utf8("../R/models/e5.R")
test_that("ipca bimestral e painel: validade, razao e deflator", {
  sgs <- data.frame(data = seq(as.Date("2014-01-01"), by = "month", length.out = 36), valor = 1)
  ind <- e5_ipca_bim(sgs)
  expect_equal(ind(2014, 1), (1.01 + 1.01^2) / 2)
  P <- expand.grid(periodo = 1:6, exercicio = 2014:2015, cod_ibge = 11L, serie = "rec:total", stringsAsFactors = FALSE); P$valor <- 100
  P$valor[P$exercicio == 2015 & P$periodo == 3] <- NA     # ano incompleto fica fora
  pn <- e5_painel(P, ind, "rec:total")
  expect_equal(unique(pn$exercicio), 2014L); expect_equal(pn$A, 100 * 1:5); expect_equal(pn$r, (600 - 100 * 1:5) / (100 * 1:5))
  P$valor[P$exercicio == 2014 & P$periodo == 6] <- -1000  # restante nao positivo no b5
  expect_equal(nrow(e5_painel(P, ind, "rec:total")), 0L)
})
test_that("alvos: ano anterior valido e pelo menos 3 UF-anos validos antes", {
  pn <- data.frame(cod_ibge = 11L, serie = "rec:total", exercicio = rep(c(2015:2018, 2020:2021), each = 5), corte = 1:5, A = 1, T = 2, R = 1, r = 1, Areal = 1, Treal = 2)
  m <- unique(e5_marcar_alvos(pn)[, c("exercicio", "alvo")])
  expect_equal(m$alvo[order(m$exercicio)], c(FALSE, FALSE, FALSE, TRUE, FALSE, TRUE))   # 2018 (3 antes); 2020 sem 2019; 2021 (5 antes e 2020 valido)
})
test_that("dummies de quebra: LC 194, RS 2023 e intra 2023", {
  d <- data.frame(serie = c("rec:total", "rec:total", "rec:total", "desp:total", "desp:total", "desp:pessoal"), cod_ibge = c(35L, 35L, 35L, 43L, 35L, 43L),
                  exercicio = c(2022L, 2022L, 2023L, 2023L, 2023L, 2024L), corte = c(3L, 4L, 2L, 1L, 1L, 1L))
  d <- e5_dummies(d)
  expect_equal(d$d_resto, c(1, 0, 0, 0, 0, 0)); expect_equal(d$d_base, c(0, 0, 1, 0, 0, 0))
  expect_equal(d$d_yoy, c(0, 0, 0, 1, 0, 1)); expect_equal(d$d_intra23, c(0, 0, 0, 1, 1, 0))
})
test_that("estimadores M1-M3 recuperam um efeito conhecido e o criterio aceita o melhor", {
  set.seed(7); n <- 27 * 6
  b <- data.frame(cod_ibge = rep(1:27, 6), exercicio = rep(2016:2021, each = 27), corte = 1L, x1 = rnorm(n), x2 = rnorm(n), x3 = NA_real_, x4 = NA_real_,
                  d_resto = 0, d_base = 0, d_yoy = 0, d_intra23 = 0)
  b$y <- 0.5 * b$x2 + rnorm(n, 0, 0.05)
  tr <- b[b$exercicio < 2021, ]; al <- b[b$exercicio == 2021, ]
  for (m in c("M1", "M2", "M3")) {
    r <- e5_prever(tr, al, c("x1", "x2"), m); expect_equal(r$diag, "ok"); expect_gt(cor(r$yhat, al$y), 0.95)
  }
  # criterios: candidato com erro 0,5x o do B0 em todos os anos passa; sem poder nao passa
  E <- do.call(rbind, lapply(2016:2023, function(a) { u <- 1:27; eb <- rnorm(27, 0, 8)
    rbind(data.frame(modelo = "B0", cod_ibge = u, exercicio = a, corte = 1L, e = eb, acerto = 1), data.frame(modelo = "M1", cod_ibge = u, exercicio = a, corte = 1L, e = 0.5 * eb, acerto = 1)) }))
  cr <- e5_criterios(E, "M1", B = 200)
  expect_true(cr$c1_rmse10 && cr$c2_pares && cr$c3_sinal && cr$c4_vies && cr$c5_boot); expect_equal(cr$razao_rmse, 0.5, tolerance = 0.01)
})
test_that("erros: T_hat = A (1 + r_hat) e erro nulo quando a razao e exata", {
  b <- data.frame(serie = "rec:total", cod_ibge = 11L, exercicio = 2020L, corte = 2L, A = 100, T = 300, Areal = 100, Treal = 300, Treal_ant = 250)
  p <- data.frame(serie = "rec:total", cod_ibge = 11L, exercicio = 2020L, corte = 2L, modelo = c("B0", "M1"), logr_hat = c(log(2), log(1)))
  e <- e5_erros(p, b)
  expect_equal(e$e[e$modelo == "B0"], 0); expect_equal(e$e[e$modelo == "M1"], 100 * (200 - 300) / 300); expect_equal(e$acerto[e$modelo == "B0"], 1)
})
