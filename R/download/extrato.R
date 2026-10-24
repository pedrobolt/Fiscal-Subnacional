# extrato_entregas do Siconfi (E2.4): tipo de RREO e datas de homologação/retificação por ente x ano.
# O endpoint guarda só o último status de cada período; por isso cada consulta vira um snapshot novo
# (data/raw/rreo/extrato/<ano>/<ente>_s<carimbo>.json.gz), que acumula o histórico a partir de agora.

url_extrato <- function(id_ente, ano) {
  sprintf("%s/extrato_entregas?id_ente=%s&an_referencia=%d", SICONFI_URL, id_ente, as.integer(ano))
}

dir_extrato <- function(pasta, ano) file.path(pasta, "extrato", ano)

#' Baixa o extrato de um ente x ano e grava como snapshot novo. Retorna o caminho.
baixar_extrato <- function(id_ente, ano, pasta = "data/raw/rreo", tentativas = 4, pausa = 0.3,
                           log = "_log_extrato.csv", agora = Sys.time()) {
  dir.create(dir_extrato(pasta, ano), showWarnings = FALSE, recursive = TRUE)
  destino <- file.path(dir_extrato(pasta, ano), sprintf("%s_s%s.json.gz", id_ente, carimbo_utc(agora)))
  tmp <- tempfile(fileext = ".json")
  for (i in seq_len(tentativas)) {
    t0 <- Sys.time()
    res <- tryCatch({
      utils::download.file(url_extrato(id_ente, ano), tmp, quiet = TRUE, method = "libcurl")
      x <- jsonlite::fromJSON(tmp)
      if (!is.list(x) || is.null(x$items)) stop("resposta sem 'items'")
      if (isTRUE(x$hasMore)) stop("extrato paginado (hasMore): tratar paginação")
      list(ok = TRUE, linhas = NROW(x$items), msg = "")
    }, error = function(e) list(ok = FALSE, linhas = NA_integer_, msg = conditionMessage(e)),
       warning = function(w) list(ok = FALSE, linhas = NA_integer_, msg = conditionMessage(w)))
    registrar_chamada(pasta, data.frame(
      momento = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), esfera = NA, id_ente = id_ente, ano = ano,
      periodo = NA, anexo = "extrato", tipo = NA, tentativa = i, ok = res$ok, linhas = res$linhas,
      segundos = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2), msg = substr(res$msg, 1, 120)), log)
    if (res$ok) {
      parcial <- paste0(destino, ".tmp")
      con <- gzfile(parcial, "wb"); writeLines(readLines(tmp, warn = FALSE, encoding = "UTF-8"), con, useBytes = TRUE); close(con)
      if (!file.rename(parcial, destino)) stop("Falha ao renomear ", parcial, call. = FALSE)
      Sys.sleep(pausa)
      return(destino)
    }
    Sys.sleep(2 * i)
  }
  stop("Falha ao baixar o extrato ", id_ente, " ", ano, " após ", tentativas, " tentativas.", call. = FALSE)
}

#' Extrato mais recente já baixado de um ente x ano: data.frame(arquivo, baixado_em) de uma linha, ou vazio.
extrato_vigente <- function(pasta, id_ente, ano) {
  arqs <- list.files(dir_extrato(pasta, ano), pattern = paste0("^", id_ente, PADRAO_SUFIXO_SNAPSHOT, "\\.json\\.gz$"), full.names = TRUE)
  if (length(arqs) == 0) return(data.frame(arquivo = character(0), baixado_em = as.POSIXct(character(0), tz = "UTC")))
  m <- regmatches(arqs, regexpr("_s[0-9]{8}T[0-9]{6}Z", arqs))
  t <- as.POSIXct(substring(m, 3), format = "%Y%m%dT%H%M%SZ", tz = "UTC")
  o <- order(t)
  data.frame(arquivo = arqs[o][length(o)], baixado_em = t[o][length(o)])
}

#' Lê um extrato e devolve só as entregas do RREO (padrão e simplificado), uma linha por período.
#' tipo = "RREO" ou "RREO Simplificado"; status: HO (homologado) ou RE (retificado); data_status em UTC.
ler_extrato <- function(arquivo) {
  x <- jsonlite::fromJSON(gzfile(arquivo))$items
  vazio <- data.frame(cod_ibge = integer(0), exercicio = integer(0), periodo = integer(0), tipo = character(0),
                      status = character(0), data_status = as.POSIXct(character(0), tz = "UTC"))
  if (NROW(x) == 0) return(vazio)
  faltam <- setdiff(c("cod_ibge", "exercicio", "entregavel", "periodo", "status_relatorio", "data_status"), names(x))
  if (length(faltam) > 0) stop("Campos ausentes no extrato ", arquivo, ": ", paste(faltam, collapse = ", "), call. = FALSE)
  r <- x[grepl("Resumido de Execu", x$entregavel), ]
  if (nrow(r) == 0) return(vazio)
  data.frame(cod_ibge = r$cod_ibge, exercicio = r$exercicio, periodo = r$periodo,
             tipo = ifelse(grepl("Simplificado", r$entregavel), "RREO Simplificado", "RREO"),
             status = r$status_relatorio,
             data_status = as.POSIXct(r$data_status, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
             stringsAsFactors = FALSE)
}
