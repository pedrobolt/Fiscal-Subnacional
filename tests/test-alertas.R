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
