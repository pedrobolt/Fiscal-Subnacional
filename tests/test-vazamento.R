library(testthat)
source("../R/models/fatia_minima.R")
source("../R/evaluation/backtest_fatia.R")
source("../R/models/candidatos_restante.R")
source("../R/models/candidatos_p1.R")
source("../R/evaluation/vazamento.R")
source("../R/transform/stn.R")

set.seed(10)
anos <- 1998:2016
comp <- function() { d <- expand.grid(mes = 1:12, ano = anos); data.frame(data = as.Date(sprintf("%d-%02d-01", d$ano, d$mes)), valor_bi = rnorm(nrow(d), 0, 3)) }
bcb_est <- comp(); bcb_mun <- comp()
bcb <- data.frame(data = bcb_est$data, valor_bi = bcb_est$valor_bi + bcb_mun$valor_bi)
pib <- data.frame(ano = anos, pib_bi = 1000 * 1.1^(anos - 1998))
rreo <- data.frame(available_at = as.Date("2008-01-01") + seq(0, 3000, by = 30), valor = rnorm(101))
g <- expand.grid(mes = 1:12, ano = 1997:2016); g <- g[order(g$ano, g$mes), ]
stn <- data.frame(ano = g$ano, mes = g$mes, valor_fpe = 5 + 0.3 * (g$ano - 1997) + rnorm(nrow(g), 0, 0.4),
                  valor_fpm = 5.2 + 0.3 * (g$ano - 1997) + rnorm(nrow(g), 0, 0.4), tratamento = "original")
stn$available_at <- available_at_stn(stn$ano, stn$mes)
stn[stn$ano == 2004 & stn$mes == 5, c("valor_fpe", "valor_fpm")] <- NA   # lacuna: sem imputação
fontes <- list(bcb = bcb, bcb_est = bcb_est, bcb_mun = bcb_mun, pib = pib, rreo = rreo, stn = stn, ldo = rreo)

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
  f$ldo <- data.frame(valor = 1)
  expect_error(montar_info(f, 2010, 6), "available_at")
})

test_that("nenhum candidato do P1 muda quando o futuro é perturbado", {
  r <- testar_vazamento(c(CANDIDATOS_P1, CANDIDATOS_DIAGNOSTICO), fontes, anos = c(2009, 2012, 2015), cortes = c(1, 4, 8, 11))
  expect_equal(nrow(r), 11 * 3 * 4)
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

test_that("E4.1 = m3 por componente (soma) com a dummy de eleição do próprio componente", {
  info <- montar_info(fontes, 2012, 8)
  est <- prever_total_restante(info, 2012, 8, ESPEC_M3_ESTADOS, serie = info$bcb_est)
  mun <- prever_total_restante(info, 2012, 8, ESPEC_M3_MUNICIPIOS, serie = info$bcb_mun)
  expect_equal(CANDIDATOS_P1$e41(info, 2012, 8), est + mun)
  expect_equal(deparse(ESPEC_M3_MUNICIPIOS$formula), "r ~ a + r_lag + Emun")
  expect_equal(deparse(ESPEC_M3_ESTADOS$formula), "r ~ a + r_lag + E")
  expect_equal(CANDIDATOS_DIAGNOSTICO$diag_e41_est_m3(info, 2012, 8), est + prever_srw(info$bcb_mun, 2012, 8))
})

test_that("combinação: média simples dos disponíveis, sem pesos estimados; NA fora da média", {
  info <- montar_info(fontes, 2012, 8)
  p <- vapply(CANDIDATOS_P1_BASE, function(f) f(info, 2012, 8), numeric(1))
  expect_equal(prever_combinacao(info, 2012, 8), mean(p))
  expect_equal(prever_combinacao(info, 2012, 8, candidatos = list(a = function(i, t, m) 1, b = function(i, t, m) NA_real_, c = function(i, t, m) 3)), 2)
  expect_true(is.na(prever_combinacao(info, 2012, 8, candidatos = list(a = function(i, t, m) NA_real_))))
  # com poucos anos de treino, m2/m3/e41 ainda não existem: a combinação usa os que há
  info0 <- montar_info(fontes, 2003, 8); info0$excluir <- integer(0)
  expect_true(is.na(CANDIDATOS_P1$m3(info0, 2003, 8)))
  expect_false(is.na(prever_combinacao(info0, 2003, 8)))
})

test_that("backtest_p1: usa montar_info, exclui anos e devolve erro em R$ e p.p. do PIB", {
  bt <- backtest_p1(CANDIDATOS_P1["srw_brl"], fontes, 2010:2012, cortes = 8, excluir = 2011)
  expect_equal(sort(unique(bt$ano)), c(2010, 2012))
  expect_equal(bt$erro_pp, bt$erro / bt$pib * 100)
})

test_that("fpe_fpm: g usa só meses disponíveis; lacuna vira NA; o candidato reage à STN (o teste de vazamento não é trivial)", {
  info <- montar_info(fontes, 2012, 8)
  expect_equal(max(info$stn$ano * 100 + info$stn$mes), 201208)         # o mês m entra no corte m (available_at = divulgação do BCB do mês m)
  expect_false(is.na(CANDIDATOS_P1$fpe_fpm(info, 2012, 8)))
  expect_false(is.na(g_stn(info, 2012, 8)))
  # no corte de jul/2012, ago/2012 ainda não existe: g(2012, 8) seria NA
  expect_true(is.na(g_stn(montar_info(fontes, 2012, 7), 2012, 8)))
  # lacuna em mai/2004: g(2004, m>=5) e g(2005, m>=5) são NA; para m<5 existem
  i7 <- montar_info(fontes, 2012, 11)
  expect_true(is.na(g_stn(i7, 2004, 6))); expect_true(is.na(g_stn(i7, 2005, 6))); expect_false(is.na(g_stn(i7, 2004, 4)))
  # o candidato muda quando um mês disponível muda (prova de que usa a fonte)
  f2 <- fontes; k <- f2$stn$ano == 2011 & f2$stn$mes == 3; f2$stn$valor_fpe[k] <- f2$stn$valor_fpe[k] + 50
  ant <- CANDIDATOS_P1$fpe_fpm(montar_info(fontes, 2012, 11), 2012, 11); dep <- CANDIDATOS_P1$fpe_fpm(montar_info(f2, 2012, 11), 2012, 11)
  expect_false(isTRUE(all.equal(ant, dep)))
  # sem a fonte: falha explícita, nunca m3 em silêncio
  info0 <- montar_info(fontes[setdiff(names(fontes), "stn")], 2012, 8)
  expect_error(CANDIDATOS_P1$fpe_fpm(info0, 2012, 8), "stn")
})

test_that("a combinação inclui fpe_fpm; o conjunto do #25 continua reproduzível e a sem-fpe é diagnóstico", {
  info <- montar_info(fontes, 2012, 11)
  base <- vapply(CANDIDATOS_P1_BASE, function(f) f(info, 2012, 11), numeric(1))
  com <- c(base, fpe_fpm = CANDIDATOS_P1$fpe_fpm(info, 2012, 11))
  expect_equal(CANDIDATOS_P1$combinacao(info, 2012, 11), mean(com, na.rm = TRUE))
  expect_equal(CANDIDATOS_P1_25$combinacao(info, 2012, 11), mean(base, na.rm = TRUE))
  expect_equal(CANDIDATOS_DIAGNOSTICO$diag_combinacao_sem_fpe(info, 2012, 11), mean(base, na.rm = TRUE))
  expect_false("fpe_fpm" %in% names(CANDIDATOS_P1_25))
})

test_that("fpe_fpm com defasagem extra: g usa jan..m-1; no corte 1 não há previsão; mudar o mês m não afeta", {
  i <- montar_info(fontes, 2012, 8)
  expect_equal(g_stn(i, 2012, 8, lag = 1), g_stn(montar_info(fontes, 2012, 7), 2012, 7))
  expect_true(is.na(g_stn(montar_info(fontes, 2012, 1), 2012, 1, lag = 1)))
  f2 <- fontes; k <- f2$stn$ano == 2012 & f2$stn$mes == 8; f2$stn$valor_fpe[k] <- 999
  expect_equal(prever_fpe_fpm_lag1(montar_info(f2, 2012, 8), 2012, 8), prever_fpe_fpm_lag1(i, 2012, 8))
})
