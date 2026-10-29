# Receita mensal dos estados a partir do RREO Anexo 3 (RCL): 12 colunas mensais "<MR-11>".."<MR>" (MR = último mês do
# bimestre), "TOTAL (ÚLTIMOS 12 MESES)" e "PREVISÃO ATUALIZADA AAAA". Os nomes das contas mudam por layout (prefixo RREO3
# a partir de 2018); a categoria é atribuída pelo nome sem o prefixo.

# CATEGORIAS_A3 está em R/transform/dicionario_contas.R (a mesma lista alimenta o dicionário de contas do Anexo 3).

#' Categoria da conta do Anexo 3 (NA se não for uma das acompanhadas).
categoria_a3 <- function(cod_conta) unname(CATEGORIAS_A3[sub("^RREO3", "", cod_conta)])

#' Mês (1o dia) a que se refere a coluna mensal do Anexo 3; NA para TOTAL e PREVISÃO.
mes_coluna_a3 <- function(exercicio, periodo, coluna) {
  k <- ifelse(coluna == "<MR>", 0L, suppressWarnings(as.integer(sub("^<MR-([0-9]+)>$", "\\1", coluna))))
  k[!grepl("^<MR(-[0-9]+)?>$", coluna)] <- NA_integer_
  m <- 2L * as.integer(periodo) - k                      # mês corrido desde janeiro do exercício (pode ser <= 0)
  ano <- as.integer(exercicio) + (m - 1L) %/% 12L
  mes <- (m - 1L) %% 12L + 1L
  as.Date(ifelse(is.na(k), NA_character_, sprintf("%04d-%02d-01", ano, mes)))
}

#' Lê os arquivos do Anexo 3 dos estados (versão original, sem snapshots) e devolve formato longo das contas acompanhadas:
#' cod_ibge, uf, exercicio, periodo, categoria, tipo ("mensal", "total12m", "previsao"), mes, valor.
ler_a3_estados <- function(pasta = "data/raw/rreo/E") {
  arqs <- list.files(pasta, "^[0-9]+_b[1-6]_a03\\.json\\.gz$", recursive = TRUE, full.names = TRUE)
  out <- lapply(arqs, function(a) {
    x <- ler_rreo(a)
    if (!NROW(x)) return(NULL)
    x$categoria <- categoria_a3(x$cod_conta)
    x <- x[!is.na(x$categoria), ]
    if (!NROW(x)) return(NULL)
    x$tipo <- ifelse(grepl("^<MR", x$coluna), "mensal", ifelse(grepl("^TOTAL", x$coluna), "total12m", "previsao"))
    x$mes <- mes_coluna_a3(x$exercicio, x$periodo, x$coluna)
    x[, c("cod_ibge", "uf", "exercicio", "periodo", "categoria", "tipo", "mes", "valor")]
  })
  do.call(rbind, out)
}

#' Receita mensal por UF x categoria x mês, comparando as versões do mesmo mês em arquivos de bimestres diferentes
#' (um mês aparece em até 12 arquivos). Devolve `ultima` (valor do arquivo mais recente) e `dif_max` (maior diferença entre versões).
receita_mensal_a3 <- function(a3) {
  m <- a3[a3$tipo == "mensal", ]
  m$pub <- m$exercicio * 10L + m$periodo
  m <- m[order(m$cod_ibge, m$categoria, m$mes, m$pub), ]
  ch <- paste(m$cod_ibge, m$categoria, m$mes)
  ult <- m[!duplicated(ch, fromLast = TRUE), ]
  rng <- tapply(m$valor, ch, function(v) max(v) - min(v))
  nv <- tapply(m$valor, ch, length)
  ult$ch <- paste(ult$cod_ibge, ult$categoria, ult$mes)
  data.frame(cod_ibge = ult$cod_ibge, uf = ult$uf, categoria = ult$categoria, mes = ult$mes, valor = ult$valor,
             versoes = as.integer(nv[ult$ch]), dif_max = as.numeric(rng[ult$ch]), publicado_em = ult$pub)
}
