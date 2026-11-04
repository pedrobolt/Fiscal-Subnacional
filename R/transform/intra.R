# Harmonizacao das intraorcamentarias (A6 de 2023 em diante). Ver docs/relatorio_intra.md e docs/intra_criterios.md.
# Ate 2022 o Anexo 6 nao inclui as contas intraorcamentarias na receita nem na despesa primaria; de 2023 inclui nas duas. A serie harmonizada
# (conceito consolidado e continuo) retira a intra do Anexo 1 de 2023 em diante. So a parcela PAGA de despesa esta no Anexo 1 (RP pagos de intra: Anexo 7).

#' Mapa serie do P2 -> conta intra do Anexo 1 e coluna acumulada (padrao ja com espacos normalizados).
INTRA_MAPA <- data.frame(
  serie = c("rec:demais receitas", "desp:pessoal", "desp:custeio", "desp:investimento", "desp:demais despesas de capital"),
  conta = c("ReceitasIntraOrcamentariasTotal", "PessoalEEncargosSociaisIntra", "OutrasDespesasCorrentesIntra", "InvestimentosIntra", "InversoesFinanceirasIntra"),
  lado = c("rec", "desp", "desp", "desp", "desp"),
  coluna = c("Até o Bimestre (c)", "DESPESAS PAGAS ATÉ O BIMESTRE (j)", "DESPESAS PAGAS ATÉ O BIMESTRE (j)", "DESPESAS PAGAS ATÉ O BIMESTRE (j)", "DESPESAS PAGAS ATÉ O BIMESTRE (j)"),
  stringsAsFactors = FALSE)
#' Series em que o mapeamento passou na validacao (docs/relatorio_intra.md, secao 2b): a retirada por categoria vale so nelas; as demais so no total.
INTRA_SERIES_VALIDADAS <- c("rec:demais receitas", "desp:pessoal")

#' Fluxo bimestral da intra por serie (Anexo 1, de `desde` em diante). `rreo`: saida de ler_rreo_pasta().
fluxo_intra <- function(rreo, desde = 2023L, mapa = INTRA_MAPA) {
  a1 <- rreo[rreo$anexo == "RREO-Anexo 01" & rreo$exercicio >= desde, ]
  a1$col <- gsub("\\s+", " ", a1$coluna)
  out <- lapply(seq_len(nrow(mapa)), function(i) {
    x <- a1[a1$cod_conta == mapa$conta[i] & a1$col == mapa$coluna[i], ]
    x <- x[!duplicated(x[, c("cod_ibge", "exercicio", "periodo")]), ]
    if (nrow(x) == 0) return(NULL)
    x <- x[order(x$cod_ibge, x$exercicio, x$periodo), c("cod_ibge", "exercicio", "periodo", "valor")]
    x$serie <- mapa$serie[i]; x <- acumulado_para_fluxo(x, serie = c("cod_ibge", "serie"))
    x$lado <- mapa$lado[i]; x[, c("cod_ibge", "exercicio", "periodo", "serie", "lado", "fluxo")]
  })
  do.call(rbind, out)
}

#' Retira a intra das series validadas: `fl` (cod_ibge, serie, exercicio, periodo, valor); `intra`: fluxo_intra(). Guarda `valor_bruto`.
harmonizar_intra <- function(fl, intra, series = INTRA_SERIES_VALIDADAS) {
  i <- intra[intra$serie %in% series, c("cod_ibge", "exercicio", "periodo", "serie", "fluxo")]
  k <- match(paste(fl$cod_ibge, fl$exercicio, fl$periodo, fl$serie), paste(i$cod_ibge, i$exercicio, i$periodo, i$serie))
  fl$valor_bruto <- fl$valor
  aj <- ifelse(is.na(k), 0, i$fluxo[k])
  fl$valor <- fl$valor - ifelse(is.na(aj), 0, aj)
  fl
}

#' Total do lado ("rec" ou "desp") harmonizado: soma das series brutas menos TODA a intra do lado (nao so a das series validadas).
total_harmonizado <- function(fl, intra, lado) {
  x <- fl[grepl(paste0("^", lado, ":"), fl$serie), ]
  a <- aggregate(valor ~ cod_ibge + exercicio + periodo, x, sum); names(a)[4] <- "bruto"
  i <- aggregate(fluxo ~ cod_ibge + exercicio + periodo, intra[intra$lado == lado, ], sum)
  a <- merge(a, i, by = c("cod_ibge", "exercicio", "periodo"), all.x = TRUE); a$fluxo[is.na(a$fluxo)] <- 0
  a$harmonizado <- a$bruto - a$fluxo; names(a)[names(a) == "fluxo"] <- "intra"; a$lado <- lado
  a
}
