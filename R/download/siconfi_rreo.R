# Download e leitura do RREO via API do Siconfi (E2.1; reaproveitada na E2.0 para municípios).
# Regras: bruto imutável e compactado (.json.gz, um arquivo por ente x ano x bimestre x anexo);
# arquivo existente nunca é rebaixado (política de snapshots/retificações: E2.4);
# resposta vazia só é guardada para exercícios já encerrados (o bimestre corrente pode ainda não ter sido publicado);
# cada chamada é registrada em _log.csv (status, tempo, linhas).

SICONFI_URL <- "https://apidatalake.tesouro.gov.br/ords/siconfi/tt"
ANEXOS_RREO <- c(anexo01 = "RREO-Anexo 01", anexo06 = "RREO-Anexo 06")

# Municípios pequenos que optam pelo RREO semestral entregam o tipo "RREO Simplificado"
# (mesmos Anexos 1 e 6, só nos bimestres 3 e 6).
TIPOS_RREO <- c("RREO", "RREO Simplificado")

url_rreo <- function(id_ente, ano, periodo, anexo, tipo = "RREO") {
  sprintf("%s/rreo?an_exercicio=%d&nr_periodo=%d&co_tipo_demonstrativo=%s&no_anexo=%s&id_ente=%s",
          SICONFI_URL, as.integer(ano), as.integer(periodo), utils::URLencode(tipo, reserved = TRUE),
          utils::URLencode(anexo, reserved = TRUE), id_ente)
}

caminho_rreo <- function(pasta, esfera, id_ente, ano, periodo, anexo, tipo = "RREO") {
  nome_anexo <- tolower(gsub("[^0-9]", "", anexo))
  sufixo <- if (tipo == "RREO") "" else "_simpl"
  file.path(pasta, esfera, ano, sprintf("%s_b%d_a%s%s.json.gz", id_ente, as.integer(periodo), nome_anexo, sufixo))
}

registrar_chamada <- function(pasta, linha, log = "_log.csv") {
  log <- file.path(pasta, log)
  existe <- file.exists(log)
  utils::write.table(linha, log, sep = ",", row.names = FALSE, col.names = !existe, append = existe, qmethod = "double")
}

#' Baixa um demonstrativo do RREO (um ente, ano, bimestre, anexo) e guarda o JSON compactado.
#' Retorna o caminho do arquivo, ou NA se a resposta veio vazia e não foi guardada.
baixar_rreo <- function(id_ente, ano, periodo, anexo, esfera = "E", pasta = "data/raw/rreo",
                        tentativas = 4, hoje = Sys.Date(), pausa = 0.3, tipo = "RREO", log = "_log.csv") {
  destino <- caminho_rreo(pasta, esfera, id_ente, ano, periodo, anexo, tipo)
  if (file.exists(destino)) return(destino)
  dir.create(dirname(destino), showWarnings = FALSE, recursive = TRUE)
  tmp <- tempfile(fileext = ".json")
  for (i in seq_len(tentativas)) {
    t0 <- Sys.time()
    res <- tryCatch({
      utils::download.file(url_rreo(id_ente, ano, periodo, anexo, tipo), tmp, quiet = TRUE, method = "libcurl")
      x <- jsonlite::fromJSON(tmp)
      if (!is.list(x) || is.null(x$items)) stop("resposta sem 'items'")
      if (isTRUE(x$hasMore)) stop("resposta paginada (hasMore): tratar paginação")
      list(ok = TRUE, linhas = NROW(x$items), msg = "")
    }, error = function(e) list(ok = FALSE, linhas = NA_integer_, msg = conditionMessage(e)),
       warning = function(w) list(ok = FALSE, linhas = NA_integer_, msg = conditionMessage(w)))
    registrar_chamada(pasta, data.frame(
      momento = format(Sys.time(), "%Y-%m-%d %H:%M:%S"), esfera = esfera, id_ente = id_ente, ano = ano,
      periodo = periodo, anexo = anexo, tipo = tipo, tentativa = i, ok = res$ok, linhas = res$linhas,
      segundos = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2), msg = substr(res$msg, 1, 120)), log)
    if (res$ok) {
      if (res$linhas == 0 && ano >= as.integer(format(hoje, "%Y"))) return(NA_character_)
      # Gravação atômica: escreve em .tmp e renomeia. Se o processo morrer no meio, sobra só o .tmp
      # (ignorado) e o arquivo final nunca fica truncado.
      parcial <- paste0(destino, ".tmp")
      con <- gzfile(parcial, "wb"); writeLines(readLines(tmp, warn = FALSE, encoding = "UTF-8"), con, useBytes = TRUE); close(con)
      if (!file.rename(parcial, destino)) stop("Falha ao renomear ", parcial, call. = FALSE)
      Sys.sleep(pausa)
      return(destino)
    }
    Sys.sleep(2 * i)
  }
  stop("Falha ao baixar RREO ", id_ente, " ", ano, " b", periodo, " ", anexo, " após ", tentativas, " tentativas.", call. = FALSE)
}

#' Número de linhas do arquivo (NA se não existir).
linhas_rreo <- function(arquivo) {
  if (!file.exists(arquivo)) return(NA_integer_)
  NROW(jsonlite::fromJSON(gzfile(arquivo))$items)
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

#' Município: tenta "RREO" e, se vier vazio (sem declaração desse tipo), "RREO Simplificado".
#' Retorna o caminho do arquivo com dados, ou NA se nenhum dos dois tem dados.
baixar_rreo_municipal <- function(id_ente, ano, periodo, anexo, pasta = "data/raw/rreo", log = "_log_M.csv",
                                  hoje = Sys.Date()) {
  for (tipo in TIPOS_RREO) {
    p <- baixar_rreo(id_ente, ano, periodo, anexo, esfera = "M", pasta = pasta, tipo = tipo, log = log, hoje = hoje)
    if (!is.na(p) && linhas_rreo(p) > 0) return(p)
  }
  NA_character_
}

#' Coleta municipal sequencial (1 conexão por processo). Para 2 conexões, rodar 2 processos com
#' fatia = 1 e 2, de = 2: cada um pega os entes de posição congruente. Retomável.
baixar_rreo_municipios <- function(ids, anos, periodos = 6, anexos = ANEXOS_RREO, fatia = 1, de = 1,
                                   pasta = "data/raw/rreo", tag = "", hoje = Sys.Date()) {
  ids <- ids[(seq_along(ids) - 1) %% de == fatia - 1]
  log <- sprintf("_log_M%s.csv", tag)
  n <- 0
  for (ano in anos) for (b in periodos) for (anx in anexos) for (id in ids) {
    # Anexo 6: consulta só o tipo que o Anexo 1 já mostrou ter dados (poupa chamadas)
    tipos <- TIPOS_RREO
    if (anx != ANEXOS_RREO[["anexo01"]]) {
      a1 <- vapply(TIPOS_RREO, function(t) isTRUE(linhas_rreo(caminho_rreo(pasta, "M", id, ano, b, ANEXOS_RREO[["anexo01"]], t)) > 0), logical(1))
      if (any(a1)) tipos <- TIPOS_RREO[a1][1] else next   # sem Anexo 1 com dados: não há o que buscar
    }
    for (t in tipos) {
      p <- baixar_rreo(id, ano, b, anx, esfera = "M", pasta = pasta, tipo = t, log = log, hoje = hoje)
      if (!is.na(p) && linhas_rreo(p) > 0) break
    }
    n <- n + 1
  }
  invisible(n)
}

#' Valida todos os .json.gz de `pasta` (descompacta e interpreta o JSON). Retorna os caminhos inválidos.
#' Com `remover = TRUE`, apaga os inválidos para a retomada rebaixá-los. Também apaga sobras .tmp.
validar_rreo_pasta <- function(pasta = "data/raw/rreo", remover = FALSE) {
  tmps <- list.files(pasta, pattern = "\\.tmp$", recursive = TRUE, full.names = TRUE)
  if (remover && length(tmps) > 0) unlink(tmps)
  arqs <- list.files(pasta, pattern = "\\.json\\.gz$", recursive = TRUE, full.names = TRUE)
  ok <- vapply(arqs, function(a) {
    r <- try(suppressWarnings(jsonlite::fromJSON(gzfile(a))), silent = TRUE)
    !inherits(r, "try-error") && is.list(r) && !is.null(r$items)
  }, logical(1))
  ruins <- arqs[!ok]
  if (remover && length(ruins) > 0) unlink(ruins)
  ruins
}
