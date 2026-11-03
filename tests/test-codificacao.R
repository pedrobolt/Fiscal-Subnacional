library(testthat)

arquivos_codigo <- function() {
  c(list.files("../R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE), list.files("../scripts", pattern = "\\.R$", full.names = TRUE), "../_targets.R")
}
fora_cp1252 <- function(f) {
  l <- readLines(f, encoding = "UTF-8", warn = FALSE)
  which(is.na(iconv(enc2utf8(l), "UTF-8", "CP1252")) & !is.na(l))
}

test_that("nenhum .R em R/ ou scripts/ tem caractere fora do CP1252 (Windows trunca o arquivo no primeiro)", {
  for (f in arquivos_codigo()) {
    ruins <- fora_cp1252(f)
    expect_length(ruins, 0)
    if (length(ruins)) message("fora do CP1252: ", f, " linhas ", paste(head(ruins, 5), collapse = ","))
  }
})

test_that("pontos de entrada lidos pelo R nativo sao ASCII (rodada_mensal.R, _targets.R e R/utils_io.R: carregam o carregador)", {
  for (f in c("../scripts/rodada_mensal.R", "../_targets.R", "../R/utils_io.R")) {
    l <- readLines(f, encoding = "UTF-8", warn = FALSE)
    expect_true(all(!is.na(iconv(l, "UTF-8", "ASCII"))), info = f)
  }
})

test_that("carregar_r le UTF-8 mesmo com caractere fora da codificacao nativa", {
  tmp <- tempfile(fileext = ".R")
  writeBin(c(charToRaw("f_teste_utf8 <- function() 'a"), as.raw(c(0xcf, 0x83)), charToRaw("b'\ng_teste_utf8 <- 1\n")), tmp)   # bytes UTF-8 (sigma), sem depender do locale
  e <- new.env(); carregar_r(tmp, e)
  expect_equal(e$g_teste_utf8, 1); expect_equal(nchar(e$f_teste_utf8()), 3L)
})

# funcoes que cada script usa, conferidas depois de carregar a lista de arquivos DO PROPRIO script pelo carregador
ESPERADAS <- list(
  "rodada_mensal_corpo.R" = c("fluxos_a6_categorias", "aplicar_dicionario", "p1_srw_esferas", "intervalo_p1_regional", "arquivar_previsoes", "aba_alertas_rodada",
                              "bimestre_referencia", "p2_sem_rpps_ldo_bim", "backtest_p1", "atualizar_rreo", "atualizar_a3_dca", "baixar_rgf_estados", "ler_premissas",
                              "gap_bimestral", "classificar_gap", "caminhos_rodada", "baixar_sgs", "pib_ibge_anual"),
  "conceito_unico.R" = c("fluxos_a6_conceito", "conceito_deducoes_a6", "fatores_dca", "receita_bruta_liquida", "ler_rreo_pasta", "aplicar_conceito_unico"),
  "quebras_e28.R" = c("alerta_dicionario_rreo", "fluxos_a6_categorias", "alerta_entrega", "totais_rpps", "pessoal_rgf_mensal", "extrato_vigente", "ler_extrato", "marcar_conhecidas"),
  "alertas_priorizados.R" = c("priorizar_alertas", "aba_alertas", "fluxos_a6_categorias"),
  "receita_bruta_liquida.R" = c("estabilidade_fatores", "receita_mensal_a3", "fatores_dca", "ler_a3_estados"))

arquivos_do_script <- function(script) {
  txt <- paste(readLines(file.path("../scripts", script), encoding = "UTF-8", warn = FALSE), collapse = "\n")
  if (grepl("list.files(\"R\"", txt, fixed = TRUE) || grepl("arqs <- list.files", txt, fixed = TRUE)) {
    a <- list.files("../R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
    return(c(a[!grepl("candidatos_p1", a)], a[grepl("candidatos_p1", a)]))     # candidatos_p1 depende de ESPEC_RESTANTE
  }
  m <- regmatches(txt, gregexpr("R/[A-Za-z0-9_/]+\\.R", txt))[[1]]
  file.path("..", setdiff(unique(m), "R/utils_io.R"))
}

test_that("o carregador, aplicado a lista de arquivos de cada script, define as funcoes que o script usa", {
  for (s in names(ESPERADAS)) {
    e <- new.env(parent = globalenv())
    arq <- arquivos_do_script(s)
    expect_gt(length(arq), 0)
    carregar_r(arq, e)
    falta <- ESPERADAS[[s]][!vapply(ESPERADAS[[s]], exists, logical(1), envir = e, inherits = FALSE)]
    expect_length(falta, 0)
    if (length(falta)) message(s, " sem: ", paste(falta, collapse = ", "))
  }
})

test_that("o ponto de entrada da rodada carrega o corpo pelo carregador", {
  txt <- paste(readLines("../scripts/rodada_mensal.R", warn = FALSE), collapse = "\n")
  expect_match(txt, "carregar_r\\(\"scripts/rodada_mensal_corpo.R\"\\)"); expect_false(grepl("\\bsource\\(\"scripts", txt))
})

test_that("nenhum script usa source() com encoding no lugar do carregador (trunca no Windows)", {
  for (f in arquivos_codigo()) {
    l <- readLines(f, encoding = "UTF-8", warn = FALSE); l <- l[!grepl("^\\s*#", l)]
    ruim <- grepl("source\\(", l) & grepl("encoding", l) & !grepl("R/utils_io.R", l, fixed = TRUE)
    expect_false(any(ruim), info = f)
  }
})

# (d, geral) dependencias: para CADA script, carrega so os arquivos que ele proprio carrega e segue, a partir das funcoes que o script chama, as
# funcoes e constantes globais de cada uma (codetools); tudo precisa estar definido nesses arquivos ou nos pacotes anexados. Pega o caso de um
# script que esquece de carregar um arquivo (ex.: CATEGORIAS_A3 em dicionario_contas.R) sem rodar o script.
NSE_OK <- c("anexo", "cod_ibge", "motivo", "periodo", "tipo")        # colunas usadas dentro de with() em atualizar_rreo

nao_resolvidos <- function(arq, ids_script) {
  e <- new.env(parent = parent.env(globalenv()))                       # fora do globalenv: o que outros testes definiram nao vale
  carregar_r(c("../R/utils_io.R", arq), e)
  fila <- intersect(ids_script, ls(e)); visto <- character(0); falta <- character(0)
  while (length(fila)) {
    n <- fila[1]; fila <- fila[-1]
    if (n %in% visto) next
    visto <- c(visto, n); f <- get(n, e); if (!is.function(f)) next
    g <- codetools::findGlobals(f, merge = FALSE)
    for (v in setdiff(c(g$functions, g$variables), NSE_OK)) {
      if (exists(v, envir = e, inherits = FALSE)) fila <- c(fila, v) else if (!exists(v, envir = e, inherits = TRUE)) falta <- c(falta, paste0(v, " (usado em ", n, ")"))
    }
  }
  unique(falta)
}
ids_do_script <- function(script) {
  txt <- readLines(file.path("../scripts", script), encoding = "UTF-8", warn = FALSE); txt <- txt[!grepl("^\\s*#", txt)]
  unique(unlist(regmatches(txt, gregexpr("[A-Za-z_.][A-Za-z0-9_.]*", txt))))
}

test_that("o detector de dependencias acusa constante nao carregada (teste do proprio teste)", {
  tmp <- tempfile(fileext = ".R")
  writeLines(c("K_SO_NO_OUTRO <- 1", "f_usa <- function() K_SO_NO_OUTRO + 1"), tmp)
  tmp2 <- tempfile(fileext = ".R"); writeLines("g_sem_k <- function() K_SO_NO_OUTRO", tmp2)
  expect_length(nao_resolvidos(c(tmp, tmp2), "g_sem_k"), 0)
  expect_match(nao_resolvidos(tmp2, "g_sem_k"), "K_SO_NO_OUTRO")
})

test_that("cada script carrega todos os arquivos de que suas funcoes dependem", {
  for (s in setdiff(list.files("../scripts", pattern = "\\.R$"), "rodada_mensal.R")) {
    arq <- arquivos_do_script(s)
    if (!length(arq)) next
    expect_length(nao_resolvidos(arq, ids_do_script(s)), 0)
    r <- nao_resolvidos(arq, ids_do_script(s)); if (length(r)) message(s, ": ", paste(head(r, 5), collapse = "; "))
  }
})
