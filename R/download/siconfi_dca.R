# DCA (Declaração de Contas Anuais) dos estados, Anexo I-C (receita orçamentária): receita bruta realizada e deduções
# (transferências constitucionais, FUNDEB, outras) por conta. Usada para validar o bruto do RREO Anexo 3 e o regime do Anexo 6.
# Mesmas regras do RREO: bruto imutável e compactado, gravação atômica, log de chamadas, retomável.
url_dca <- function(id_ente, ano, anexo = "DCA-Anexo I-C")
  sprintf("%s/dca?an_exercicio=%d&id_ente=%s&no_anexo=%s", SICONFI_URL, as.integer(ano), id_ente, utils::URLencode(anexo, reserved = TRUE))

caminho_dca <- function(pasta, id_ente, ano) file.path(pasta, "E", ano, sprintf("%s_i_c.json.gz", id_ente))

baixar_dca <- function(id_ente, ano, pasta = "data/raw/dca", tentativas = 4, pausa = 0.3) {
  destino <- caminho_dca(pasta, id_ente, ano)
  if (file.exists(destino)) return(destino)
  dir.create(dirname(destino), showWarnings = FALSE, recursive = TRUE)
  tmp <- tempfile(fileext = ".json")
  for (i in seq_len(tentativas)) {
    t0 <- Sys.time()
    res <- tryCatch({
      utils::download.file(url_dca(id_ente, ano), tmp, quiet = TRUE, method = "libcurl")
      x <- ler_json_utf8(tmp)
      if (!is.list(x) || is.null(x$items)) stop("resposta sem 'items'")
      if (isTRUE(x$hasMore)) stop("resposta paginada (hasMore): tratar paginação")
      list(ok = TRUE, linhas = NROW(x$items), msg = "")
    }, error = function(e) list(ok = FALSE, linhas = NA_integer_, msg = conditionMessage(e)),
       warning = function(w) list(ok = FALSE, linhas = NA_integer_, msg = conditionMessage(w)))
    dir.create(pasta, showWarnings = FALSE, recursive = TRUE)
    gravar_csv(data.frame(momento = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), id_ente = id_ente, ano = ano, tentativa = i,
                          ok = res$ok, linhas = res$linhas, segundos = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2),
                          msg = substr(res$msg, 1, 120)), file.path(pasta, "_log.csv"), append = TRUE)
    if (res$ok) {
      if (res$linhas == 0) return(NA_character_)          # exercício sem DCA: não grava
      parcial <- paste0(destino, ".tmp")
      gravar_gz_bytes(tmp, parcial)
      if (!file.rename(parcial, destino)) stop("Falha ao renomear ", parcial, call. = FALSE)
      Sys.sleep(pausa)
      return(destino)
    }
    Sys.sleep(2 * i)
  }
  stop("Falha ao baixar DCA ", id_ente, " ", ano, " após ", tentativas, " tentativas.", call. = FALSE)
}

ler_dca <- function(arquivo) ler_json_utf8(arquivo)$items

baixar_dca_estados <- function(anos = 2015:2025, pasta = "data/raw/dca") {
  entes <- ler_entes(baixar_entes("data/raw/rreo", Sys.Date()))
  est <- listar_estados(entes); stopifnot(nrow(est) == 27)
  for (a in anos) for (id in est$cod_ibge) baixar_dca(id, a, pasta)
  invisible(TRUE)
}
