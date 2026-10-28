library(testthat)
source("../R/models/fatia_minima.R")
source("../R/evaluation/vazamento.R")
source("../R/transform/stn.R")

escrever <- function(dir, nome, linhas, municipio = FALSE) {
  cab <- if (municipio) "Município;UF;ANO;Mês;1º Decêndio;2º Decêndio;3º Decêndio;Item transferência;Transferência;"
         else "UF;ANO;Mês;1º Decêndio;2º Decêndio;3º Decêndio;Item transferência;Transferência;"
  f <- file.path(dir, nome); con <- file(f, open = "wb"); writeLines(iconv(c(cab, linhas), "UTF-8", "latin1"), con, useBytes = TRUE); close(con); f
}

test_that("leitor: soma decêndios, só FPE/FPM, mês sem zero à esquerda vira inteiro", {
  d <- tempfile(); dir.create(d)
  f <- escrever(d, "a.csv", c("AC;2020;1;10;20;30;FPE;FPE;", "AC;2020;01;1;1;1;IPI-EXP;IPI-Exp;", "AC;2020;8;5;5;5;FPE;FPE;", "AC;2020;02;1;1;1;FPM;FUNDEB;"))
  x <- ler_stn_arquivo(f, "estados")
  expect_equal(nrow(x), 2); expect_equal(x$mes, c(1L, 8L)); expect_equal(x$valor, c(60, 15))
  fm <- escrever(d, "m.csv", c("Acrelândia;AC;2020;3;1;2;3;FPM;FPM;", "Acrelândia;AC;2020;3;9;9;9;FPM;FUNDEB;"), municipio = TRUE)
  m <- ler_stn_arquivo(fm, "municipios"); expect_equal(nrow(m), 1); expect_equal(m$valor, 6)
})

test_that("FPM 1% (a partir de jul/2025) entra no FPM e não é tratado como repetição; layout sem nome de transferência fica de fora", {
  d <- tempfile(); dir.create(d)
  fm <- escrever(d, "m.csv", c("Acrel\u00e2ndia;AC;2025;9;1;2;3;FPM;FPM;", "Acrel\u00e2ndia;AC;2025;9;10;20;30;FPM 1%;FPM 1%;"), municipio = TRUE)
  m <- ler_stn_arquivo(fm, "municipios"); expect_equal(nrow(m), 2); expect_equal(sum(m$valor), 66)
  expect_equal(nrow(deduplicar_stn(m)), 2)                               # mesmo ente x ano x mês, itens diferentes
  expect_equal(sum(serie_stn_mensal(data.frame(ente = "AC", item = "FPE", ano = 2025L, mes = 9L, valor = 1e9, arquivo = "a"), m)$valor_fpm * 1e9), 66)
  f18 <- escrever(d, "a18.csv", c("AC;2018;05;1;1;1;FPE;", "AC;2018;05;2;2;2;FPE;"))   # sem o nome da transferência (7 colunas preenchidas)
  expect_equal(nrow(ler_stn_arquivo(f18, "estados")), 0)
})

test_that("deduplicar: idênticas somem; valores diferentes são erro", {
  x <- data.frame(ente = c("AC", "AC", "AL"), item = "FPE", ano = 2020L, mes = 1L, valor = c(10, 10, 5), arquivo = c("a", "b", "a"))
  y <- deduplicar_stn(x); expect_equal(nrow(y), 2); expect_equal(attr(y, "repetidas_removidas"), 1)
  x$valor[2] <- 11; expect_error(deduplicar_stn(x), "valores diferentes")
})

serie_teste <- function() {
  g <- expand.grid(mes = 1:12, ano = 2021:2025); g <- g[order(g$ano, g$mes), ]
  data.frame(ano = g$ano, mes = g$mes, valor_fpe = 8 + 0.1 * (g$mes %% 3), valor_fpm = 8.4 + 0.1 * (g$mes %% 3), tratamento = "original")
}

test_that("escala: ×100 corrigido só se os dois fluxos e os vizinhos fecham; senão NA", {
  s <- serie_teste(); k <- s$ano == 2023 & s$mes == 9
  s$valor_fpe[k] <- s$valor_fpe[k] * 100; s$valor_fpm[k] <- s$valor_fpm[k] * 100
  r <- corrigir_escala_stn(s)
  expect_equal(r$tratamento[k], "escala_100"); expect_equal(r$valor_fpe[k], serie_teste()$valor_fpe[k])
  expect_true(all(r$tratamento[!k] == "original"))
  # só o FPE inflado: razão FPM/FPE fica fora do envelope -> descartado
  s2 <- serie_teste(); s2$valor_fpe[k] <- s2$valor_fpe[k] * 100
  r2 <- corrigir_escala_stn(s2); expect_equal(r2$tratamento[k], "descartado_escala"); expect_true(is.na(r2$valor_fpe[k]))
  # valor enorme que, dividido por 100, não fecha com os vizinhos (×100 não explica) -> NA
  s3 <- serie_teste(); s3$valor_fpe[k] <- 8 * 1000; s3$valor_fpm[k] <- 8.4 * 1000
  r3 <- corrigir_escala_stn(s3); expect_equal(r3$tratamento[k], "descartado_escala")
  # série limpa: nada muda
  expect_equal(corrigir_escala_stn(serie_teste()), serie_teste())
})

test_that("mês ausente fica NA (sem imputação) e a grade mensal é completa", {
  fpe <- data.frame(ente = "AC", item = "FPE", ano = 2020L, mes = c(1L, 3L), valor = 1e9, arquivo = "a")
  fpm <- data.frame(ente = "AC/x", item = "FPM", ano = 2020L, mes = c(1L, 2L, 3L), valor = 1e9, arquivo = "a")
  s <- serie_stn_mensal(fpe, fpm)
  expect_equal(nrow(s), 3); expect_equal(s$tratamento, c("original", "ausente", "original")); expect_true(is.na(s$valor_fpe[2]))
})

test_that("available_at da STN: último dia útil de m+1; defasagem extra desloca um mês", {
  expect_equal(available_at_stn(2026, 8), as.Date("2026-09-30"))
  expect_equal(available_at_stn(2026, 8, 1), as.Date("2026-10-30"))
  expect_equal(available_at_stn(2026, 12), as.Date("2027-01-29"))
})
