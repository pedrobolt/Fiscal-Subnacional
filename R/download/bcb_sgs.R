# Download e leitura de séries do SGS/BCB (E1.5).
# Regra: o dado bruto é imutável. Cada download vira um arquivo datado em data/raw/;
# se já houver arquivo do mesmo dia, ele é reaproveitado, nunca sobrescrito.

# Séries NFSP sem desvalorização cambial, fluxo mensal corrente, resultado primário, R$ milhões.
# Convenção do BCB: déficit positivo, superávit negativo (o sinal é invertido em ler_sgs_primario).
SGS_PRIMARIO <- c(regionais = 4642L, estaduais = 4643L, municipais = 4644L)

url_sgs <- function(codigo, inicio, fim) {
  sprintf("https://api.bcb.gov.br/dados/serie/bcdata.sgs.%d/dados?formato=json&dataInicial=%s&dataFinal=%s",
          as.integer(codigo), format(inicio, "%d/%m/%Y"), format(fim, "%d/%m/%Y"))
}

#' Baixa uma série do SGS e guarda o JSON bruto em data/raw/. Retorna o caminho do arquivo.
baixar_sgs <- function(codigo, inicio, fim, pasta = "data/raw", hoje = Sys.Date(), tentativas = 4) {
  dir.create(pasta, showWarnings = FALSE, recursive = TRUE)
  destino <- file.path(pasta, sprintf("bcb_sgs_%d_%s.json", as.integer(codigo), format(hoje, "%Y%m%d")))
  if (file.exists(destino)) return(destino)
  tmp <- tempfile(fileext = ".json")
  for (i in seq_len(tentativas)) {
    ok <- tryCatch({
      utils::download.file(url_sgs(codigo, inicio, fim), tmp, quiet = TRUE, method = "libcurl")
      !inherits(try(jsonlite::fromJSON(tmp), silent = TRUE), "try-error")
    }, error = function(e) FALSE, warning = function(w) FALSE)
    if (isTRUE(ok)) { file.copy(tmp, destino); return(destino) }
    Sys.sleep(2 * i)  # a API do BCB falha de forma intermitente
  }
  stop("Falha ao baixar a série SGS ", codigo, " após ", tentativas, " tentativas.", call. = FALSE)
}

#' Lê o JSON bruto do SGS. Retorna data.frame(data, valor) com o valor como veio (R$ milhões).
ler_sgs <- function(arquivo) {
  x <- jsonlite::fromJSON(arquivo)
  if (!is.data.frame(x) || !all(c("data", "valor") %in% names(x))) {
    stop("Formato inesperado no arquivo SGS: ", arquivo, call. = FALSE)
  }
  out <- data.frame(data = as.Date(x$data, format = "%d/%m/%Y"), valor = as.numeric(x$valor))
  if (anyNA(out$data) || anyNA(out$valor)) stop("Datas ou valores inválidos em ", arquivo, call. = FALSE)
  out[order(out$data), ]
}

#' Converte a série primária do BCB para a convenção do contrato:
#' superávit positivo (sinal invertido) e R$ bilhões. Retorna data.frame(data, valor_bi).
primario_bi <- function(sgs) {
  data.frame(data = sgs$data, valor_bi = -sgs$valor / 1000)
}
