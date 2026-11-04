library(testthat)
source_utf8("../R/download/snapshots.R")
source_utf8("../R/download/siconfi_rreo.R")
source_utf8("../R/download/extrato.R")
source_utf8("../R/download/atualizacao_rreo.R")
source_utf8("../R/download/carga_historica.R")

test_that("faixas seguem a ordem aprovada", {
  f <- faixas_carga()
  expect_equal(vapply(f, `[[`, "", "esfera"), c("E", "M", "M"))
  expect_equal(f[[2]]$periodos, 6)
  expect_equal(f[[2]]$anos, 2025:2015)                 # mais recente primeiro
  expect_equal(f[[3]]$anos, 2026:2023)
  expect_equal(f[[3]]$periodos, 1:5)
  expect_false(any(f[[3]]$anos < 2023))                # 2015-2022 b1-5 fica fora (pendência condicionada)
})

test_that("ids_da_esfera: municípios sem o DF; estados com 26 E + DF", {
  entes <- data.frame(cod_ibge = c(1, 11, 53, 5300108, 3550308, 1100015), ente = "x", esfera = c("U", "E", "D", "M", "M", "M"))
  expect_equal(ids_da_esfera(entes, "M"), c(1100015, 3550308))
  expect_equal(ids_da_esfera(entes, "E"), c(11, 53))
})

test_that("trava impede segunda execução da mesma fatia", {
  f <- tempfile(); writeLines("x", f)
  expect_true(trava_ocupada(f))
  Sys.setFileTime(f, Sys.time() - 600)
  expect_false(trava_ocupada(f))
  expect_false(trava_ocupada(tempfile()))
})

test_that("executar_carga exige exatamente 2 processos", {
  expect_error(executar_carga(1, de = 3), "2 processos")
})

test_that("progresso_carga estima as chamadas restantes sem extratos locais", {
  pasta <- tempfile(); dir.create(pasta)
  writeLines(jsonlite::toJSON(list(items = data.frame(cod_ibge = c(11, 12, 53), ente = "x", esfera = c("E", "E", "D")), hasMore = FALSE)),
             file.path(pasta, "_entes_20261024.json"))
  f <- list(list(nome = "t", esfera = "E", anos = 2025, periodos = 6))
  p <- progresso_carga(pasta, f, hoje = as.Date("2026-10-24"))
  expect_equal(p$com_extrato, 0)
  expect_equal(p$chamadas_restantes, 3 * (1 + 2 * 1))
  expect_true(is.na(attr(p, "resumo")$horas_restantes))
})

# ---- idade máxima do extrato por exercício ----------------------------------------------------------------------------------------------------
mk_extrato <- function(pasta, id, ano, quando) {   # snapshot de extrato vazio com data de download `quando`
  d <- file.path(pasta, "extrato", ano); dir.create(d, recursive = TRUE, showWarnings = FALSE)
  f <- file.path(d, sprintf("%s_s%sZ.json.gz", id, format(quando, "%Y%m%dT%H%M%S", tz = "UTC")))
  con <- gzfile(f, "w"); writeLines('{"items":[],"hasMore":false}', con); close(con); f
}

test_that("idade_max_extrato: 7 dias para t e t-1, 90 para os anteriores, configuravel", {
  h <- as.Date("2026-11-04")
  expect_equal(idade_max_extrato(c(2026, 2025, 2024, 2015), h), c(7, 7, 90, 90))
  expect_equal(idade_max_extrato(c(2026, 2024), h, recente = 3, antigo = 30), c(3, 30))
  expect_equal(idade_max_extrato(2025, as.Date("2027-01-02")), 90)   # na virada, t-1 passa a ser 2026
  expect_equal(c(EXTRATO_IDADE_RECENTE, EXTRATO_IDADE_ANTIGO), c(7, 90))
})

test_that("atualizar_rreo reconsulta o extrato conforme a idade e o exercicio", {
  pasta <- tempfile(); dir.create(pasta); agora <- Sys.time(); h <- as.Date(agora)
  for (ano in c(2026, 2025, 2024)) { mk_extrato(pasta, 11, ano, agora - 10 * 86400)         # 10 dias
                                     mk_extrato(pasta, 12, ano, agora - 100 * 86400) }      # 100 dias
  chamadas <- character(0)
  orig <- baixar_extrato; on.exit(assign("baixar_extrato", orig, envir = globalenv()), add = TRUE)
  assign("baixar_extrato", function(id_ente, ano, pasta, ...) { chamadas <<- c(chamadas, paste(id_ente, ano)); extrato_vigente(pasta, id_ente, ano)$arquivo }, envir = globalenv())
  atualizar_rreo(c(11, 12), 2024:2026, 6, "E", pasta, hoje = h, idade_max_extrato_dias = function(a) idade_max_extrato(a, h))
  # 10 dias: vencido em 2026 e 2025 (limite 7), valido em 2024 (limite 90); 100 dias: vencido nos tres
  expect_setequal(chamadas, c("11 2026", "11 2025", "12 2026", "12 2025", "12 2024"))
  chamadas <- character(0)
  atualizar_rreo(c(11, 12), 2024, 6, "E", pasta, hoje = h)                                 # escalar (comportamento anterior): limite 7 para todos
  expect_setequal(chamadas, c("11 2024", "12 2024"))
})

test_that("progresso_carga conta os extratos que a proxima execucao vai refazer", {
  pasta <- tempfile(); dir.create(pasta); agora <- Sys.time(); h <- as.Date(agora)
  writeLines(jsonlite::toJSON(list(items = data.frame(cod_ibge = c(11, 12, 13), ente = "x", esfera = "E"), hasMore = FALSE)), file.path(pasta, paste0("_entes_", format(h, "%Y%m%d"), ".json")))
  mk_extrato(pasta, 11, 2025, agora - 10 * 86400); mk_extrato(pasta, 12, 2025, agora - 2 * 86400)    # 2025: 10 dias vence (7), 2 dias nao; 13 sem extrato
  mk_extrato(pasta, 11, 2020, agora - 10 * 86400); mk_extrato(pasta, 12, 2020, agora - 100 * 86400)  # 2020: 10 dias nao vence (90), 100 dias vence
  f <- list(list(nome = "t", esfera = "E", anos = c(2025, 2020), periodos = 6))
  p <- progresso_carga(pasta, f, hoje = h)
  expect_equal(p$extratos_vencidos, c(1, 1))
  e <- attr(p, "extratos")
  expect_equal(c(e$vencidos, e$sem_extrato, e$total), c(2, 2, 4))
  p2 <- progresso_carga(pasta, f, hoje = h, idade_recente = 1, idade_antigo = 1)
  expect_equal(attr(p2, "extratos")$vencidos, 4)
})
