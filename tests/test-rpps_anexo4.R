library(testthat)
source_utf8("../R/transform/rpps_anexo4.R")

test_that("colunas do Anexo 4 por exercicio", {
  expect_true(coluna_a4("Até o Bimestre / 2019", 2019, "receita")); expect_false(coluna_a4("Até o Bimestre / 2018", 2019, "receita"))
  expect_true(coluna_a4("DESPESAS LIQUIDADAS ATÉ O BIMESTRE / 2020", 2020, "liquidada"))
  expect_true(coluna_a4("RECEITAS REALIZADAS ATÉ O BIMESTRE (b)", 2023, "receita"))
  expect_true(coluna_a4("DESPESAS LIQUIDADAS ATÉ O BIMESTRE (e)", 2023, "liquidada")); expect_true(coluna_a4("DESPESAS PAGAS ATÉ O BIMESTRE (f)", 2023, "paga"))
  expect_false(coluna_a4("PREVISÃO ATUALIZADA (a)", 2023, "receita"))
})

test_that("liquido do RPPS soma os dois planos, tira rendimentos na variante e trata plano ausente", {
  mk <- function(cod, ex, conta, col, v) data.frame(cod_ibge = cod, exercicio = ex, periodo = 6L, anexo = "RREO-Anexo 04", cod_conta = conta, coluna = col, valor = v, baixado_em = Sys.time())
  x <- rbind(mk(1, 2023, "TotalReceitasRPPSFinanceiro", "RECEITAS REALIZADAS ATÉ O BIMESTRE (b)", 100),
             mk(1, 2023, "TotalReceitasRPPSPrevidenciario", "RECEITAS REALIZADAS ATÉ O BIMESTRE (b)", 50),
             mk(1, 2023, "TotalDasDespesasRPPSFinanceiro", "DESPESAS LIQUIDADAS ATÉ O BIMESTRE (e)", 160),
             mk(1, 2023, "TotalDasDespesasRPPSPrevidenciario", "DESPESAS LIQUIDADAS ATÉ O BIMESTRE (e)", 20),
             mk(1, 2023, "ReceitasDeValoresMobiliariosPrevidenciariasBrutasPrevidenciario", "RECEITAS REALIZADAS ATÉ O BIMESTRE (b)", 10),
             mk(2, 2023, "TotalReceitasRPPSPrevidenciario", "RECEITAS REALIZADAS ATÉ O BIMESTRE (b)", 30),    # só capitalização
             mk(2, 2023, "TotalDasDespesasRPPSPrevidenciario", "DESPESAS LIQUIDADAS ATÉ O BIMESTRE (e)", 5))
  d <- rpps_liquido_a4(x)
  expect_equal(d$liquido[d$cod_ibge == 1], -30); expect_equal(d$liquido_sem_rendimentos[d$cod_ibge == 1], -40)
  expect_equal(d$liquido[d$cod_ibge == 2], 25)
  expect_equal(nrow(rpps_liquido_a4(x[0, ])), 0L)
})

test_that("aportes do Tesouro entram no liquido consolidado", {
  mk <- function(cod, ex, conta, col, v) data.frame(cod_ibge = cod, exercicio = ex, periodo = 6L, anexo = "RREO-Anexo 04", cod_conta = conta, coluna = col, valor = v, baixado_em = Sys.time())
  x <- rbind(mk(1, 2023, "TotalReceitasRPPSFinanceiro", "RECEITAS REALIZADAS ATÉ O BIMESTRE (b)", 100), mk(1, 2023, "TotalDasDespesasRPPSFinanceiro", "DESPESAS LIQUIDADAS ATÉ O BIMESTRE (e)", 160),
             mk(1, 2023, "AportesParaAPrevidenciaPlanoFinanceiroInsuficienciaFinanceira", "APORTES REALIZADOS", 50),
             mk(1, 2023, "AportesParaAPrevidenciaPlanoFinanceiroInsuficienciaFinanceira", "PREVISÃO ATUALIZADA (a)", 999))
  d <- rpps_liquido_a4(x)
  expect_equal(d$aportes, 50); expect_equal(d$liquido, -60); expect_equal(d$liquido_consolidado, -10)
})
