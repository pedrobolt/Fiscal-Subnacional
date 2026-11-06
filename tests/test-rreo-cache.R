library(testthat)
source_utf8("../R/utils_io.R")
source_utf8("../R/download/snapshots.R"); source_utf8("../R/download/siconfi_rreo.R"); source_utf8("../R/download/extrato.R"); source_utf8("../R/transform/rreo.R")

item <- function(valor = 1, cod = 1, periodo = 6, coluna = "Até o Bimestre (c)") {
  list(exercicio = 2025, demonstrativo = "RREO", periodo = periodo, periodicidade = "B", instituicao = "x", cod_ibge = cod, uf = "A", populacao = 1, esfera = "E", anexo = "RREO-Anexo 01", rotulo = "r", coluna = coluna, cod_conta = "c", conta = "c", valor = valor)
}
grava <- function(items, arq, mtime = NULL) {
  dir.create(dirname(arq), showWarnings = FALSE, recursive = TRUE); grava_gz_utf8(jsonlite::toJSON(list(items = items, hasMore = FALSE), auto_unbox = TRUE), arq)
  if (!is.null(mtime)) Sys.setFileTime(arq, mtime); arq
}
utc <- function(x) as.POSIXct(x, tz = "UTC")
monta <- function() {                 # pasta com 3 entes, um deles com snapshot mais novo e um arquivo vazio
  pasta <- tempfile("rreo"); a1 <- "RREO-Anexo 01"; b1 <- caminho_rreo(pasta, "E", 1, 2025, 6, a1)
  grava(list(item(10, 1), item(11, 1)), b1, utc("2026-10-23 12:00:00")); grava(list(item(99, 1)), caminho_snapshot(b1, utc("2026-11-05 09:30:00")))
  grava(list(item(5, 2)), caminho_rreo(pasta, "E", 2, 2025, 6, a1), utc("2026-10-24 12:00:00")); grava(list(item(7, 3), item(8, 3, 5)), caminho_rreo(pasta, "E", 3, 2025, 6, a1, "RREO Simplificado"), utc("2026-10-25 12:00:00"))
  grava(list(), caminho_rreo(pasta, "E", 4, 2025, 6, a1), utc("2026-10-26 12:00:00"))
  pasta
}
caminho_cache <- function() tempfile(fileext = ".rds")
limpa <- function() rm(list = ls(.rreo_memo), envir = .rreo_memo)

test_that("com cache o resultado e identico ao da leitura completa (primeira vez e segunda)", {
  limpa(); pasta <- monta(); cache <- caminho_cache(); ref <- ler_rreo_pasta(pasta, "E")
  c1 <- ler_rreo_cache(pasta, "E", cache, aviso = FALSE); expect_identical(c1, ref); expect_true(file.exists(cache))
  limpa(); c2 <- ler_rreo_cache(pasta, "E", cache, aviso = FALSE); expect_identical(c2, ref)     # agora vem do RDS
  c3 <- ler_rreo_cache(pasta, "E", cache, aviso = FALSE); expect_identical(c3, ref)               # e do objeto em memoria
  expect_equal(nrow(ref), 4L); expect_equal(sort(ref$valor), c(5, 7, 8, 99))
})

test_that("o manifesto guarda caminho relativo, tamanho e mtime dos vigentes", {
  limpa(); pasta <- monta(); cache <- caminho_cache(); ler_rreo_cache(pasta, "E", cache, aviso = FALSE); m <- readRDS(cache)$manifesto
  expect_named(m, c("arquivo", "tamanho", "mtime")); expect_equal(nrow(m), 4L); expect_true(all(grepl("^E/2025/", m$arquivo))); expect_true(all(m$tamanho > 0))
})

test_that("cache invalidado quando um arquivo muda, aparece ou deixa de ser vigente", {
  limpa(); pasta <- monta(); cache <- caminho_cache(); a1 <- "RREO-Anexo 01"; ler_rreo_cache(pasta, "E", cache, aviso = FALSE)
  # 1. arquivo alterado (conteudo e tamanho)
  grava(list(item(55, 2), item(56, 2)), caminho_rreo(pasta, "E", 2, 2025, 6, a1), utc("2026-11-06 10:00:00")); limpa()
  expect_output(x <- ler_rreo_cache(pasta, "E", cache), "1 a decodificar"); expect_identical(x, ler_rreo_pasta(pasta, "E")); expect_true(all(c(55, 56) %in% x$valor)); expect_false(5 %in% x$valor)
  # 2. so o mtime muda (mesmo conteudo): decodifica de novo e continua identico
  Sys.setFileTime(caminho_rreo(pasta, "E", 2, 2025, 6, a1), utc("2026-11-07 10:00:00")); limpa()
  expect_output(y <- ler_rreo_cache(pasta, "E", cache), "1 a decodificar"); expect_identical(y, ler_rreo_pasta(pasta, "E"))
  # 3. arquivo novo (ente 5) e snapshot novo que substitui o vigente do ente 1
  grava(list(item(1000, 5)), caminho_rreo(pasta, "E", 5, 2025, 6, a1), utc("2026-11-08 10:00:00")); grava(list(item(77, 1)), caminho_snapshot(caminho_rreo(pasta, "E", 1, 2025, 6, a1), utc("2026-11-09 08:00:00"))); limpa()
  expect_output(z <- ler_rreo_cache(pasta, "E", cache), "2 a decodificar"); expect_identical(z, ler_rreo_pasta(pasta, "E")); expect_true(all(c(1000, 77) %in% z$valor)); expect_false(99 %in% z$valor)
  # 4. nada mudou: nenhum arquivo decodificado
  limpa(); expect_output(w <- ler_rreo_cache(pasta, "E", cache), "0 a decodificar"); expect_identical(w, z)
})

test_that("cache corrompido ou de outra versao e ignorado; FISCAL_SEM_CACHE e forcar contornam", {
  limpa(); pasta <- monta(); cache <- caminho_cache(); writeLines("lixo", cache)
  expect_identical(ler_rreo_cache(pasta, "E", cache, aviso = FALSE), ler_rreo_pasta(pasta, "E")); c0 <- readRDS(cache); c0$versao <- 0L; saveRDS(c0, cache); limpa()
  expect_output(ler_rreo_cache(pasta, "E", cache), "4 a decodificar")
  Sys.setenv(FISCAL_SEM_CACHE = "1"); on.exit(Sys.unsetenv("FISCAL_SEM_CACHE")); expect_identical(ler_rreo_cache(pasta, "E", tempfile(), aviso = FALSE), ler_rreo_pasta(pasta, "E")); expect_false(file.exists(paste0(cache, "x")))
  Sys.unsetenv("FISCAL_SEM_CACHE"); expect_identical(ler_rreo_cache(pasta, "E", tempfile(), forcar = TRUE, aviso = FALSE), ler_rreo_pasta(pasta, "E"))
})

test_that("pasta sem arquivos devolve data.frame vazio", {
  limpa(); expect_equal(nrow(ler_rreo_cache(tempfile(), "E", caminho_cache(), aviso = FALSE)), 0L)
})
