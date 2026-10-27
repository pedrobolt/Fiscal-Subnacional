# Transferências constitucionais da STN (FPE por estado; FPM por município), E2.3. Fonte: Tesouro Transparente (CKAN).
# O servidor limita a taxa de requisições (HTTP 429 com Retry-After): o download é espaçado, respeita o Retry-After e
# para depois de poucas recusas seguidas, em vez de insistir. Nada é sobrescrito; arquivos inválidos (HTML) não são gravados.

STN_CKAN <- "https://www.tesourotransparente.gov.br/ckan/api/3/action/package_show?id="
STN_DATASETS <- c(estados = "transferencias-constitucionais-para-estados",
                  municipios = "transferencias-constitucionais-para-municipios")

#' Recursos CSV de um conjunto (nome, url, tamanho). Descarta duplicatas de nome ficando com a maior (a versão completa).
recursos_stn <- function(dataset) {
  x <- jsonlite::fromJSON(paste0(STN_CKAN, STN_DATASETS[[dataset]]))
  r <- x$result$resources
  r <- r[toupper(r$format) == "CSV", c("name", "url", "size")]
  r$size <- suppressWarnings(as.numeric(r$size)); r$size[is.na(r$size)] <- 0
  r <- r[order(r$name, -r$size), ]
  r <- r[!duplicated(r$name), ]
  rownames(r) <- NULL
  r
}

#' O arquivo parece um CSV de dados (e não a página HTML de erro)?
csv_valido <- function(arquivo) {
  l <- readLines(arquivo, n = 3, warn = FALSE, encoding = "latin1")
  length(l) >= 2 && !any(grepl("<html|<!DOCTYPE", l, ignore.case = TRUE))
}

#' Baixa os arquivos que faltam em `pasta/<dataset>/`. `pausa`: segundos entre pedidos. Respeita Retry-After e
#' interrompe após `max_recusas` recusas (429) seguidas. Retorna data.frame(name, situacao).
baixar_stn <- function(dataset, pasta = "data/raw/stn", pausa = 5, max_recusas = 3, filtro = NULL) {
  dest <- file.path(pasta, dataset); dir.create(dest, showWarnings = FALSE, recursive = TRUE)
  r <- recursos_stn(dataset)
  if (!is.null(filtro)) r <- r[grepl(filtro, r$name), ]
  sit <- character(nrow(r)); recusas <- 0
  for (i in seq_len(nrow(r))) {
    f <- file.path(dest, r$name[i])
    if (file.exists(f)) { sit[i] <- "existente"; next }
    if (recusas >= max_recusas) { sit[i] <- "nao_tentado"; next }
    tmp <- tempfile(); h <- tempfile()
    code <- system2("curl", c("-s", "--max-time", "120", "-D", shQuote(h), "-o", shQuote(tmp), "-w", shQuote("%{http_code}"), shQuote(r$url[i])), stdout = TRUE)
    hdr <- readLines(h, warn = FALSE)
    if (identical(code, "429") || any(grepl("429", hdr[1])) || (file.exists(tmp) && !csv_valido(tmp))) {
      recusas <- recusas + 1; sit[i] <- "recusado"
      ra <- suppressWarnings(as.numeric(sub("(?i)^retry-after:\\s*", "", grep("^retry-after", hdr, ignore.case = TRUE, value = TRUE)[1], perl = TRUE)))
      Sys.sleep(if (is.finite(ra)) ra + 5 else 60)
      next
    }
    recusas <- 0
    file.rename(tmp, f) || file.copy(tmp, f)
    sit[i] <- "baixado"
    Sys.sleep(pausa)
  }
  data.frame(name = r$name, situacao = sit)
}
