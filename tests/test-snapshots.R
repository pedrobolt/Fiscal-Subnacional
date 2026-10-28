library(testthat)
source_utf8("../R/download/snapshots.R")
source_utf8("../R/download/siconfi_rreo.R")
source_utf8("../R/download/extrato.R")
source_utf8("../R/download/atualizacao_rreo.R")
source_utf8("../R/quality/cobertura_rreo.R")
source_utf8("../R/transform/rreo.R")

item <- function(valor = 1, coluna = "Até o Bimestre (c)") {
  list(exercicio = 2025, demonstrativo = "RREO", periodo = 6, periodicidade = "B", instituicao = "x",
       cod_ibge = 1, uf = "A", populacao = 1, esfera = "M", anexo = "RREO-Anexo 01", rotulo = "r",
       coluna = coluna, cod_conta = "c", conta = "c", valor = valor)
}
grava <- function(items, arq, mtime = NULL) {
  dir.create(dirname(arq), showWarnings = FALSE, recursive = TRUE)
  grava_gz_utf8(jsonlite::toJSON(list(items = items, hasMore = FALSE), auto_unbox = TRUE), arq)
  if (!is.null(mtime)) Sys.setFileTime(arq, mtime)
  arq
}
utc <- function(x) as.POSIXct(x, tz = "UTC")

test_that("snapshot tem nome com carimbo UTC e a vigente é a mais recente", {
  pasta <- tempfile()
  base <- caminho_rreo(pasta, "M", 1, 2025, 6, "RREO-Anexo 01")
  grava(list(item(1)), base, utc("2026-10-23 12:00:00"))
  expect_equal(caminho_norm(arquivo_vigente(base)), caminho_norm(base))
  snap <- caminho_snapshot(base, utc("2026-11-05 09:30:00"))
  expect_match(basename(snap), "^1_b6_a01_s20261105T093000Z\\.json\\.gz$")
  grava(list(item(2)), snap)
  expect_equal(caminho_norm(arquivo_vigente(base)), caminho_norm(snap))
  expect_equal(nrow(versoes_rreo(base)), 2)
  expect_equal(baixado_em_vigente(base), utc("2026-11-05 09:30:00"))
})

test_that("versões de tipos diferentes não se misturam", {
  pasta <- tempfile()
  b1 <- caminho_rreo(pasta, "M", 1, 2025, 6, "RREO-Anexo 01", "RREO")
  b2 <- caminho_rreo(pasta, "M", 1, 2025, 6, "RREO-Anexo 01", "RREO Simplificado")
  grava(list(item()), b1); grava(list(item()), b2)
  expect_equal(nrow(versoes_rreo(b1)), 1); expect_equal(nrow(versoes_rreo(b2)), 1)
})

test_that("ler_extrato filtra o RREO e distingue o Simplificado", {
  f <- tempfile(fileext = ".json.gz")
  x <- list(
    list(cod_ibge = 1, exercicio = 2025, entregavel = "Relatório Resumido de Execução Orçamentária", periodo = 1, status_relatorio = "HO", data_status = "2025-03-30T22:31:54Z"),
    list(cod_ibge = 1, exercicio = 2025, entregavel = "Relatório Resumido de Execução Orçamentária Simplificado", periodo = 2, status_relatorio = "RE", data_status = "2025-06-01T10:00:00Z"),
    list(cod_ibge = 1, exercicio = 2025, entregavel = "Relatório de Gestão Fiscal Simplificado", periodo = 1, status_relatorio = "HO", data_status = "2025-03-30T22:31:54Z"),
    list(cod_ibge = 1, exercicio = 2025, entregavel = "MSC Agregada", periodo = 1, status_relatorio = NA, data_status = "2025-02-27T09:36:06Z"))
  grava(x, f)
  e <- ler_extrato(f)
  expect_equal(nrow(e), 2)
  expect_equal(e$tipo, c("RREO", "RREO Simplificado"))
  expect_equal(e$status, c("HO", "RE"))
  expect_equal(e$data_status[1], utc("2025-03-30 22:31:54"))
})

test_that("extrato_vigente pega o snapshot mais recente", {
  pasta <- tempfile()
  grava(list(), file.path(pasta, "extrato", 2025, "7_s20261001T000000Z.json.gz"))
  grava(list(), file.path(pasta, "extrato", 2025, "7_s20261020T120000Z.json.gz"))
  grava(list(), file.path(pasta, "extrato", 2025, "70_s20261025T000000Z.json.gz"))   # outro ente
  v <- extrato_vigente(pasta, 7, 2025)
  expect_equal(basename(v$arquivo), "7_s20261020T120000Z.json.gz")
  expect_equal(nrow(extrato_vigente(pasta, 8, 2025)), 0)
})

entrega <- function(periodo, tipo = "RREO", data_status) {
  data.frame(cod_ibge = 1, exercicio = 2025, periodo = periodo, tipo = tipo, status = "HO", data_status = utc(data_status))
}

test_that("planejar_jobs: novo, retificado, vazio com entrega e nada a fazer", {
  pasta <- tempfile()
  a1 <- "RREO-Anexo 01"
  # b1: arquivo local baixado depois da entrega -> nada a fazer
  grava(list(item()), caminho_rreo(pasta, "M", 1, 2025, 1, a1), utc("2026-10-23 12:00:00"))
  # b2: arquivo local baixado antes da retificação -> retificado
  grava(list(item()), caminho_rreo(pasta, "M", 1, 2025, 2, a1), utc("2026-10-23 12:00:00"))
  # b3: arquivo local vazio e entrega posterior -> vazio_com_entrega
  grava(list(), caminho_rreo(pasta, "M", 1, 2025, 3, a1), utc("2026-10-23 12:00:00"))
  # b4: arquivo local vazio e entrega anterior à consulta -> nada (o anexo não existe)
  grava(list(), caminho_rreo(pasta, "M", 1, 2025, 4, a1), utc("2026-10-23 12:00:00"))
  # b5: sem arquivo -> novo
  ent <- rbind(entrega(1, data_status = "2025-03-30 10:00:00"), entrega(2, data_status = "2026-11-01 10:00:00"),
               entrega(3, data_status = "2026-11-01 10:00:00"), entrega(4, data_status = "2025-09-30 10:00:00"),
               entrega(5, data_status = "2025-11-30 10:00:00"))
  j <- planejar_jobs(ent, pasta, "M", anexos = c(a = a1))
  expect_equal(j$periodo, c(2, 3, 5))
  expect_equal(j$motivo, c("retificado", "vazio_com_entrega", "novo"))
})

test_that("planejar_jobs respeita o tipo do extrato e a lista de períodos", {
  pasta <- tempfile()
  ent <- rbind(entrega(5, "RREO Simplificado", "2025-11-30 10:00:00"), entrega(6, "RREO Simplificado", "2026-01-30 10:00:00"))
  j <- planejar_jobs(ent, pasta, "M", anexos = c(a = "RREO-Anexo 01"), periodos = 6)
  expect_equal(nrow(j), 1); expect_equal(j$tipo, "RREO Simplificado")
})

test_that("cobertura_rreo reconhece Simplificado e separa não tentado de sem arquivo", {
  pasta <- tempfile(); a1 <- "RREO-Anexo 01"; a6 <- "RREO-Anexo 06"
  # ente 11: RREO com A1 e A6
  grava(list(item()), caminho_rreo(pasta, "M", 11, 2025, 6, a1)); grava(list(item()), caminho_rreo(pasta, "M", 11, 2025, 6, a6))
  # ente 12: Simplificado com A1 e A6
  grava(list(item()), caminho_rreo(pasta, "M", 12, 2025, 6, a1, "RREO Simplificado"))
  grava(list(item()), caminho_rreo(pasta, "M", 12, 2025, 6, a6, "RREO Simplificado"))
  # ente 13: A1 vazio (RREO), sem A6 -> A1 vazio; A6 não tentado
  grava(list(), caminho_rreo(pasta, "M", 13, 2025, 6, a1))
  # ente 14: A1 com dados, sem A6 -> A6 sem arquivo (deveria existir)
  grava(list(item()), caminho_rreo(pasta, "M", 14, 2025, 6, a1))
  # ente 15: nada -> A1 sem arquivo, A6 não tentado
  c <- cobertura_rreo(11:15, 2025, 6, c(a1 = a1, a6 = a6), esfera = "M", pasta = pasta, hoje = as.Date("2026-10-23"))
  r1 <- c[c$anexo == a1, ]; r6 <- c[c$anexo == a6, ]
  expect_equal(c(r1$com_dados, r1$vazios, r1$nao_tentado, r1$sem_arquivo), c(3, 1, 0, 1))
  expect_equal(c(r6$com_dados, r6$vazios, r6$nao_tentado, r6$sem_arquivo), c(2, 0, 2, 1))
})

test_that("ler_rreo_pasta usa a versão vigente e acrescenta tipo, arquivo e baixado_em", {
  pasta <- tempfile(); a1 <- "RREO-Anexo 01"
  base <- caminho_rreo(pasta, "M", 1, 2025, 6, a1)
  grava(list(item(10)), base, utc("2026-10-23 12:00:00"))
  grava(list(item(99)), caminho_snapshot(base, utc("2026-11-05 09:30:00")))
  grava(list(item(5)), caminho_rreo(pasta, "M", 2, 2025, 6, a1, "RREO Simplificado"))
  d <- ler_rreo_pasta(pasta, "M")
  expect_equal(nrow(d), 2)
  expect_equal(d$valor[d$tipo_demonstrativo == "RREO"], 99)
  expect_equal(d$valor[d$tipo_demonstrativo == "RREO Simplificado"], 5)
  expect_match(d$arquivo[d$tipo_demonstrativo == "RREO"], "^M/2025/1_b6_a01_s20261105T093000Z\\.json\\.gz$")
  expect_equal(d$baixado_em[d$tipo_demonstrativo == "RREO"], utc("2026-11-05 09:30:00"))
})

escreve_log <- function(pasta, momentos, base_args = list(esfera = "M", id = 1, ano = 2025, periodo = 6, anexo = "RREO-Anexo 01", tipo = "RREO"), nome = "_log.csv") {
  d <- data.frame(momento = momentos, esfera = base_args$esfera, id_ente = base_args$id, ano = base_args$ano,
                  periodo = base_args$periodo, anexo = base_args$anexo, tipo = base_args$tipo, tentativa = 1,
                  ok = TRUE, linhas = 10, segundos = 1, msg = "")
  dir.create(pasta, showWarnings = FALSE, recursive = TRUE)
  utils::write.csv(fileEncoding = "UTF-8", d, file.path(pasta, nome), row.names = FALSE)
}

test_that("data da original vem do log, não do mtime (cópia/restauração muda o mtime)", {
  pasta <- tempfile()
  base <- caminho_rreo(pasta, "M", 1, 2025, 6, "RREO-Anexo 01")
  grava(list(item()), base, utc("2027-03-01 00:00:00"))              # mtime "de hoje", após cópia
  escreve_log(pasta, c("2026-10-23T12:00:00Z", "2026-10-25T08:00:00Z"))  # primeiro ok = original
  v <- versoes_rreo(base)
  expect_equal(v$baixado_em, utc("2026-10-23 12:00:00"))
  expect_equal(v$fonte, "log")
})

test_that("log antigo (hora local sem fuso) é lido como America/Sao_Paulo e convertido a UTC", {
  pasta <- tempfile()
  base <- caminho_rreo(pasta, "M", 1, 2025, 6, "RREO-Anexo 01")
  grava(list(item()), base)
  escreve_log(pasta, "2026-10-23 09:00:00")
  expect_equal(baixado_em_vigente(base), utc("2026-10-23 12:00:00"))
})

test_that("sem registro no log, usa o mtime e marca a fonte", {
  pasta <- tempfile()
  base <- caminho_rreo(pasta, "M", 1, 2025, 6, "RREO-Anexo 01")
  grava(list(item()), base, utc("2026-10-20 10:00:00"))
  v <- versoes_rreo(base)
  expect_equal(v$baixado_em, utc("2026-10-20 10:00:00")); expect_equal(v$fonte, "mtime")
})

test_that("planejar_jobs não marca retificado por causa de mtime novo quando o log tem a data da original", {
  pasta <- tempfile()
  base <- caminho_rreo(pasta, "M", 1, 2025, 6, "RREO-Anexo 01")
  grava(list(item()), base, utc("2027-03-01 00:00:00"))
  escreve_log(pasta, "2026-10-23T12:00:00Z")
  ent <- data.frame(cod_ibge = 1, exercicio = 2025, periodo = 6, tipo = "RREO",
                    data_status = utc("2026-10-10 00:00:00"), stringsAsFactors = FALSE)
  j <- planejar_jobs(ent, pasta, "M", anexos = "RREO-Anexo 01", periodos = 6)
  expect_equal(nrow(j), 0)
  ent$data_status <- utc("2026-10-24 00:00:00")
  expect_equal(planejar_jobs(ent, pasta, "M", anexos = "RREO-Anexo 01", periodos = 6)$motivo, "retificado")
})
