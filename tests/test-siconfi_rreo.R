library(testthat)
source_utf8("../R/download/snapshots.R")
source_utf8("../R/download/siconfi_rreo.R")

item <- function(coluna = "Até o Bimestre (c)", valor = 100) {
  list(exercicio = 2024, demonstrativo = "RREO", periodo = 6, periodicidade = "B", instituicao = "Estado X",
       cod_ibge = 35, uf = "SP", populacao = 1000, anexo = "RREO-Anexo 01", esfera = "E", rotulo = "Padrão",
       coluna = coluna, cod_conta = "ReceitasExcetoIntraOrcamentarias", conta = "RECEITAS (I)", valor = valor)
}
grava_gz <- function(items, arquivo) {
  dir.create(dirname(arquivo), showWarnings = FALSE, recursive = TRUE)
  con <- gzfile(arquivo, "wb")
  writeLines(jsonlite::toJSON(list(items = items, hasMore = FALSE), auto_unbox = TRUE, null = "null"), con)
  close(con)
}

test_that("url_rreo codifica o anexo", {
  expect_match(url_rreo(35, 2024, 6, "RREO-Anexo 01"),
               "an_exercicio=2024&nr_periodo=6&co_tipo_demonstrativo=RREO&no_anexo=RREO-Anexo%2001&id_ente=35", fixed = TRUE)
})

test_that("caminho_rreo organiza por esfera e ano", {
  expect_equal(caminho_rreo("raw", "E", 35, 2024, 6, "RREO-Anexo 06"), file.path("raw", "E", 2024, "35_b6_a06.json.gz"))
})

test_that("ler_rreo devolve formato longo sem alterar valores", {
  f <- tempfile(fileext = ".json.gz")
  grava_gz(list(item("A", 10), item("B", -5)), f)
  d <- ler_rreo(f)
  expect_equal(nrow(d), 2)
  expect_equal(d$valor, c(10, -5))
  expect_equal(d$coluna, c("A", "B"))
})

test_that("ler_rreo falha se faltar campo e devolve vazio sem itens", {
  f <- tempfile(fileext = ".json.gz")
  grava_gz(list(list(exercicio = 2024)), f)
  expect_error(ler_rreo(f), "ausentes")
  g <- tempfile(fileext = ".json.gz"); grava_gz(list(), g)
  expect_equal(nrow(ler_rreo(g)), 0)
})

test_that("baixar_rreo reaproveita arquivo existente sem chamar a API", {
  pasta <- tempfile()
  alvo <- caminho_rreo(pasta, "E", 35, 2024, 6, "RREO-Anexo 01")
  grava_gz(list(item()), alvo)
  expect_equal(baixar_rreo(35, 2024, 6, "RREO-Anexo 01", pasta = pasta), alvo)
  expect_false(file.exists(file.path(pasta, "_log.csv")))
})

test_that("listar_estados devolve 27 UFs a partir de 26 E + DF", {
  entes <- data.frame(cod_ibge = c(1, 11, 53, 3550308), ente = c("União", "RO", "DF", "SP"),
                      esfera = c("U", "E", "D", "M"))
  e <- listar_estados(entes)
  expect_equal(e$cod_ibge, c(11, 53))
})

test_that("cobertura_rreo separa com dados, vazios e sem arquivo", {
  pasta <- tempfile()
  grava_gz(list(item()), caminho_rreo(pasta, "E", 11, 2024, 6, "RREO-Anexo 01"))
  grava_gz(list(), caminho_rreo(pasta, "E", 12, 2024, 6, "RREO-Anexo 01"))
  source("../R/quality/cobertura_rreo.R", local = TRUE)
  c1 <- cobertura_rreo(c(11, 12, 13), 2024, 6, c(a = "RREO-Anexo 01"), pasta = pasta)
  expect_equal(c(c1$com_dados, c1$vazios, c1$sem_arquivo), c(1, 1, 1))
})

test_that("ler_rreo_pasta empilha arquivos e ignora vazios", {
  pasta <- tempfile()
  grava_gz(list(item("A", 1)), caminho_rreo(pasta, "E", 11, 2024, 6, "RREO-Anexo 01"))
  grava_gz(list(item("B", 2), item("C", 3)), caminho_rreo(pasta, "E", 12, 2024, 6, "RREO-Anexo 01"))
  grava_gz(list(), caminho_rreo(pasta, "E", 13, 2024, 6, "RREO-Anexo 01"))
  source("../R/transform/rreo.R", local = TRUE)
  expect_equal(nrow(ler_rreo_pasta(pasta, "E")), 3)
  expect_equal(nrow(ler_rreo_pasta(tempfile(), "E")), 0)
})

test_that("bimestre_disponivel considera publicação até 30 dias após o fim do bimestre", {
  hoje <- as.Date("2026-10-23")
  expect_true(bimestre_disponivel(2025, 6, hoje))
  expect_true(bimestre_disponivel(2026, 4, hoje))
  expect_false(bimestre_disponivel(2026, 5, hoje))
  expect_false(bimestre_disponivel(2027, 1, hoje))
  expect_true(bimestre_disponivel(2026, 1, as.Date("2026-03-01")))
  expect_false(bimestre_disponivel(2026, 1, as.Date("2026-02-15")))
})

test_that("validar_rreo_pasta acha arquivo truncado e sobra .tmp, e remove quando pedido", {
  pasta <- tempfile()
  bom <- caminho_rreo(pasta, "M", 1, 2025, 6, "RREO-Anexo 01"); grava_gz(list(item()), bom)
  ruim <- caminho_rreo(pasta, "M", 2, 2025, 6, "RREO-Anexo 01"); grava_gz(list(item()), ruim)
  bytes <- readBin(ruim, "raw", file.size(ruim)); writeBin(bytes[seq_len(length(bytes) %/% 2)], ruim)  # trunca
  file.create(paste0(bom, ".tmp"))
  expect_equal(validar_rreo_pasta(pasta), ruim)
  validar_rreo_pasta(pasta, remover = TRUE)
  expect_false(file.exists(ruim)); expect_true(file.exists(bom)); expect_false(file.exists(paste0(bom, ".tmp")))
})
