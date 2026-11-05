library(testthat)
source_utf8("../R/utils_io.R")
source_utf8("../R/models/e5.R")
source_utf8("../R/models/e5_producao.R")

ad <- function() e5_ler_adocao(file.path("..", E5_ADOCAO_ARQ))

test_that("adocao de 05/11/2026: um oficial por serie e faixa, como decidido", {
  a <- ad(); of <- a[a$oficial, ]
  expect_false(anyDuplicated(of[, c("serie", "faixa")]) > 0); expect_equal(nrow(of), 6L)
  g <- function(s, f) of$modelo[of$serie == s & of$faixa == f]
  expect_equal(g("rec:total", "b1_b2"), "B0"); expect_equal(g("rec:total", "b3_b4"), "M5s4"); expect_equal(g("rec:total", "b5"), "B0")
  expect_equal(g("desp:total", "b1_b2"), "B0"); expect_equal(g("desp:total", "b3_b4"), "B0"); expect_equal(g("desp:total", "b5"), "M3")
  expect_equal(of$membros[of$serie == "rec:total" & of$faixa == "b3_b4"], "M1+M2+M3")
  expect_false(a$oficial[a$serie == "rec:total" & a$faixa == "b5" & a$modelo == "M5s4"])   # M5 na sombra no b5
})

test_that("faixa do corte e IPCA estendido fecha na premissa", {
  expect_equal(e5_faixa_corte(2), "b1_b2"); expect_equal(e5_faixa_corte(4), "b3_b4"); expect_equal(e5_faixa_corte(5), "b5")
  sgs <- data.frame(data = seq(as.Date("2025-01-01"), as.Date("2026-12-01"), by = "month"), valor = 0.4)
  x <- e5_ipca_estendido(sgs, 2026, 0.05, ate_mes = 8)
  d <- as.Date(x$data); expect_equal(sum(format(d, "%Y") == "2026"), 12L)
  expect_equal(prod(1 + x$valor[format(d, "%Y") == "2026"] / 100), 1.05, tolerance = 1e-9)
  expect_equal(x$valor[format(d, "%Y") == "2026" & as.integer(format(d, "%m")) <= 8], rep(0.4, 8))
})

test_that("corte disponivel exige todas as UFs com ambas as series", {
  P <- expand.grid(periodo = 1:4, exercicio = 2026L, cod_ibge = 1:3, serie = c("rec:total", "desp:total"), stringsAsFactors = FALSE); P$valor <- 1
  expect_equal(e5_corte_disponivel(P, 2026L, n_ufs = 3L), 4L)
  P2 <- P[!(P$cod_ibge == 3L & P$periodo == 4L), ]; expect_equal(e5_corte_disponivel(P2, 2026L, n_ufs = 3L), 3L)
  expect_equal(e5_corte_disponivel(P, 2026L, n_ufs = 4L), 0L)
})

test_that("agregacao exclui UFs e calcula crescimento real e nominal", {
  U <- data.frame(cod_ibge = c(11L, 12L, 41L), serie = "rec:total", modelo = "B0", That = c(110, 220, 330), Treal_hat = c(55, 110, 165), Treal_ant = c(50, 100, 150), T_ant = c(100, 200, 300))
  a <- e5_agregar_cresc(U); expect_equal(a$n_ufs, 3L); expect_equal(a$cresc_real_pct, 10); expect_equal(a$cresc_nominal_pct, 10)
  b <- e5_agregar_cresc(U, excluir = 41L); expect_equal(b$n_ufs, 2L)
})

test_that("plano da faixa: oficial primeiro e sombra completa", {
  p <- e5_plano_faixa(ad(), 5L)
  expect_equal(p$modelo[p$serie == "desp:total" & p$oficial], "M3"); expect_equal(p$modelo[p$serie == "rec:total" & p$oficial], "B0")
  expect_true(all(c("B0", "M1", "M2", "M3") %in% p$modelo[p$serie == "rec:total"]))
  expect_equal(sum(p$oficial), 2L)
})

test_that("salto da troca de metodo da receita M5 -> B0 entre b4 e b5", {
  r <- list(faixa = "b5", cresc = data.frame(conceito = "consolidado", serie = "rec:total", modelo = c("B0", "prev_rec:total"),
    That_bi = c(1500, 1520), cresc_real_pct = c(4.0, 5.0), stringsAsFactors = FALSE))
  s <- e5_salto_troca(r, ad())
  expect_equal(nrow(s), 1L); expect_equal(s$modelo_atual, "B0"); expect_equal(s$modelo_anterior, "M5s4")
  expect_equal(s$salto_pp, -1.0); expect_equal(s$salto_bi, -20)
})
