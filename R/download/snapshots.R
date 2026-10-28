# Versões (snapshots) do bruto do RREO (E2.4).
# Arquivo existente nunca é sobrescrito. Uma retificação entra como arquivo novo com sufixo
# `_s<AAAAMMDDTHHMMSSZ>` (UTC): `123_b6_a01.json.gz` (versão original) -> `123_b6_a01_s20261101T120000Z.json.gz`.
# A versão vigente é a mais recente. A data da original vem do primeiro registro `ok` nos `_log*.csv`
# (não do mtime, que muda ao copiar, extrair ou restaurar); sem registro, cai no mtime e é marcada.

PADRAO_SUFIXO_SNAPSHOT <- "_s[0-9]{8}T[0-9]{6}Z"

carimbo_utc <- function(momento = Sys.time()) format(momento, "%Y%m%dT%H%M%SZ", tz = "UTC")

caminho_snapshot <- function(base, momento = Sys.time()) {
  sub("\\.json\\.gz$", paste0("_s", carimbo_utc(momento), ".json.gz"), base)
}

#' Converte a coluna `momento` dos logs (hora local antiga ou UTC com "Z") em segundos desde 1970.
momento_log_numerico <- function(x) {
  utc_z <- grepl("Z$", x)
  ifelse(utc_z,
         as.numeric(as.POSIXct(sub("Z$", "", sub("T", " ", x)), tz = "UTC", format = "%Y-%m-%d %H:%M:%S")),
         as.numeric(as.POSIXct(x, tz = "America/Sao_Paulo", format = "%Y-%m-%d %H:%M:%S")))
}

#' Chave (esfera|id|ano|periodo|anexo|tipo) de um arquivo `pasta/esfera/ano/<id>_b<p>_a<nn>[_simpl][_s...].json.gz`.
chave_arquivo <- function(arq) {
  nome <- sub(paste0(PADRAO_SUFIXO_SNAPSHOT, "(\\.json\\.gz)$"), "\\1", basename(arq))
  m <- regmatches(nome, regexec("^([0-9]+)_b([0-9]+)_a([0-9]+)(_simpl)?\\.json\\.gz$", nome))
  vapply(seq_along(arq), function(i) {
    x <- m[[i]]
    if (length(x) == 0) return(NA_character_)
    ano <- basename(dirname(arq[i])); esf <- basename(dirname(dirname(arq[i])))
    paste(esf, x[2], ano, as.integer(x[3]), x[4], if (nzchar(x[5])) "RREO Simplificado" else "RREO", sep = "|")
  }, character(1))
}

#' Momento (UTC, numérico) em que cada demonstrativo foi baixado pela primeira vez, a partir dos
#' `_log*.csv` da pasta raiz (primeira chamada com ok = TRUE). Não depende da data dos arquivos,
#' que muda ao copiar, extrair ou restaurar do Release. Logs antigos gravam hora local sem fuso
#' ("AAAA-MM-DD HH:MM:SS", gerados na nuvem, America/Sao_Paulo); logs novos gravam UTC com "Z".
#' Retorna vetor nomeado pela chave (ver `chave_arquivo`).
momentos_originais <- function(pasta) {
  logs <- list.files(pasta, pattern = "^_log.*\\.csv$", full.names = TRUE)
  logs <- logs[!grepl("_log_extrato", basename(logs))]
  partes <- lapply(logs, function(f) {
    d <- tryCatch(utils::read.csv(fileEncoding = "UTF-8", f, stringsAsFactors = FALSE, colClasses = "character"), error = function(e) NULL)
    if (is.null(d) || !all(c("momento", "esfera", "id_ente", "ano", "periodo", "anexo", "tipo", "ok") %in% names(d))) return(NULL)
    d <- d[d$ok == "TRUE", , drop = FALSE]
    if (nrow(d) == 0) return(NULL)
    t <- momento_log_numerico(d$momento)
    data.frame(chave = paste(d$esfera, d$id_ente, d$ano, as.integer(d$periodo), gsub("[^0-9]", "", d$anexo), d$tipo, sep = "|"),
               t = t, stringsAsFactors = FALSE)
  })
  todos <- do.call(rbind, partes)
  if (is.null(todos) || nrow(todos) == 0) return(stats::setNames(numeric(0), character(0)))
  todos <- todos[!is.na(todos$t), ]
  r <- tapply(todos$t, todos$chave, min); stats::setNames(as.numeric(r), names(r))
}

#' Data de cada versão: snapshots usam o carimbo do nome; a original usa o primeiro registro do log;
#' sem registro, cai na data do arquivo (fonte = "mtime", menos confiável).
#' Retorna data.frame(baixado_em [POSIXct UTC], fonte ["nome", "log" ou "mtime"]).
datas_versoes <- function(arqs, pasta, momentos = momentos_originais(pasta)) {
  m <- regexpr(PADRAO_SUFIXO_SNAPSHOT, arqs)
  eh_snap <- m > 0
  t <- rep(NA_real_, length(arqs)); fonte <- rep(NA_character_, length(arqs))
  if (any(eh_snap)) {
    t[eh_snap] <- as.numeric(as.POSIXct(substring(regmatches(arqs, m), 3), format = "%Y%m%dT%H%M%SZ", tz = "UTC"))
    fonte[eh_snap] <- "nome"
  }
  if (any(!eh_snap)) {
    ch <- chave_arquivo(arqs[!eh_snap]); tl <- unname(momentos[ch])
    usa_log <- !is.na(tl)
    tt <- ifelse(usa_log, tl, as.numeric(file.mtime(arqs[!eh_snap])))
    t[!eh_snap] <- tt; fonte[!eh_snap] <- ifelse(usa_log, "log", "mtime")
  }
  data.frame(baixado_em = as.POSIXct(t, origin = "1970-01-01", tz = "UTC"), fonte = fonte, stringsAsFactors = FALSE)
}

#' Todas as versões de um demonstrativo (base + snapshots), da mais antiga para a mais recente.
#' Retorna data.frame(arquivo, baixado_em [POSIXct UTC], fonte); vazio se não houver nenhuma.
#' `momentos`: resultado de `momentos_originais(pasta)`, a ser passado quando chamado em laço.
versoes_rreo <- function(base, momentos = NULL) {
  vazio <- data.frame(arquivo = character(0), baixado_em = as.POSIXct(character(0), tz = "UTC"), fonte = character(0))
  dir <- dirname(base)
  if (!dir.exists(dir)) return(vazio)
  stem <- sub("\\.json\\.gz$", "", basename(base))
  arqs <- list.files(dir, pattern = paste0("^", stem, "(", PADRAO_SUFIXO_SNAPSHOT, ")?\\.json\\.gz$"), full.names = TRUE)
  if (length(arqs) == 0) return(vazio)
  if (is.null(momentos)) momentos <- momentos_originais(dirname(dirname(dir)))
  out <- cbind(data.frame(arquivo = arqs, stringsAsFactors = FALSE), datas_versoes(arqs, dirname(dirname(dir)), momentos))
  out[order(out$baixado_em, out$arquivo), ]
}

#' Caminho da versão vigente (mais recente) ou NA. Não depende de datas de arquivo: a original é
#' sempre anterior aos snapshots, e estes se ordenam pelo carimbo no nome.
arquivo_vigente <- function(base) {
  dir <- dirname(base)
  if (!dir.exists(dir)) return(NA_character_)
  stem <- sub("\\.json\\.gz$", "", basename(base))
  arqs <- list.files(dir, pattern = paste0("^", stem, "(", PADRAO_SUFIXO_SNAPSHOT, ")?\\.json\\.gz$"), full.names = TRUE)
  if (length(arqs) == 0) return(NA_character_)
  snaps <- sort(arqs[grepl(PADRAO_SUFIXO_SNAPSHOT, arqs)])
  if (length(snaps)) snaps[length(snaps)] else arqs[1]
}

baixado_em_vigente <- function(base, momentos = NULL) {
  v <- versoes_rreo(base, momentos)
  if (nrow(v) == 0) as.POSIXct(NA, tz = "UTC") else v$baixado_em[nrow(v)]
}

#' Versão vigente do demonstrativo de um ente (ou NA).
vigente_rreo <- function(pasta, esfera, id_ente, ano, periodo, anexo, tipo = "RREO") {
  arquivo_vigente(caminho_rreo(pasta, esfera, id_ente, ano, periodo, anexo, tipo))
}

# --- JSON em UTF-8 independente do locale ---------------------------------------------------------------------------
# Os brutos do Siconfi são UTF-8. Ler/gravar via conexão de texto usa o encoding nativo (CP1252/850 no Windows) e
# estraga os acentos. Aqui o conteúdo é sempre tratado como bytes UTF-8, sem tradução.

#' Lê um JSON (texto puro ou .gz) como UTF-8, qualquer que seja o locale.
ler_json_utf8 <- function(arquivo) {
  con <- gzfile(arquivo, "rb"); on.exit(close(con))
  partes <- list()
  repeat { b <- readBin(con, "raw", 1e6); if (!length(b)) break; partes[[length(partes) + 1L]] <- b }
  txt <- rawToChar(unlist(partes)); Encoding(txt) <- "UTF-8"
  jsonlite::fromJSON(txt)
}

#' Copia `origem` (JSON em texto) para `destino` comprimido em gzip, byte a byte (sem passar pelo encoding nativo).
gravar_gz_bytes <- function(origem, destino) {
  bytes <- readBin(origem, "raw", file.size(origem))
  con <- gzfile(destino, "wb"); on.exit(close(con))
  writeBin(bytes, con)
  invisible(destino)
}

#' Caminho normalizado (barras "/", sem exigir que exista), para comparar caminhos em qualquer sistema.
caminho_norm <- function(x) normalizePath(x, winslash = "/", mustWork = FALSE)
