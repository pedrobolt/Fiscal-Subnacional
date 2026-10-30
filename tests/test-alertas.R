library(testthat)
source_utf8("../R/transform/dicionario_contas.R")
source_utf8("../R/quality/alertas.R")

test_that("(b) salto contra o mesmo bimestre do ano anterior, com MAD do proprio historico e piso", {
  # 7 anos de crescimento estavel (+10 por ano), depois um salto de +200 em 2024
  v <- c(100, 110, 120, 130, 140, 150, 160, 370)
  f <- data.frame(cod_ibge = 35, serie = "pessoal", exercicio = 2017:2024, periodo = 1, valor = v)
  rt <- data.frame(cod_ibge = 35, exercicio = 2017:2024, periodo = 1, rec_total = 5000)
  a <- alerta_salto(f, rt)
  expect_equal(a$exercicio, 2024L); expect_equal(a$tipo, "b")
  # variacao normal nao alerta; piso de 1% impede alerta quando a receita é enorme
  expect_equal(nrow(alerta_salto(f[-8, ], rt[-8, ])), 0)
  rt$rec_total <- 1e6; expect_equal(nrow(alerta_salto(f, rt)), 0)
})

test_that("(b) historico curto nao gera alerta e sazonalidade nao confunde", {
  f <- data.frame(cod_ibge = 1, serie = "x", exercicio = 2022:2024, periodo = 1, valor = c(10, 11, 500))
  rt <- data.frame(cod_ibge = 1, exercicio = 2022:2024, periodo = 1, rec_total = 100)
  expect_equal(nrow(alerta_salto(f, rt)), 0)
  # bimestres com nivel muito diferente (sazonal) mas estaveis contra o proprio bimestre do ano anterior
  g <- rbind(data.frame(cod_ibge = 1, serie = "x", exercicio = 2018:2023, periodo = 1, valor = 100 + 5 * 0:5),
             data.frame(cod_ibge = 1, serie = "x", exercicio = 2018:2023, periodo = 2, valor = 900 + 5 * 0:5))
  rt2 <- expand.grid(cod_ibge = 1, exercicio = 2018:2023, periodo = 1:2, rec_total = 2000)
  expect_equal(nrow(alerta_salto(g, rt2)), 0)
})

test_that("(b) suspeita de reclassificacao: RREO acima do RGF em mais de 20 p.p.", {
  y <- data.frame(rreo_yoy = c(.5, .1, NA), rgf_yoy = c(.05, .05, .1))
  expect_equal(marcar_reclassificacao(y)$suspeita_reclassificacao, c(TRUE, FALSE, FALSE))
})

test_that("(c) flags viram alertas", {
  x <- data.frame(cod_ibge = c(14, 35), exercicio = 2019, periodo = 1, conceito_original = c(TRUE, FALSE),
                  flag_custeio_nao_positivo = c(FALSE, TRUE), flag_quebra_troca = FALSE)
  a <- alerta_flags(x)
  expect_equal(sort(a$subtipo), c("conceito_original", "custeio_nao_positivo"))
})

test_that("(d) entrega ausente, atrasada e retificada; so conta apos o prazo", {
  esp <- data.frame(cod_ibge = c(1, 2, 3, 4), exercicio = 2024, periodo = 1)       # prazo: 28/02 + 30 d... 
  ext <- data.frame(cod_ibge = c(2, 3, 4), exercicio = 2024, periodo = 1, tipo = "RREO", status = c("HO", "HO", "RE"),
                    data_status = as.POSIXct(c("2024-04-20", "2024-03-25", "2024-05-01"), tz = "UTC"))
  a <- alerta_entrega(ext, esp, hoje = as.Date("2024-06-30"))
  expect_equal(a$subtipo[a$cod_ibge == 1], "entrega_ausente")
  expect_equal(a$subtipo[a$cod_ibge == 2], "entrega_atrasada")
  expect_equal(a$subtipo[a$cod_ibge == 4], "retificacao")
  expect_false(3 %in% a$cod_ibge)
  expect_equal(nrow(alerta_entrega(ext, esp, hoje = as.Date("2024-03-15"))), 0)      # antes do prazo: nada
})

test_that("(a) conta nova fora do conjunto conhecido", {
  a <- alerta_contas_conhecidas(c("ICMS", "NovaConta"), c("ICMS", "IPVA"), "RGF-Anexo 01")
  expect_equal(nrow(a), 1); expect_match(a$serie, "NovaConta")
  expect_equal(nrow(alerta_contas_conhecidas("ICMS", c("ICMS"), "x")), 0)
})

test_that("yoy do pessoal RREO x RGF e suspeita de reclassificacao", {
  fl <- rbind(data.frame(cod_ibge = 1, serie = "desp:pessoal", exercicio = 2024:2025, periodo = 1, valor = c(100, 200)),
              data.frame(cod_ibge = 2, serie = "desp:pessoal", exercicio = 2024:2025, periodo = 1, valor = c(100, 110)))
  g <- data.frame(cod_ibge = rep(1:2, each = 4), mes = rep(as.Date(c("2024-01-01", "2024-02-01", "2025-01-01", "2025-02-01")), 2), valor = c(50, 50, 52, 52, 50, 50, 55, 55))
  y <- yoy_pessoal_rreo_rgf(fl, g); y <- y[y$exercicio == 2025, ]
  expect_equal(y$suspeita_reclassificacao[y$cod_ibge == 1], TRUE); expect_equal(y$suspeita_reclassificacao[y$cod_ibge == 2], FALSE)
  expect_equal(round(y$rgf_yoy[y$cod_ibge == 1], 3), 0.04)
})

test_that("suspeita de reclassificacao so alerta quando o salto (b) tambem dispara", {
  ab <- mk_alerta("b", "salto_vs_ano_anterior", c(1, 2), "desp:pessoal", 2025, 1, 10, 5, "x")
  yoy <- data.frame(cod_ibge = c(1, 2, 3), exercicio = 2025, periodo = 1, rreo_yoy = c(.8, .1, .9), rgf_yoy = c(.05, .05, .02), dif = c(.75, .05, .88),
                    suspeita_reclassificacao = c(TRUE, FALSE, TRUE))
  a <- alerta_reclassificacao_pessoal(ab, yoy)
  expect_equal(a$cod_ibge, 1L); expect_equal(a$subtipo, "pessoal_suspeita_reclassificacao")
})

test_that("pessoal harmonizado: a partir do inicio usa o ano anterior x variacao do RGF; antes nao mexe", {
  p <- data.frame(cod_ibge = 1, exercicio = c(2024, 2025, 2026), periodo = 1, valor = c(100, 300, 330))
  y <- data.frame(cod_ibge = 1, exercicio = c(2025, 2026), periodo = 1, rgf_yoy = c(.05, .10))
  h <- pessoal_harmonizado(p, y, data.frame(cod_ibge = 1, exercicio = 2025, periodo = 1))
  expect_equal(h$harmonizado, c(100, 105, 115.5)); expect_equal(h$excedente, c(0, 195, 330 - 115.5))
})

test_that("quebras inventariadas viram conhecida e as demais saem por materialidade", {
  al <- rbind(
    mk_alerta("b", "salto_vs_ano_anterior", 33L, "desp:pessoal", 2025L, 3L, valor = 5e9),     # reclassificação RJ: conhecida
    mk_alerta("b", "salto_vs_ano_anterior", 33L, "desp:pessoal", 2026L, 2L, valor = -5e9),    # reversão: nova
    mk_alerta("b", "salto_vs_ano_anterior", 35L, "desp:pessoal", 2023L, 2L, valor = 1e9),     # RPPS 2023: conhecida
    mk_alerta("b", "salto_vs_ano_anterior", 35L, "rec:ICMS", 2023L, 2L, valor = 1e9),         # ICMS 2023: nova
    mk_alerta("b", "salto_vs_ano_anterior", 31L, "rec:ICMS", 2026L, 4L, valor = 9e9),         # nova, mais material
    mk_alerta("b", "salto_vs_ano_anterior", 41L, "desp:pessoal", 2025L, 5L, valor = 9e9),     # PR antes do início (b6): nova
    mk_alerta("c", "fator_defasado", 31L, "ICMS", 2026L, 4L),                                 # nova, sem R$
    mk_alerta("c", "conceito_original", 14L, "A6", 2020L, 1L))                                # conhecida
  rt <- unique(data.frame(cod_ibge = al$cod_ibge, exercicio = al$exercicio, periodo = al$periodo, rec_total = 10e9))
  p <- priorizar_alertas(al, rt)
  a <- p$alertas
  expect_equal(sum(a$status == "conhecida"), 3L)
  expect_true(all(a$status[1:5] == "nova") && all(a$status[6:8] == "conhecida"))
  expect_equal(a$cod_ibge[1], 31L)                                  # maior |Δ|/receita primeiro
  expect_true(is.na(a$materialidade[5]))                            # sem R$ por último entre as novas
  expect_equal(sum(p$resumo$n), nrow(al))
  expect_equal(nrow(alertas_novos_por_rodada(a, 2022L)), 5L)
  expect_equal(nrow(marcar_conhecidas(alertas_vazio())), 0L)
})
