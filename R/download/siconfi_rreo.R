# Download e leitura do RREO via API do Siconfi (E2.1; reaproveitada na E2.0 para municípios).
# Regras: bruto imutável e compactado (.json.gz, um arquivo por ente x ano x bimestre x anexo);
# arquivo existente nunca é rebaixado (política de snapshots/retificações: E2.4);
# resposta vazia só é guardada para exercícios já encerrados (o bimestre corrente pode ainda não ter sido publicado);
# cada chamada é registrada em _log.csv (status, tempo, linhas).

SICONFI_URL <- "https://apidatalake.tesouro.gov.br/ords/siconfi/tt"
ANEXOS_RREO <- c(anexo01 = "RREO-Anexo 01", anexo06 = "RREO-Anexo 06")

url_rreo <- function(id_ente, ano, periodo, anexo) {
  sprintf("%s/rreo?an_exercicio=%d&nr_periodo=%d&co_tipo_demonstrativo=RREO&no_anexo=%s&id_ente=%s",
          SICONFI_URL, as.integer(ano), as.integer(periodo), utils::URLencode(anexo, reserved = TRUE), id_ente)
}

caminho_rreo <- function(pasta, esfera, id_ente, ano, periodo, anexo) {
  nome_anexo <- tolower(gsub("[^0-9]", "", anexo))
  file.path(pasta, esfera, ano, sprintf("%s_b%d_a%s.json.gz", id_ente, as.integer(periodo), nome_anexo))
}

registrar_chamada <- function(pasta, linha) {
  log <- file.path(pasta, "_log.csv")
  existe <- file.exists(log)
  utils::write.table(linha, log, sep = ",", row.names = FALSE, col.names = !existe, append = existe, qmethod = "double")
}

#' Baixa um demonstrativo do RREO (um ente, ano, bimestre, anexo) e guarda o JSON compactado.
#' Retorna o caminho do arquivo, ou NA se a resposta veio vazia e não foi guardada.
baixar_rreo <- function(id_ente, ano, periodo, anexo, esfera = "E", pasta = "data/raw/rreo",
                        tentativas = 4, hoje = Sys.Date(), pausa = 0.3) {
  destino <- caminho_rreo(pasta, esfera, id_ente, ano, periodo, anexo)
  if (file.exists(destino)) return(destino)
  dir.create(dirname(destino), showWarnings = FALSE, recursive = TRUE)
  tmp <- tempfile(fileext = ".json")
  for (i in seq_len(tentativas)) {
    t0 <- Sys.time()
    res <- tryCatch({
      utils::download.file(url_rreo(id_ente, ano, periodo, anexo), tmp, quiet = TRUE, method = "libcurl")
      x <- jsonlite::fromJSON(tmp)
      if (!is.list(x) || is.null(x$items)) stop("resposta sem 'items'")
      if (isTRUE(x$hasMore)) stop("resposta paginada (hasMore): tratar paginação")
      list(ok = TRUE, linhas = NROW(x$items), msg = "")
    }, error = function(e) list(ok = FALSE, linhas = NA_integer_, msg = conditionMessage(e)),
       warning = function(w) list(ok = FALSE, linhas = NA_integer_, msg = conditionMessage(w)))
    registrar_chamada(pasta, data.frame(
      momento = format(Sys.time(), "%Y-%m-%d %H:%M:%S"), esfera = esfera, id_ente = id_ente, ano = ano,
      periodo = periodo, anexo = anexo, tentativa = i, ok = res$ok, linhas = res$linhas,
      segundos = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2), msg = substr(res$msg, 1, 120)))
    if (res$ok) {
      if (res$linhas == 0 && ano >= as.integer(format(hoje, "%Y"))) return(NA_character_)
      con <- gzfile(destino, "wb"); writeLines(readLines(tmp, warn = FALSE, encoding = "UTF-8"), con, useBytes = TRUE); close(con)
      Sys.sleep(pausa)
      return(destino)
    }
    Sys.sleep(2 * i)
  }
  stop("Falha ao baixar RREO ", id_ente, " ", ano, " b", periodo, " ", anexo, " após ", tentativas, " tentativas.", call. = FALSE)
}

#' Lê um arquivo do RREO e devolve formato longo: uma linha por conta x coluna, sem somar nem reclassificar.
ler_rreo <- function(arquivo) {
  x <- jsonlite::fromJSON(gzfile(arquivo))$items
  if (NROW(x) == 0) return(data.frame())
  cols <- c("exercicio", "periodo", "periodicidade", "cod_ibge", "instituicao", "uf", "populacao", "esfera",
            "anexo", "rotulo", "coluna", "cod_conta", "conta", "valor")
  faltam <- setdiff(cols, names(x))
  if (length(faltam) > 0) stop("Campos ausentes no RREO ", arquivo, ": ", paste(faltam, collapse = ", "), call. = FALSE)
  x[, cols]
}

#' Lista dos 27 entes estaduais (26 estados "E" + Distrito Federal "D") a partir do endpoint /entes.
listar_estados <- function(entes) {
  e <- entes[entes$esfera %in% c("E", "D"), c("cod_ibge", "ente", "esfera")]
  e[order(e$cod_ibge), ]
}

baixar_entes <- function(pasta = "data/raw/rreo", hoje = Sys.Date()) {
  dir.create(pasta, showWarnings = FALSE, recursive = TRUE)
  destino <- file.path(pasta, sprintf("_entes_%s.json", format(hoje, "%Y%m%d")))
  if (!file.exists(destino)) {
    utils::download.file(paste0(SICONFI_URL, "/entes?limit=10000"), destino, quiet = TRUE, method = "libcurl")
  }
  destino
}

ler_entes <- function(arquivo) {
  x <- jsonlite::fromJSON(arquivo)
  if (isTRUE(x$hasMore)) stop("Lista de entes paginada: tratar paginação", call. = FALSE)
  x$items
}

#' O bimestre b de `ano` já deveria estar publicado em `hoje`? (encerra no mês 2b; publicação em até 30 dias)
bimestre_disponivel <- function(ano, b, hoje = Sys.Date()) {
  atual <- as.integer(format(hoje, "%Y"))
  if (ano < atual) return(TRUE)
  if (ano > atual) return(FALSE)
  b <= (as.integer(format(hoje, "%m")) - 1) %/% 2
}

#' Baixa em lote (sequencial, 1 conexão) e devolve os caminhos obtidos. Reentrante: pula o que já existe.
baixar_rreo_lote <- function(entes, anos, periodos = 1:6, anexos = ANEXOS_RREO, esfera = "E",
                             pasta = "data/raw/rreo", hoje = Sys.Date()) {
  caminhos <- character(0)
  for (ano in anos) for (b in periodos) for (anx in anexos) for (id in entes) {
    if (!bimestre_disponivel(ano, b, hoje)) next
    p <- baixar_rreo(id, ano, b, anx, esfera = esfera, pasta = pasta, hoje = hoje)
    if (!is.na(p)) caminhos <- c(caminhos, p)
  }
  caminhos
}

#' E2.1: baixa o RREO (Anexos 1 e 6) dos 27 entes estaduais. Sequencial (1 conexão) e retomável.
#' Rodar fora do pipeline: Rscript -e 'source("_targets.R"); baixar_rreo_estados()'
baixar_rreo_estados <- function(anos = 2015:2026, pasta = "data/raw/rreo", hoje = Sys.Date()) {
  entes <- ler_entes(baixar_entes(pasta, hoje))
  estados <- listar_estados(entes)
  stopifnot(nrow(estados) == 27)
  invisible(baixar_rreo_lote(estados$cod_ibge, anos, pasta = pasta, hoje = hoje))
}
