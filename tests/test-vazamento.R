library(testthat)
source("../R/models/fatia_minima.R")
source("../R/evaluation/backtest_fatia.R")
source("../R/models/candidatos_restante.R")
source("../R/models/candidatos_p1.R")
source("../R/evaluation/vazamento.R")

set.seed(10)
anos <- 1998:2016
bcb <- local({ d <- expand.grid(mes = 1:12, ano = anos); data.frame(data = as.Date(sprintf("%d-%02d-01", d$ano, d$mes)), valor_bi = rnorm(nrow(d), 0, 3)) })
pib <- data.frame(ano = anos, pib_bi = 1000 * 1.1^(anos - 1998))
rreo <- data.frame(available_at = as.Date("2008-01-01") + seq(0, 3000, by = 30), valor = rnorm(101))
fontes <- list(bcb = bcb, pib = pib, rreo = rreo, stn = rreo, ldo = rreo)

test_that("data de divulgação do BCB: último dia útil do mês seguinte; calendário real tem precedência", {
  expect_equal(data_divulgacao_bcb(2026, 8), as.Date("2026-09-30"))    # quarta
  expect_equal(data_divulgacao_bcb(2026, 1), as.Date("2026-02-27"))    # 28/02 é sábado
  expect_equal(data_divulgacao_bcb(2026, 12), as.Date("2027-01-29"))   # 31/01/2027 é domingo
  cal <- data.frame(ano = 2026, mes = 8, data = as.Date("2026-09-28"))
  expect_equal(data_divulgacao_bcb(2026, 8, cal), as.Date("2026-09-28"))
})

test_that("montar_info: BCB até o mês m; RREO/STN/LDO só com available_at <= data de corte (inclusive)", {
  info <- montar_info(fontes, 2010, 6)
  expect_equal(max(info$bcb$data), as.Date("2010-06-01"))
  expect_equal(max(info$pib$ano), 2010)
  corte <- data_divulgacao_bcb(2010, 6)
  f <- fontes; f$rreo <- data.frame(available_at = corte + c(-1, 0, 1), valor = 1:3)
  expect_equal(montar_info(f, 2010, 6)$rreo$valor, c(1, 2))
  f$stn <- data.frame(valor = 1)
  expect_error(montar_info(f, 2010, 6), "available_at")
})

test_that("nenhum candidato do P1 muda quando o futuro é perturbado", {
  r <- testar_vazamento(CANDIDATOS_P1, fontes, anos = c(2009, 2012, 2015), cortes = c(1, 4, 8, 11))
  expect_equal(nrow(r), 5 * 3 * 4)
  expect_false(any(r$mudou))
})

test_that("o teste detecta vazamento: oráculo com fontes sem filtro muda; com filtro real não", {
  oraculo <- list(oraculo = function(info, ano_t, m) soma_meses(info$bcb, ano_t, 1:12))
  vaz <- testar_vazamento(oraculo, fontes, anos = 2012, cortes = c(3, 8), montar = montar_info_vazado)
  expect_true(all(vaz$mudou))
  ok <- testar_vazamento(oraculo, fontes, anos = 2012, cortes = c(3, 8))
  expect_false(any(ok$mudou))
  # vazamento via RREO: candidato que soma todo o RREO sem respeitar available_at
  rr <- list(rr = function(info, ano_t, m) sum(info$rreo$valor))
  expect_true(all(testar_vazamento(rr, fontes, 2012, c(3, 8), montar = montar_info_vazado)$mudou))
  expect_false(any(testar_vazamento(rr, fontes, 2012, c(3, 8))$mudou))
})

test_that("adaptadores reproduzem o backtest rolante (mesmos números)", {
  painel <- painel_restante(bcb, pib)
  bt <- backtest_restante(painel, 2010:2012, especs = ESPEC_RESTANTE[c("srw_pib", "m2", "m3")])
  for (i in seq_len(nrow(bt))) {
    b <- bt[i, ]; info <- montar_info(fontes, b$ano, b$corte)
    expect_equal(CANDIDATOS_P1[[b$modelo]](info, b$ano, b$corte), b$previsao, tolerance = 1e-9)
  }
})

test_that("available_at do RREO: HO = data_status; RE = prazo legal + mediana HO da UF x período; falha sem extrato", {
  ext <- data.frame(uf = "DF", exercicio = c(2023, 2024, 2025), periodo = 2,
                    status = c("HO", "HO", "RE"), data_status = as.Date(c("2023-04-10", "2024-04-20", "2025-09-01")))
  r <- available_at_rreo(ext)
  prazo <- function(y) as.Date(sprintf("%d-05-30", y))   # fim de abril + 30 dias = 30/05
  expect_equal(r$available_at[1], as.Date("2023-04-10"))
  atrasos <- c(as.numeric(as.Date("2023-04-10") - prazo(2023)), as.numeric(as.Date("2024-04-20") - prazo(2024)))
  expect_equal(r$available_at[3], prazo(2025) + round(median(atrasos)))
  expect_equal(r$fonte_available_at, c("data_status", "data_status", "mediana_uf_periodo"))
  ext2 <- rbind(ext, data.frame(uf = "AC", exercicio = 2025, periodo = 2, status = "RE", data_status = as.Date("2025-10-01")))
  expect_equal(available_at_rreo(ext2)$fonte_available_at[4], "mediana_nacional_periodo")
  expect_error(available_at_rreo(ext[0, ]), "Extrato ausente")
  expect_error(available_at_rreo(NULL), "Extrato ausente")
})
