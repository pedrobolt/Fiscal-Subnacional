library(testthat)
source_utf8("../R/download/snapshots.R")
source_utf8("../R/download/siconfi_rreo.R")
source_utf8("../R/evaluation/cobertura_municipal.R")

base <- data.frame(cod_ibge = 1:6, uf = c("A", "A", "A", "B", "B", "B"),
                   populacao = c(100, 50, 50, 80, 10, 10),
                   receita = c(70, 20, 10, 50, 40, NA),
                   primario = c(5, -2, 1, 3, 1, NA))

test_that("curva_cobertura: menor N por UF e share do primário", {
  c <- curva_cobertura(base)
  a <- c[c$uf == "A", ]
  expect_equal(a$n, c(1, 2, 2))                          # 70%, 80% e 90% da receita (70/20/10)
  expect_equal(a$share_primario_liquido[1], 5 / 4)       # 1º município: 5 de um líquido de 4
  expect_equal(a$share_primario_abs[1], 5 / 8)
  b <- c[c$uf == "B", ]
  expect_equal(b$n, c(2, 2, 2))                          # 50/90 = 56%: precisa dos dois; o município NA fica de fora
  expect_equal(b$n_municipios, c(2, 2, 2))
})

test_that("curva_cobertura_brasil usa ranking nacional", {
  c <- curva_cobertura_brasil(base)
  # receitas: 70, 50, 40, 20, 10 (total 190): acumulados 0.368, 0.63, 0.84, 0.947, 1
  expect_equal(c$n, c(3, 3, 4))
})

test_that("sobreposicao_topn mede estabilidade do ranking entre anos", {
  b2 <- base; b2$receita <- c(20, 70, 10, 50, 40, NA)     # em A, os dois maiores trocam de ordem
  s <- sobreposicao_topn(base, b2, c(A = 1, B = 1))
  expect_equal(s$em_comum[s$uf == "A"], 0)
  expect_equal(s$em_comum[s$uf == "B"], 1)
})

test_that("sem_dados mede municípios e população sem informação", {
  s <- sem_dados(base)
  expect_equal(s$n, 1)
  expect_equal(s$pop_share, 10 / 300)
  expect_equal(s$por_uf$n_sem_dados, c(0, 1))
  expect_equal(s$municipios$cod_ibge, 6)
})

test_that("extrair_municipio cai para o Simplificado e devolve NA sem dados", {
  pasta <- tempfile()
  grava <- function(items, arq) {
    dir.create(dirname(arq), showWarnings = FALSE, recursive = TRUE)
    con <- gzfile(arq, "wb"); writeLines(jsonlite::toJSON(list(items = items, hasMore = FALSE), auto_unbox = TRUE), con); close(con)
  }
  it <- function(cod_conta, coluna, valor) list(exercicio = 2025, periodo = 6, periodicidade = "B", cod_ibge = 1,
    instituicao = "x", uf = "A", populacao = 1, esfera = "M", anexo = "a", rotulo = "r", coluna = coluna,
    cod_conta = cod_conta, conta = "c", valor = valor)
  grava(list(), caminho_rreo(pasta, "M", 1, 2025, 6, "RREO-Anexo 01", "RREO"))
  grava(list(it("ReceitasExcetoIntraOrcamentarias", "Até o Bimestre (c)", 123)),
        caminho_rreo(pasta, "M", 1, 2025, 6, "RREO-Anexo 01", "RREO Simplificado"))
  r <- extrair_municipio(1, 2025, pasta = pasta)
  expect_equal(r$tipo, "RREO Simplificado")
  expect_equal(r$receita, 123)
  expect_true(is.na(r$primario))
  expect_true(is.na(extrair_municipio(2, 2025, pasta = pasta)$tipo))
})

test_that("participacao_simplificado separa o grupo estrutural e ignora sem dados", {
  b <- data.frame(cod_ibge = 1:4, uf = "A", populacao = c(100, 50, 50, 100),
                  tipo = c("RREO", "RREO Simplificado", "RREO Simplificado", NA),
                  receita = c(80, 15, 5, NA), primario = c(8, -1, 3, NA))
  p <- participacao_simplificado(b)
  a <- p[p$uf == "A", ]
  expect_equal(a$n_simplificado, 2)
  expect_equal(a$receita_share, 20 / 100)
  expect_equal(a$primario_liquido_share, 2 / 10)
  expect_equal(a$primario_abs_share, 4 / 12)
  expect_equal(a$pop_share, 100 / 300)
  expect_equal(p$uf, c("A", "BR"))
})
