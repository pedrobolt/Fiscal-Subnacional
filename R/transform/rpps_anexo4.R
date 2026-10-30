# Fluxo liquido do RPPS dos estados pelo RREO Anexo 4 (receitas e despesas previdenciarias), 6o bimestre = acumulado do ano (E3.6, teste do RPPS).
# Liquido = (receitas realizadas - despesas liquidadas) dos dois planos do RPPS: Fundo em Reparticao (financeiro) e Fundo em Capitalizacao
# (previdenciario). Fora: Administracao do RPPS, beneficios mantidos pelo Tesouro, militares e aportes do Tesouro (nao entram nas receitas).
# `aportes` = linhas "Aportes para ..." (coluna APORTES REALIZADOS): transferencias do Tesouro; `liquido_consolidado` = liquido + aportes.
# Variante "sem rendimentos": tira as receitas de valores mobiliarios (retorno financeiro, nao primario).

RPPS_A4_CONTAS <- c(rec_fin = "TotalReceitasRPPSFinanceiro", rec_prev = "TotalReceitasRPPSPrevidenciario",
                    desp_fin = "TotalDasDespesasRPPSFinanceiro", desp_prev = "TotalDasDespesasRPPSPrevidenciario",
                    vm_fin = "ReceitasDeValoresMobiliariosPrevidenciariasBrutasFinanceiro", vm_prev = "ReceitasDeValoresMobiliariosPrevidenciariasBrutasPrevidenciario")

#' Coluna certa por exercicio: ate 2020 "Ate o Bimestre / <ano>" (receita) e "DESPESAS LIQUIDADAS ATE O BIMESTRE / <ano>"; de 2021 em diante
#' "RECEITAS REALIZADAS ATE O BIMESTRE (b)", "(e)" liquidada e "(f)" paga. ASCII: regex sem acento (C locale).
coluna_a4 <- function(coluna, exercicio, tipo = c("receita", "liquidada", "paga")) {
  tipo <- match.arg(tipo)
  u <- toupper(iconv(enc2utf8(coluna), "UTF-8", "ASCII", sub = ""))   # acentos somem: "ATE" vira "AT"
  if (exercicio <= 2020) {
    if (tipo == "receita") return(grepl(paste0("^AT O BIMESTRE / ", exercicio, "$"), u))
    if (tipo == "liquidada") return(grepl(paste0("^DESPESAS LIQUIDADAS AT O BIMESTRE / ", exercicio, "$"), u))
    return(rep(FALSE, length(u)))
  }
  switch(tipo, receita = grepl("^RECEITAS REALIZADAS AT O BIMESTRE", u), liquidada = grepl("^DESPESAS LIQUIDADAS AT O BIMESTRE", u),
         paga = grepl("^DESPESAS PAGAS AT O BIMESTRE", u))
}

#' `rreo`: saida de `ler_rreo_pasta()` (so o Anexo 4, 6o bimestre). Devolve, por UF x ano, receitas, despesas liquidadas/pagas e o liquido (R$).
rpps_liquido_a4 <- function(rreo) {
  a <- rreo[rreo$anexo == "RREO-Anexo 04" & rreo$periodo == 6L & rreo$cod_conta %in% RPPS_A4_CONTAS, ]
  if (!nrow(a)) return(data.frame())
  a <- a[order(a$cod_ibge, a$exercicio, a$cod_conta, a$coluna, a$baixado_em), ]
  a <- a[!duplicated(a[, c("cod_ibge", "exercicio", "cod_conta", "coluna")], fromLast = TRUE), ]
  pega <- function(conta, tipo) {
    x <- a[a$cod_conta == RPPS_A4_CONTAS[[conta]], ]
    if (!nrow(x)) return(setNames(numeric(0), character(0)))
    x <- x[unlist(mapply(function(co, ex) coluna_a4(co, ex, tipo), x$coluna, x$exercicio)), ]
    setNames(x$valor, paste(x$cod_ibge, x$exercicio))
  }
  chaves <- sort(unique(paste(a$cod_ibge, a$exercicio)))
  g <- function(v) { z <- v[chaves]; names(z) <- chaves; z }
  s <- function(...) { m <- cbind(...); ifelse(rowSums(!is.na(m)) == 0, NA_real_, rowSums(m, na.rm = TRUE)) }
  rec <- s(g(pega("rec_fin", "receita")), g(pega("rec_prev", "receita")))
  dl <- s(g(pega("desp_fin", "liquidada")), g(pega("desp_prev", "liquidada")))
  dp <- s(g(pega("desp_fin", "paga")), g(pega("desp_prev", "paga")))
  vm <- s(g(pega("vm_fin", "receita")), g(pega("vm_prev", "receita")))
  ap <- rreo[rreo$anexo == "RREO-Anexo 04" & rreo$periodo == 6L & grepl("^AportesPara", rreo$cod_conta) &
               grepl("^APORTES REALIZADOS$", toupper(iconv(enc2utf8(rreo$coluna), "UTF-8", "ASCII", sub = ""))), ]
  ap <- ap[order(ap$cod_ibge, ap$exercicio, ap$cod_conta, ap$baixado_em), ]
  ap <- ap[!duplicated(ap[, c("cod_ibge", "exercicio", "cod_conta")], fromLast = TRUE), ]
  ap_v <- tapply(ap$valor, paste(ap$cod_ibge, ap$exercicio), sum, na.rm = TRUE)
  aportes <- unname(ap_v[chaves]); aportes[is.na(aportes)] <- 0
  p <- strsplit(chaves, " ")
  d <- data.frame(cod_ibge = as.integer(sapply(p, `[`, 1)), exercicio = as.integer(sapply(p, `[`, 2)), rec = rec, desp_liquidada = dl, desp_paga = dp, rendimentos = vm, aportes = aportes)
  d$liquido <- d$rec - d$desp_liquidada; d$liquido_pago <- d$rec - d$desp_paga
  d$liquido_consolidado <- d$liquido + d$aportes     # aportes do Tesouro ao RPPS cancelam na consolidacao
  d$liquido_sem_rendimentos <- d$liquido - ifelse(is.na(d$rendimentos), 0, d$rendimentos)
  d
}
