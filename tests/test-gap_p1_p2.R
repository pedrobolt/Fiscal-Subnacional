library(testthat)
source_utf8("../R/transform/gap_p1_p2.R")

serie <- function(r, ex = 2018L:2022L) {            # r por (ex x 6 bimestres), em ordem temporal
  d <- expand.grid(periodo = 1:6, exercicio = ex); d <- d[order(d$exercicio, d$periodo), c("exercicio", "periodo")]
  d$r <- r; d
}

test_that("referencia sazonal: mesmo bimestre dos anos anteriores, minimo de 2, sem atravessar 2023", {
  d <- serie(rep(0.02, 30)); d$r[d$exercicio == 2020 & d$periodo == 3] <- 0.02
  c1 <- classificar_gap(d)
  expect_equal(c1$classe[d$exercicio == 2018], rep("sem_referencia", 6))
  expect_equal(c1$classe[d$exercicio == 2019], rep("sem_referencia", 6))      # só 1 observação
  expect_true(all(c1$classe[d$exercicio == 2020] == "consistente"))
  d2 <- serie(rep(0.02, 42), 2020L:2026L)
  c2 <- classificar_gap(d2)
  expect_true(all(c2$classe[d2$exercicio %in% 2023:2024] == "sem_referencia"))   # fronteira: sem referência pós-2023
  expect_true(all(c2$classe[d2$exercicio %in% 2025:2026] == "consistente"))
})

test_that("atipico exige 4 x MAD e o piso de 1%", {
  d <- serie(rep(0.02, 30)); i <- which(d$exercicio == 2021 & d$periodo == 2)
  d$r[i] <- 0.025                                  # +0,5 p.p.: abaixo do piso -> consistente
  expect_equal(classificar_gap(d)$classe[i], "consistente")
  d$r[i] <- 0.05                                   # +3 p.p. -> atípico
  expect_equal(classificar_gap(d)$classe[i], "atipico")
  # referência volátil: MAD grande protege (4 x MAD > desvio). Bimestre 2 de 2018-20 com r = 0, 0.06, 0.03 (mediana 0.03, MAD 0.03)
  d <- serie(rep(0.02, 30)); d$r[d$periodo == 2 & d$exercicio == 2018] <- 0; d$r[d$periodo == 2 & d$exercicio == 2019] <- 0.06
  d$r[d$periodo == 2 & d$exercicio == 2020] <- 0.03; d$r[i] <- 0.075
  expect_equal(classificar_gap(d)$classe[i], "consistente")
})

test_that("instavel: 3 de 6 atipicos, ou sinal oposto da mediana acima do piso", {
  d <- serie(rep(0.02, 30)); w <- which(d$exercicio == 2021)[1:6]
  d$r[w[c(1, 3, 5)]] <- 0.08                       # 3 atípicos em 6 bimestres consecutivos
  expect_equal(classificar_gap(d)$classe[w[6]], "instavel")
  d <- serie(rep(0.02, 30)); w <- which(d$exercicio == 2021)[1:6]
  d$r[w] <- -0.02                                  # mediana 6 com sinal oposto e |.| > 1%
  expect_equal(classificar_gap(d)$classe[w[6]], "instavel")
  d <- serie(rep(0.004, 30)); d$r[w] <- -0.005   # sinal oposto mas |mediana| < 1% e dentro do piso: não instável
  expect_false(classificar_gap(d)$classe[w[6]] == "instavel")
})

test_that("sem 2020-22: anos excluidos nao sao referencia nem classificados", {
  d <- serie(rep(0.02, 30)); d$r[d$exercicio %in% 2019:2020] <- 0.2         # referência contaminada de 2021
  i <- which(d$exercicio == 2021 & d$periodo == 1)
  expect_equal(classificar_gap(d, fronteira = 2100L)$classe[i], "atipico")   # com 2019-20 na referência (mediana 0,2), 2021 destoa
  c1 <- classificar_gap(d, excluir_anos = 2020:2022, fronteira = 2100L)
  expect_true(all(c1$classe[d$exercicio %in% 2020:2022] == "excluido"))
  expect_true(all(c1$classe[d$exercicio %in% 2018:2019] == "sem_referencia"))
  s <- resumo_classes(c1$classe)
  expect_equal(sum(s$n), nrow(d)); expect_true(is.na(s$pct_classificaveis[s$classe == "excluido"]))
})

test_that("P1 e P2 por bimestre: sinal, soma de dois meses e UFs completas", {
  sgs <- data.frame(data = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01")), valor = c(1000, 500, -300))   # déficit +
  p1 <- p1_estados_bim(sgs)
  expect_equal(p1$p1[p1$periodo == 1], -1.5); expect_true(is.na(p1$p1[p1$periodo == 2]))           # 2º bimestre incompleto
  x <- data.frame(cod_ibge = 1:3, exercicio = 2024L, periodo = 1L, rec_total = 1e9, primario_a6 = c(1e8, NA, 2e8))
  expect_true(is.na(p2_estados_bim(x, n_ufs = 3L)$p2))
  expect_equal(p2_estados_bim(x[-2, ], n_ufs = 2L)$p2, 0.3)
  g <- gap_bimestral(data.frame(exercicio = 2025L, periodo = 1L, n_ufs = 27L, p2 = 1, rec = 10), data.frame(exercicio = 2025L, periodo = 1L, p1 = 3),
                     data.frame(exercicio = 2025L, periodo = 1L, excedente = 2e9))
  expect_equal(g$g, -2); expect_equal(g$g_sem, 0); expect_true(g$apos_reclass)
})
