library(testthat)
source_utf8("../R/transform/continuidade_rpps.R")

test_that("regressao: inclinacao, HC3 e decisao em casos sinteticos", {
  set.seed(1); x <- seq(0.01, 0.20, length.out = 27)
  mk <- function(delta) data.frame(cod_ibge = rep(1:27, 2), exercicio = rep(c(2022L, 2023L), each = 27), razao = c(rep(0.02, 27), 0.02 + delta), x = c(rep(NA, 27), x))
  r0 <- continuidade_regressao(mk(rnorm(27, 0, 0.002)), 2023)                 # sem relação: inclinação ~ 0
  expect_true(abs(r0$inclinacao) < 0.1); expect_equal(decidir_continuidade(r0$ic_inf, r0$ic_sup), "continua")
  r1 <- continuidade_regressao(mk(x + rnorm(27, 0, 0.002)), 2023)              # delta = x: inclinação ~ 1
  expect_equal(r1$inclinacao, 1, tolerance = 0.1); expect_equal(decidir_continuidade(r1$ic_inf, r1$ic_sup), "nao_continua")
  r2 <- continuidade_regressao(mk(0.5 * x + rep(c(-0.3, 0.3), length.out = 27)), 2023)   # muito ruído: IC largo contém 0 e 1
  expect_equal(decidir_continuidade(r2$ic_inf, r2$ic_sup), "inconclusivo")
  # HC3 bate com o cálculo direto em um caso pequeno
  y <- c(1, 2, 2.5, 4, 5); xx <- c(1, 2, 3, 4, 5); X <- cbind(1, xx); XtXi <- solve(crossprod(X)); b <- XtXi %*% crossprod(X, y); e <- y - X %*% b
  h <- diag(X %*% XtXi %*% t(X)); V <- XtXi %*% t(X) %*% diag(as.vector(e^2 / (1 - h)^2)) %*% X %*% XtXi
  d <- data.frame(cod_ibge = rep(1:5, 2), exercicio = rep(c(2022L, 2023L), each = 5), razao = c(rep(0, 5), y), x = c(rep(NA, 5), xx))
  r <- continuidade_regressao(d, 2023); expect_equal(r$se_hc3, sqrt(V[2, 2])); expect_equal(r$inclinacao, b[2])
})

test_that("razao com RPPS: pre-2023 pela soma dos 6 bimestres, 2023+ pelas linhas XXXIV/XVI e R = com - sem", {
  cu <- data.frame(cod_ibge = 1L, exercicio = 2022L, periodo = 1:6, rec_total = 100, primario_a6 = 5)
  mk <- function(conta, col, v) data.frame(cod_ibge = 1L, exercicio = 2023L, periodo = 6L, cod_conta = conta, coluna = col, valor = v, baixado_em = Sys.time())
  a6 <- rbind(mk("ResultadoPrimarioComRPPSAcimaDaLinha", "VALOR", 40), mk("ResultadoPrimarioSemRPPSAcimaDaLinha", "VALOR", 60), mk("RREO6TotalReceitaPrimaria", "RECEITAS REALIZADAS (a)", 800))
  d <- razao_com_rpps(a6, cu)
  expect_equal(d$razao[d$exercicio == 2022], 30 / 600); expect_equal(d$razao[d$exercicio == 2023], 0.05)
  expect_equal(d$R[d$exercicio == 2023], -20); expect_equal(d$x[d$exercicio == 2023], -20 / 800)
  cu$primario_a6[3] <- NA; expect_true(is.na(razao_com_rpps(a6, cu)$razao[1]))        # ano incompleto -> NA
})
