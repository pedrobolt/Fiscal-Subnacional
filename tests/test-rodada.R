library(testthat)
source_utf8("../R/utils_io.R")
for (f in c("models/fatia_minima.R", "evaluation/intervalos.R", "evaluation/torneio.R", "pipeline/rodada.R")) source_utf8(file.path("../R", f))

test_that("uma etapa que falha não derruba as outras; status DEGRADADA e código de saída diferente de zero", {
  ctx <- new.env()
  r <- rbind(rodar_etapa("a", function(ctx) assign("x", 1, envir = ctx), ctx),
             rodar_etapa("b", function(ctx) stop("rede fora"), ctx),
             rodar_etapa("c", function(ctx) assign("y", 2, envir = ctx), ctx))
  expect_equal(r$estado, c("ok", "falhou", "ok")); expect_equal(ctx$y, 2)
  st <- status_rodada(r)
  expect_equal(st$status, "DEGRADADA"); expect_true(any(grepl("^b falhou: rede fora", st$problemas)))
  expect_gt(codigo_saida(st$status), 0L)
  ok <- status_rodada(r[r$estado == "ok", ]); expect_equal(ok$status, "OK"); expect_equal(codigo_saida(ok$status), 0L)
  # etapa pulada por opção não é OK; aviso (ex.: PIB aproximado) também degrada
  expect_equal(status_rodada(rbind(r[1, ], etapa_pulada("siconfi", "--sem-download")))$status, "DEGRADADA")
  expect_equal(status_rodada(r[1, ], avisos = "premissas ausentes")$status, "DEGRADADA")
})

test_that("corte efetivo é o do dado, não o da data da rodada", {
  s <- data.frame(data = seq(as.Date("2025-10-01"), as.Date("2026-05-01"), by = "month"), valor_bi = 1)
  c1 <- corte_efetivo(s)
  expect_equal(c(c1$ano_alvo, c1$m), c(2026L, 5L)); expect_false(c1$completo)
  expect_true(corte_efetivo(data.frame(data = as.Date("2025-12-01"), valor_bi = 1))$completo)
})

serie_mensal <- function(v, ini = 2020) data.frame(data = seq(as.Date(sprintf("%d-01-01", ini)), by = "month", length.out = length(v)), valor_bi = v)

test_that("SRW por esfera soma ao SRW regional (linearidade) e a diferença é zero", {
  set.seed(1)
  est <- serie_mensal(rnorm(30)); mun <- serie_mensal(rnorm(30)); reg <- serie_mensal(est$valor_bi + mun$valor_bi)
  p <- p1_srw_esferas(list(regional = reg, estaduais = est, municipais = mun), 2022, 6)
  expect_equal(p$corte_m, rep(6, 3))
  expect_equal(p$previsao_bi[p$esfera == "regional"], p$previsao_bi[p$esfera == "estaduais"] + p$previsao_bi[p$esfera == "municipais"])
  expect_equal(p$dif_regional_vs_soma_bi[p$esfera == "regional"], 0, tolerance = 1e-12)
  # SRW = acumulado até m + restante do ano anterior
  e <- p[p$esfera == "estaduais", ]; expect_equal(e$previsao_bi, e$acumulado_bi + e$restante_ano_anterior_bi)
  # ano completo (m = 12): realizado, sem previsão
  p12 <- p1_srw_esferas(list(regional = reg), 2021, 12); expect_equal(p12$previsao_bi, sum(reg$valor_bi[13:24]))
})

test_that("texto de divulgação usa a cobertura empírica da faixa e nunca 'intervalo de 80%'", {
  cob <- data.frame(faixa = c("1-4", "5-8", "9-11"), cobertura_anos = c(0.58, 0.60, 0.74), anos = 18, contem_80_anos = c(FALSE, FALSE, TRUE))
  expect_match(texto_cobertura(cob, 2), "58%"); expect_match(texto_cobertura(cob, 6), "60%"); expect_match(texto_cobertura(cob, 10), "74%")
  expect_false(any(grepl("ntervalo de 80", vapply(c(2, 6, 10), function(m) texto_cobertura(cob, m), ""))))
  expect_true(is.na(texto_cobertura(cob, 12)))
})

test_that("P2 por categoria: só vale com as 27 UFs; variação contra o mesmo bimestre do ano anterior", {
  f <- rbind(
    data.frame(cod_ibge = 1:27, serie = "rec:ICMS", exercicio = 2025, periodo = 1, valor = 1e9),
    data.frame(cod_ibge = 1:27, serie = "rec:ICMS", exercicio = 2026, periodo = 1, valor = 1.1e9),
    data.frame(cod_ibge = 1:26, serie = "rec:ICMS", exercicio = 2026, periodo = 2, valor = 1e9))
  d <- p2_categorias_bim(f, 2026)
  expect_equal(d$valor_bi[d$periodo == 1], 29.7); expect_equal(d$var_pct[d$periodo == 1], 10, tolerance = 1e-9)
  expect_true(is.na(d$valor_bi[d$periodo == 2])); expect_equal(d$n_ufs[d$periodo == 2], 26L)
})

linhas_arquivo <- function(dia, prev = 10) data.frame(data_rodada = dia, modelo = c("srw_brl", "m3"), esfera = "regional", ano_alvo = 2026L, corte_m = 8L,
  ultimo_dado = "2026-08-01", vintage_bcb = "20261024", pib_ano_alvo_bi = 12000, previsao_bi = prev, intervalo_inf_bi = c(1, NA), intervalo_sup_bi = c(2, NA),
  oficial = c(TRUE, FALSE), commit = "abc1234", status_rodada = "OK", stringsAsFactors = FALSE)

test_that("arquivo de previsões: uma linha por rodada x modelo x ano-alvo; refazer o mesmo dia não duplica; dias anteriores intactos", {
  arq <- tempfile(fileext = ".csv")
  arquivar_previsoes(arq, linhas_arquivo("2026-10-30"))
  a1 <- readLines(arq)
  arquivar_previsoes(arq, linhas_arquivo("2026-10-30"))
  expect_identical(readLines(arq), a1)                                            # idempotente
  arquivar_previsoes(arq, linhas_arquivo("2026-11-30", prev = 11))
  x <- ler_csv(arq); expect_equal(nrow(x), 4L)
  expect_equal(x$previsao_bi[x$data_rodada == "2026-10-30"], c(10, 10))             # rodada anterior intacta
  arquivar_previsoes(arq, linhas_arquivo("2026-11-30", prev = 12))                  # refaz a de novembro com outro valor: substitui
  x <- ler_csv(arq); expect_equal(nrow(x), 4L); expect_equal(unique(x$previsao_bi[x$data_rodada == "2026-11-30"]), 12)
  expect_equal(sum(duplicated(x[, c("data_rodada", "modelo", "esfera", "ano_alvo")])), 0L)
})

test_that("resumo abre com o status, lista o que falhou e é idêntico em duas execuções (sem carimbo)", {
  et <- rbind(data.frame(etapa = "bcb", estado = "falhou", msg = "sem rede", segundos = 1), data.frame(etapa = "p1", estado = "ok", msg = "", segundos = 1))
  st <- status_rodada(et)
  r1 <- resumo_rodada("2026-10-30", st, et); r2 <- resumo_rodada("2026-10-30", st, et)
  expect_identical(r1, r2)
  linhas <- strsplit(r1, "\n")[[1]]
  expect_match(linhas[3], "Status: DEGRADADA"); expect_true(any(grepl("bcb falhou: sem rede", linhas)))
  expect_match(resumo_rodada("2026-10-30", status_rodada(et[2, ]), et[2, ]), "Status: OK")
})
