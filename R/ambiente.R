#' Confere o ambiente de execução do projeto
#'
#' Retorna a versão do R e a dos pacotes essenciais. Falha se algum pacote
#' essencial não estiver instalado.
#'
#' @param pacotes Pacotes que precisam estar disponíveis.
#' @return data.frame com pacote e versão.
checar_ambiente <- function(pacotes = c("targets", "testthat", "renv")) {
  faltando <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]
  if (length(faltando) > 0) {
    stop("Pacotes ausentes: ", paste(faltando, collapse = ", "),
         ". Rode renv::restore().", call. = FALSE)
  }
  data.frame(
    pacote = c("R", pacotes),
    versao = c(paste(R.version$major, R.version$minor, sep = "."),
               vapply(pacotes, function(p) as.character(utils::packageVersion(p)), character(1))),
    row.names = NULL
  )
}
