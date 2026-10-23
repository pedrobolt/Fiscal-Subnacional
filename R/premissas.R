# Leitura e validação de premissas.yml (E1.4).
# O arquivo real não é versionado; o formato está em premissas.exemplo.yml.

#' Lê e valida o arquivo de premissas macroeconômicas.
#'
#' @param caminho caminho do arquivo YAML.
#' @param ano_t ano corrente do modelo; precisa ter todas as séries preenchidas.
#' @return lista com versao, fonte e data.frame `anos` (ano, ipca, pib_real, pib_nominal).
ler_premissas <- function(caminho = "premissas.yml", ano_t = as.integer(format(Sys.Date(), "%Y"))) {
  if (!file.exists(caminho)) {
    stop("Arquivo de premissas não encontrado: ", caminho,
         ". Copie premissas.exemplo.yml para premissas.yml e preencha.", call. = FALSE)
  }
  x <- yaml::read_yaml(caminho)

  campos <- c("ipca", "pib_real", "pib_nominal")
  ausentes <- setdiff(c("versao", "fonte", campos), names(x))
  if (length(ausentes) > 0) {
    stop("Campos ausentes em premissas: ", paste(ausentes, collapse = ", "), call. = FALSE)
  }

  anos <- sort(unique(as.integer(unlist(lapply(x[campos], names)))))
  if (!(ano_t %in% anos)) {
    stop("Ano t (", ano_t, ") ausente nas premissas.", call. = FALSE)
  }

  pega <- function(campo) {
    v <- x[[campo]][as.character(anos)]
    vapply(v, function(z) if (is.null(z)) NA_real_ else as.numeric(z), numeric(1))
  }
  d <- data.frame(ano = anos, ipca = pega("ipca"), pib_real = pega("pib_real"),
                  pib_nominal = pega("pib_nominal"), row.names = NULL)

  # O ano t precisa estar completo; anos seguintes podem ficar em branco.
  linha_t <- d[d$ano == ano_t, campos]
  vazios <- campos[is.na(unlist(linha_t))]
  if (length(vazios) > 0) {
    stop("Premissas do ano ", ano_t, " em branco: ", paste(vazios, collapse = ", "), call. = FALSE)
  }

  # Faixas de sanidade (pegam erro de unidade, p. ex. 5 em vez de 0.05).
  fora <- function(v, lo, hi) any(!is.na(v) & (v < lo | v > hi))
  if (fora(d$ipca, -0.05, 0.5)) stop("IPCA fora da faixa [-5%, 50%]: use fração (0.05 = 5%).", call. = FALSE)
  if (fora(d$pib_real, -0.2, 0.2)) stop("PIB real fora da faixa [-20%, 20%]: use fração.", call. = FALSE)
  if (fora(d$pib_nominal, 1e3, 1e5)) stop("PIB nominal fora da faixa [1.000; 100.000] R$ bilhões.", call. = FALSE)

  list(versao = as.character(x$versao), fonte = as.character(x$fonte), anos = d)
}
