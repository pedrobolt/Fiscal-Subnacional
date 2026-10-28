# Atualização automática do Anexo 3 (RCL) e da DCA dos estados para a rodada mensal (E6.1): baixa o que ainda não existe e
# já está disponível; arquivo existente nunca é sobrescrito. Sem passo manual: a rodada chama esta função e depois
# `fatores_dca()`, que sempre usa o último fator disponível.
atualizar_a3_dca <- function(hoje = Sys.Date(), pasta_rreo = "data/raw/rreo", pasta_dca = "data/raw/dca") {
  entes <- ler_entes(baixar_entes(pasta_rreo, hoje))
  est <- listar_estados(entes); stopifnot(nrow(est) == 27)
  ano <- as.integer(format(hoje, "%Y"))
  a3 <- baixar_rreo_lote(est$cod_ibge, 2015:ano, anexos = c(anexo03 = "RREO-Anexo 03"), pasta = pasta_rreo, hoje = hoje)
  dca <- character(0)
  for (a in 2015:(ano - 1L)) for (id in est$cod_ibge) dca <- c(dca, baixar_dca(id, a, pasta_dca))   # exercício ainda sem DCA volta NA e é tentado de novo na rodada seguinte
  invisible(list(a3 = a3, dca = dca[!is.na(dca)]))
}
