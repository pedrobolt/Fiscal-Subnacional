library(testthat)
source("../R/models/fatia_minima.R")
source("../R/download/bcb_sgs.R")
source("../R/download/ibge_pib.R")
source("../R/models/candidatos_restante.R")
source("../R/models/candidato_pendencias_rreo.R")

set.seed(1)
serie_sint <- function(anos) {
  d <- expand.grid(mes = 1:12, ano = anos)
  data.frame(data = as.Date(sprintf("%d-%02d-01", d$ano, d$mes)), valor_bi = rnorm(nrow(d)))
}
pib_sint <- function(anos) data.frame(ano = anos, pib_bi = 1000 * 1.1^(anos - min(anos)))

test_that("PIB do IBGE: anual da 6784, completado pela soma de quatro trimestres completos", {
  d1 <- tempfile(fileext = ".json"); d2 <- tempfile(fileext = ".json")
  cab <- list(D2C = "Variável (Código)", D3C = "Ano (Código)", V = "Valor", D3N = "Ano")
  anual <- rbind(cab, data.frame(D2C = c("9808", "9809"), D3C = c("2023", "2023"), V = c("10000000", "9000000"), D3N = "2023"))
  jsonlite::write_json(anual, d1)
  tri <- rbind(data.frame(D3C = "Período", V = "V", D3N = "n"),
               data.frame(D3C = c("202401", "202402", "202403", "202404", "202501", "202502"), V = "1000000", D3N = "tri"))
  jsonlite::write_json(tri, d2)
  p <- pib_ibge_anual(d1, d2)
  expect_equal(p$ano, c(2023L, 2024L)); expect_equal(p$pib_bi, c(10000, 4000)); expect_equal(p$fonte, c("6784", "1846"))
})

test_that("painel: acumulado + restante = total; r_lag usa o PIB do ano anterior; dummies de eleição", {
  s <- serie_sint(1998:2012); p <- painel_restante(s, pib_sint(1998:2012), cortes = 6)
  l <- p[p$ano == 2006, ]
  expect_equal(l$A + l$R, soma_meses(s, 2006, 1:12))
  expect_equal(l$r_lag, soma_meses(s, 2005, 7:12) / pib_sint(1998:2012)$pib_bi[8])
  expect_equal(c(l$E, l$Emun), c(1L, 0L)); expect_equal(p$Emun[p$ano == 2008], 1L)
})

test_that("previsão rolante não usa o futuro nem os anos excluídos", {
  s <- serie_sint(1998:2015); pib <- pib_sint(1998:2015)
  p <- painel_restante(s, pib, cortes = 6)
  base <- prever_restante(p, 2012, ESPEC_RESTANTE$m3)
  p2 <- p; p2[p2$ano > 2012, c("r", "a", "r_lag")] <- 99      # futuro adulterado
  expect_equal(prever_restante(p2, 2012, ESPEC_RESTANTE$m3), base)
  p3 <- p; p3[p3$ano == 2009, "r"] <- 99                      # ano excluído adulterado
  expect_equal(prever_restante(p3, 2012, ESPEC_RESTANTE$m3, excluir = 2009), prever_restante(p, 2012, ESPEC_RESTANTE$m3, excluir = 2009))
  expect_true(is.na(prever_restante(p, 2003, ESPEC_RESTANTE$m3)))   # menos de 8 anos de treino
})

test_that("SRW em % do PIB repete o restante do ano anterior em % do PIB", {
  s <- serie_sint(1998:2010); pib <- pib_sint(1998:2010); p <- painel_restante(s, pib, cortes = 4)
  r <- prever_restante(p, 2008, ESPEC_RESTANTE$srw_pib)
  expect_equal(r, soma_meses(s, 2007, 5:12) / pib$pib_bi[pib$ano == 2007])
})

test_that("DM: positivo quando o modelo erra menos; NA com amostra pequena", {
  set.seed(2); base <- rnorm(20); mod <- base * 0.5
  r <- dm_teste(mod, base); expect_gt(r[["stat"]], 0); expect_lt(r[["p"]], 0.05)
  expect_true(is.na(dm_teste(1:3, 3:1)[["stat"]]))
})

test_that("backtest e resumo: MASE da base = 1 e amostras pareadas", {
  s <- serie_sint(1998:2016); pib <- pib_sint(1998:2016); p <- painel_restante(s, pib, cortes = c(3, 8))
  bt <- backtest_restante(p, 2007:2015, especs = ESPEC_RESTANTE[c("srw_pib", "m3")], excluir = 2010)
  expect_false(2010 %in% bt$ano)
  r <- resumir_restante(bt)
  expect_equal(r$MASE_srw[r$modelo == "srw_pib"], c(1, 1)); expect_equal(unique(r$n), 8)
})

test_that("pendências dos estados: empenhada - paga + RP processados, soma das 27 UFs", {
  l <- function(uf, conta, col, v) data.frame(anexo = "RREO-Anexo 06", exercicio = 2024, periodo = 2, cod_ibge = uf,
                                              cod_conta = conta, coluna = col, valor = v, stringsAsFactors = FALSE)
  d <- do.call(rbind, lapply(1:27, function(u) rbind(
    l(u, "RREO6TotalDespesaPrimaria", "DESPESAS EMPENHADAS", 10e9), l(u, "RREO6TotalDespesaPrimaria", "DESPESAS  PAGAS (a)", 7e9),
    l(u, "RestosAPagarProcessadosExcetoPrecatorios", "Até o Bimestre 2024 (b)", 1e9))))
  p <- pendencias_estados(d)
  expect_equal(p$pend_bi, 27 * (10 - 7 + 1))
})
