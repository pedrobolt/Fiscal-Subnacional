# RGF (Relatório de Gestão Fiscal) dos estados, Anexo 01 (despesa com pessoal), Poder Executivo, quadrimestral.
# Traz 12 colunas mensais (<MR-11>..<MR>, MR = último mês do quadrimestre) por conta. Usado no cruzamento de pessoal do E2.8.
# Mesmas regras do RREO: bruto imutável e compactado, gravação atômica, log, retomável.
url_rgf <- function(id_ente, ano, periodo, anexo = "RGF-Anexo 01", poder = "E")
  sprintf("%s/rgf?an_exercicio=%d&in_periodicidade=Q&nr_periodo=%d&co_tipo_demonstrativo=RGF&no_anexo=%s&co_poder=%s&id_ente=%s",
          SICONFI_URL, as.integer(ano), as.integer(periodo), utils::URLencode(anexo, reserved = TRUE), poder, id_ente)

caminho_rgf <- function(pasta, id_ente, ano, periodo) file.path(pasta, "E", ano, sprintf("%s_q%d_a01.json.gz", id_ente, as.integer(periodo)))

#' Quadrimestre já encerrado e com prazo de publicação passado (30 dias).
quadrimestre_disponivel <- function(ano, q, hoje = Sys.Date()) {
  fim <- as.Date(sprintf("%d-%02d-01", ano + (q == 3L), ifelse(q == 3L, 1L, 4L * q + 1L)))
  hoje >= fim + 30L
}

baixar_rgf <- function(id_ente, ano, periodo, pasta = "data/raw/rgf", tentativas = 4, pausa = 0.3) {
  destino <- caminho_rgf(pasta, id_ente, ano, periodo)
  if (file.exists(destino)) return(destino)
  dir.create(dirname(destino), showWarnings = FALSE, recursive = TRUE)
  tmp <- tempfile(fileext = ".json")
  for (i in seq_len(tentativas)) {
    t0 <- Sys.time()
    res <- tryCatch({
      utils::download.file(url_rgf(id_ente, ano, periodo), tmp, quiet = TRUE, method = "libcurl")
      x <- ler_json_utf8(tmp)
      if (!is.list(x) || is.null(x$items)) stop("resposta sem 'items'")
      if (isTRUE(x$hasMore)) stop("resposta paginada (hasMore): tratar paginação")
      list(ok = TRUE, linhas = NROW(x$items), msg = "")
    }, error = function(e) list(ok = FALSE, linhas = NA_integer_, msg = conditionMessage(e)),
       warning = function(w) list(ok = FALSE, linhas = NA_integer_, msg = conditionMessage(w)))
    dir.create(pasta, showWarnings = FALSE, recursive = TRUE)
    gravar_csv(data.frame(momento = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), id_ente = id_ente, ano = ano, periodo = periodo,
                          tentativa = i, ok = res$ok, linhas = res$linhas,
                          segundos = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2), msg = substr(res$msg, 1, 120)),
               file.path(pasta, "_log.csv"), append = TRUE)
    if (res$ok) {
      if (res$linhas == 0) return(NA_character_)          # sem RGF nesse período: não grava, tenta de novo na rodada seguinte
      parcial <- paste0(destino, ".tmp")
      gravar_gz_bytes(tmp, parcial)
      if (!file.rename(parcial, destino)) stop("Falha ao renomear ", parcial, call. = FALSE)
      Sys.sleep(pausa)
      return(destino)
    }
    Sys.sleep(2 * i)
  }
  stop("Falha ao baixar RGF ", id_ente, " ", ano, " q", periodo, " após ", tentativas, " tentativas.", call. = FALSE)
}

ler_rgf <- function(arquivo) ler_json_utf8(arquivo)$items

baixar_rgf_estados <- function(anos = 2015:as.integer(format(Sys.Date(), "%Y")), pasta = "data/raw/rgf", hoje = Sys.Date()) {
  entes <- ler_entes(baixar_entes("data/raw/rreo", hoje))
  est <- listar_estados(entes); stopifnot(nrow(est) == 27)
  for (a in anos) for (q in 1:3) { if (!quadrimestre_disponivel(a, q, hoje)) next; for (id in est$cod_ibge) baixar_rgf(id, a, q, pasta) }
  invisible(TRUE)
}
