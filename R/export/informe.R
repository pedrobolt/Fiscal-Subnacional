# E6.2: planilha e texto do informe, gerados so de outputs/rodada/<data>/ e do arquivo de previsoes (docs/proposta_e62_e5_fase2.md, secao 1).
# Nenhuma celula digitada; unico campo livre: "comentario do analista" (vazio). A aba "Sinais" e INTERNA (uso interno, nao publicar) e vai em arquivo separado (informe_interno.xlsx): nao entra no numero nem no texto.
# Entrada: lista `I` montada pela etapa "informe" da rodada (ver `scripts/rodada_mensal_corpo.R`). Todas as funcoes abaixo sao puras (sem leitura de disco), exceto `escrever_informe()`.

MESES_PT <- c("janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro")
NOTA_CONCEITO <- "Receitas e despesas no conceito consolidado dos estados: incluem as fontes do RPPS e excluem as operações intraorçamentárias. O informe anterior usava o conceito sem RPPS e excluía RJ, PR e RS."
NOTA_BCB <- "No conceito do Banco Central."
#' Rotulo unico das esferas em todas as abas (chaves internas: regional/estaduais/municipais).
ROT_ESFERA <- c(regional = "regionais", estaduais = "estados", municipais = "municípios")
rot_esfera <- function(x) { r <- unname(ROT_ESFERA[as.character(x)]); ifelse(is.na(r), as.character(x), r) }

fmt_pt <- function(x, k = 1) formatC(x, format = "f", digits = k, decimal.mark = ",", big.mark = ".")
rs_bi <- function(x) sprintf("R$ %s %s", fmt_pt(abs(x)), if (round(abs(x), 1) < 2) "bilhão" else "bilhões")
.sinal_res <- function(x) ifelse(x >= 0, "superávit", "déficit")

#' Realizado de um ano (12 meses do SGS, R$ bi, superavit positivo); NA se o ano nao esta completo.
informe_realizado <- function(serie, ano) soma_meses(serie, ano, 1:12)

#' Acumulado jan..m de um ano.
informe_acum <- function(serie, ano, m) soma_meses(serie, ano, seq_len(m))

# ---- campos dos 5 blocos do gabarito ----------------------------------------------------------------------------------------------

#' Campos numericos do texto, todos lidos da entrada `I` (nada digitado). Retorna lista nomeada.
informe_campos <- function(I) {
  ano <- I$corte$ano_alvo; m <- I$corte$m
  reg <- I$p1[I$p1$esfera == "regional", ]; pib <- I$pib
  C <- list(ano = ano, m = m, mes = MESES_PT[m])
  C$prev_reg <- reg$previsao_bi; C$pib_ano <- pib$pib_bi[pib$ano == ano]; C$pib_ant <- pib$pib_bi[pib$ano == ano - 1L]
  C$real_ant_reg <- informe_realizado(I$series$regional, ano - 1L)
  C$acum <- vapply(c("regional", "estaduais", "municipais"), function(e) informe_acum(I$series[[e]], ano, m), 0)
  C$acum_ant <- vapply(c("regional", "estaduais", "municipais"), function(e) informe_acum(I$series[[e]], ano - 1L, m), 0)
  C$var_acum <- C$acum - C$acum_ant
  p <- I$proj; C$proj <- !is.null(p) && nrow(p$cresc) > 0
  if (C$proj) {
    of <- p$cresc[p$cresc$conceito == "consolidado" & p$cresc$oficial, ]
    C$d <- of$cresc_real_pct[of$serie == "desp:total"]; C$r <- of$cresc_real_pct[of$serie == "rec:total"]
    C$mes_p2 <- MESES_PT[2L * p$corte]
    u <- p$uf; u <- u[(u$serie == "rec:total" & u$modelo == of$modelo[of$serie == "rec:total"]) | (u$serie == "desp:total" & u$modelo == of$modelo[of$serie == "desp:total"]), ]
    u <- u[is.finite(u$Areal_ant) & u$Areal_ant > 0, ]; u$g <- u$Areal / u$Areal_ant - 1
    w <- merge(u[u$serie == "desp:total", c("cod_ibge", "g")], u[u$serie == "rec:total", c("cod_ibge", "g")], by = "cod_ibge", suffixes = c("_d", "_r"))
    C$n_ufs_desp_acima <- sum(w$g_d > w$g_r); C$n_ufs <- nrow(w)
  }
  C
}

#' Os 5 blocos do texto + notas. Blocos que dependem do E5 municipal/regional saem como "pendente". Retorna lista(blocos, notas, comentario).
informe_texto <- function(I) {
  C <- informe_campos(I); f <- fmt_pt
  # 1. manchete regional
  x <- C$prev_reg; x0 <- C$real_ant_reg
  verbo <- if (is.na(x0)) "" else if (sign(x) != sign(x0)) "revertendo" else if (abs(x) > abs(x0)) "ampliando" else "reduzindo"
  b1 <- sprintf("A CNI projeta que os governos regionais, que abarcam estados e municípios, registrem %s primário de %s (%s%% do PIB) em %d%s.", .sinal_res(x), rs_bi(x), f(100 * abs(x) / C$pib_ano), C$ano,
                if (is.na(x0)) "" else sprintf(", %s o %s de %s (%s%% do PIB) de %d", verbo, .sinal_res(x0), rs_bi(x0), f(100 * abs(x0) / C$pib_ant), C$ano - 1L))
  # 2. acumulado dos estados (BCB)
  a <- C$acum[["estaduais"]]; a0 <- C$acum_ant[["estaduais"]]
  if (sign(a) == sign(a0) || a == 0 || a0 == 0) b2 <- sprintf("No acumulado até %s, o %s dos estados %s de %s para %s na comparação com o mesmo período de %d.", C$mes, .sinal_res(a), if (a < a0) "recuou" else "subiu", rs_bi(a0), rs_bi(a), C$ano - 1L)
  else b2 <- sprintf("No acumulado até %s, o resultado dos estados passou de %s de %s para %s de %s na comparação com o mesmo período de %d.", C$mes, .sinal_res(a0), rs_bi(a0), .sinal_res(a), rs_bi(a), C$ano - 1L)
  v <- C$var_acum; conc <- abs(v[["estaduais"]]) > abs(v[["municipais"]]) && sign(v[["estaduais"]]) == sign(v[["regional"]]) && v[["regional"]] != 0
  if (conc) b2 <- paste(b2, sprintf("A %s se concentra nos estados.", if (v[["regional"]] < 0) "piora" else "melhora"))
  # 3. estados (E5)
  if (C$proj) {
    d <- C$d; r <- C$r; rz <- if (r > 0 && d > 0) d / r else NA_real_
    # Diferenca em p.p. (nao razao): com RMSE de ~1,8 p.p. por serie e n = 4 a 6, a razao nao e robusta; o sinal da diferenca e.
    rel <- if (abs(d - r) <= 0.5) "em linha com o" else if (d > r) "acima do" else "abaixo do"
    b3 <- sprintf("As despesas primárias devem registrar %s real de %s%% em %d, %s %s projetado para a arrecadação (%s%%), diferença de %s p.p.[1] Até %s, as despesas primárias cresciam acima da arrecadação em %d das %d UFs.",
                  if (d >= 0) "expansão" else "queda", f(abs(d)), C$ano, rel, if (r >= 0) "crescimento" else "queda", f(r), f(abs(d - r)), C$mes_p2, C$n_ufs_desp_acima, C$n_ufs)
  } else b3 <- "Estados: pendente (projeção do E5 indisponível nesta rodada)."
  b4 <- "Municípios: pendente (E5 municipal ainda não disponível)."
  b5 <- "Conjunto regional: pendente (depende do E5 municipal)."
  list(blocos = c(b1, b2, b3, b4, b5), notas = c(sprintf("[1] %s", NOTA_CONCEITO), "[2] (comentário do analista)", sprintf("[3] %s", NOTA_BCB)), comentario = "")
}

# ---- erro tipico (RMSE) do crescimento agregado, lido do backtest congelado -----------------------------------------------------------

#' Procura a linha do RMSE agregado (data/protocolo/e5_rmse_agregado.csv) para serie, corte, modelo (e membros do M5s4). NA se nao existe.
rmse_agregado <- function(rm, serie, corte, modelo, membros = "") {
  if (is.null(rm)) return(data.frame(rmse_pp = NA_real_, n_anos = NA_integer_, rmse_pp_sem_2020_21 = NA_real_, n_anos_sem_2020_21 = NA_integer_))
  k <- rm$serie == serie & rm$corte == corte & rm$modelo == modelo & (modelo != "M5s4" | rm$membros == membros)
  if (!any(k)) return(data.frame(rmse_pp = NA_real_, n_anos = NA_integer_, rmse_pp_sem_2020_21 = NA_real_, n_anos_sem_2020_21 = NA_integer_))
  rm[which(k)[1], c("rmse_pp", "n_anos", "rmse_pp_sem_2020_21", "n_anos_sem_2020_21")]
}

#' Aba "Crescimento projetado": uma linha por esfera x serie x conceito. Campos do E5 so para os estados; municipios e regionais "pendente".
informe_crescimento <- function(I) {
  p <- I$proj; rows <- list(); rot <- c("rec:total" = "receita primária", "desp:total" = "despesa primária")
  vazio <- function(e, s, c, st) data.frame(esfera = e, serie = rot[[s]], conceito = c, modelo = NA_character_, acumulado_real_pct = NA_real_, projetado_real_pct = NA_real_, rmse_pp = NA_real_, n_anos_rmse = NA_integer_,
                                            rmse_pp_sem_2020_21 = NA_real_, n_anos_rmse_sem_2020_21 = NA_integer_, status = st, stringsAsFactors = FALSE)
  if (!is.null(p) && nrow(p$cresc)) for (cn in unique(p$cresc$conceito)) for (s in c("rec:total", "desp:total")) {
    x <- p$cresc[p$cresc$conceito == cn & p$cresc$serie == s & p$cresc$oficial & !grepl("^prev_", p$cresc$modelo), ]
    if (!nrow(x)) next
    pl <- p$plano[p$plano$serie == s & p$plano$modelo == x$modelo[1], ]; rm <- rmse_agregado(I$rmse, s, p$corte, x$modelo[1], if (nrow(pl)) pl$membros[1] else "")
    rows[[length(rows) + 1]] <- data.frame(esfera = "estados", serie = rot[[s]], conceito = if (cn == "consolidado") "consolidado (com RPPS, sem intra; série do informe)" else "sensibilidade: sem RPPS, sem PR e RS (não é o conceito do informe)",
      modelo = x$modelo[1], acumulado_real_pct = x$acum_real_pct, projetado_real_pct = x$cresc_real_pct, rmse_pp = rm$rmse_pp, n_anos_rmse = rm$n_anos, rmse_pp_sem_2020_21 = rm$rmse_pp_sem_2020_21, n_anos_rmse_sem_2020_21 = rm$n_anos_sem_2020_21,
      status = if (cn == "consolidado") "oficial" else "sensibilidade", stringsAsFactors = FALSE)
  } else for (s in c("rec:total", "desp:total")) rows[[length(rows) + 1]] <- vazio("estados", s, "consolidado", "pendente")
  for (s in c("rec:total", "desp:total")) {
    for (cn in c("sem RPPS bruta", "harmonizada pelo RGF")) rows[[length(rows) + 1]] <- vazio("estados", s, paste("sensibilidade:", cn), "pendente (não implementada)")
    for (e in c("municípios", "regionais")) rows[[length(rows) + 1]] <- vazio(e, s, "consolidado", "pendente")
  }
  out <- do.call(rbind, rows); rownames(out) <- NULL; out
}

# ---- abas -------------------------------------------------------------------------------------------------------------------------------

informe_carimbo <- function(I) {
  data.frame(campo = c("Data da rodada", "Status", "Commit", "Corte m (P1)", "Último dado do BCB", "Bimestre de referência (alertas)", "Versão das premissas", "Fonte das premissas", "Tipo de rodada"),
    valor = c(I$dia, I$status, I$commit, as.character(I$corte$m), format(I$corte$ultimo), if (!is.null(I$bim_ref)) sprintf("%d b%d", I$bim_ref[[1]], I$bim_ref[[2]]) else "-",
              if (!is.null(I$prem)) I$prem$versao else "ausente", if (!is.null(I$prem)) I$prem$fonte else "-", if (I$oficial) "OFICIAL" else "RODADA DE TESTE (não oficial)"), stringsAsFactors = FALSE)
}

informe_esferas <- function(I) {
  C <- informe_campos(I); p <- I$p1; e <- ROT_ESFERA
  data.frame(esfera = e[p$esfera], ano_alvo = p$ano_alvo, previsao_bi = p$previsao_bi, pct_pib = 100 * p$previsao_bi / C$pib_ano,
             realizado_ano_anterior_bi = vapply(p$esfera, function(s) informe_realizado(I$series[[s]], C$ano - 1L), 0), faixa_inf_bi = ifelse(p$esfera == "regional", p$faixa_intervalo_inf, NA_real_),
             faixa_sup_bi = ifelse(p$esfera == "regional", p$faixa_intervalo_sup, NA_real_), stringsAsFactors = FALSE, row.names = NULL)
}

informe_p1 <- function(I) {
  C <- informe_campos(I); p <- I$p1; e <- ROT_ESFERA
  d <- data.frame(esfera = e[p$esfera], ano_alvo = p$ano_alvo, corte_m = p$corte_m, acumulado_bi = vapply(p$esfera, function(s) informe_acum(I$series[[s]], C$ano, C$m), 0),
                  acumulado_ano_anterior_bi = vapply(p$esfera, function(s) informe_acum(I$series[[s]], C$ano - 1L, C$m), 0), restante_ano_anterior_bi = p$restante_ano_anterior_bi, previsao_bi = p$previsao_bi, previsao_pct_pib = 100 * p$previsao_bi / C$pib_ano,
                  faixa_inf_bi = ifelse(p$esfera == "regional", p$faixa_intervalo_inf, NA_real_), faixa_sup_bi = ifelse(p$esfera == "regional", p$faixa_intervalo_sup, NA_real_), stringsAsFactors = FALSE, row.names = NULL)
  d$variacao_acumulado_bi <- d$acumulado_bi - d$acumulado_ano_anterior_bi
  d <- d[, c("esfera", "ano_alvo", "corte_m", "acumulado_bi", "acumulado_ano_anterior_bi", "variacao_acumulado_bi", "restante_ano_anterior_bi", "previsao_bi", "previsao_pct_pib", "faixa_inf_bi", "faixa_sup_bi")]
  lin <- p$dif_regional_vs_soma_bi[p$esfera == "regional"]
  list(tabela = d, linearidade_bi = lin, cobertura = I$txt_cob, historico = informe_historico_p1(I$arquivo))
}

#' Historico de previsoes emitidas (so o P1 oficial, SRW por esfera) a partir do arquivo de previsoes.
informe_historico_p1 <- function(arq) {
  if (is.null(arq) || !nrow(arq)) return(NULL)
  h <- arq[arq$modelo == "srw_brl" & arq$esfera %in% c("regional", "estaduais", "municipais") & arq$oficial %in% c(TRUE, "TRUE"), c("data_rodada", "esfera", "ano_alvo", "corte_m", "previsao_bi", "status_rodada")]
  h <- h[order(h$data_rodada, h$esfera), ]; h$esfera <- rot_esfera(h$esfera); rownames(h) <- NULL; h
}

#' P2 estados por categoria: bimestre e acumulado, variacao real (IPCA bimestral) e nominal contra o mesmo periodo do ano anterior.
#' `cat`: p2_categorias_bim(); `ind`: funcao ind(ano, bimestre) (e5_ipca_bim). Acumulado so ate o ultimo bimestre completo (n_ufs = 27) de t.
informe_p2 <- function(cat, ind = NULL, ano) {
  d <- cat; d$var_nominal_pct <- d$var_pct
  d$var_real_pct <- if (is.null(ind)) NA_real_ else 100 * ((1 + d$var_pct / 100) / (ind(d$exercicio, d$periodo) / ind(d$exercicio - 1L, d$periodo)) - 1)
  d$periodo <- as.character(d$periodo)
  b <- d[d$exercicio == ano & !is.na(d$valor_bi), ]; ult <- if (nrow(b)) max(as.integer(b$periodo)) else 0L
  ac <- NULL
  if (ult > 0) {
    cur <- cat[cat$exercicio == ano & cat$periodo <= ult, ]; ant <- cat[cat$exercicio == ano - 1L & cat$periodo <= ult, ]
    ac <- do.call(rbind, lapply(intersect(unique(cur$serie), unique(ant$serie)), function(s) {
      c1 <- cur[cur$serie == s, ]; a1 <- ant[ant$serie == s, ]
      if (nrow(c1) < ult || nrow(a1) < ult || anyNA(c1$valor_bi) || anyNA(a1$valor_bi)) return(NULL)
      real <- function(x, a) sum(x$valor_bi / vapply(x$periodo, function(p) if (is.null(ind)) 1 else ind(a, p), 0))
      data.frame(exercicio = ano, periodo = sprintf("acum. até b%d", ult), serie = s, valor_bi = sum(c1$valor_bi), n_ufs = min(c1$n_ufs), mesmo_bim_ano_ant_bi = sum(a1$valor_bi), var_pct = 100 * (sum(c1$valor_bi) / sum(a1$valor_bi) - 1),
                 var_nominal_pct = 100 * (sum(c1$valor_bi) / sum(a1$valor_bi) - 1), var_real_pct = if (is.null(ind)) NA_real_ else 100 * (real(c1, ano) / real(a1, ano - 1L) - 1), stringsAsFactors = FALSE)
    }))
  }
  d <- d[order(d$exercicio, d$periodo, d$serie), ]; if (!is.null(ac)) d <- rbind(d, ac)
  d$var_pct <- NULL; names(d)[names(d) == "mesmo_bim_ano_ant_bi"] <- "mesmo_periodo_ano_ant_bi"; d
}

informe_alertas <- function(I) list(lista = I$alertas_lista, contagem = I$alertas_contagem)

informe_notas <- function(I) {
  c("DEFINIÇÕES", "P1 = resultado primário no conceito do Banco Central (SGS 4642, 4643, 4644; superávit positivo), previsto pelo SRW em R$ (acumulado até o corte + restante do ano anterior). É o número do informe.",
    "P2 = receitas, despesas e resultado primário no conceito RREO/Siconfi (estados). P1 e P2 nunca aparecem lado a lado sem rótulo.",
    "Crescimento real projetado (E5): razão restante/acumulado no corte; modelo adotado por série e faixa (data/protocolo/e5_adocao.csv). Deflator: IPCA SGS 433 período a período; para os meses não realizados, o IPCA anual das premissas distribuído uniformemente.",
    "RMSE do crescimento: erro típico agregado (p.p. do crescimento real do total dos estados) do modelo adotado no mesmo corte, nos anos-alvo do backtest do E5 (amostra A), com e sem 2020-21 (data/protocolo/e5_rmse_agregado.csv). Poucos anos: ver a coluna n.",
    "VERSÕES", sprintf("Rodada %s; commit %s; premissas %s.", I$dia, I$commit, if (!is.null(I$prem)) I$prem$versao else "ausente"),
    "QUEBRAS E TRATAMENTOS", "Série do informe: conceito consolidado (com RPPS, sem intraorçamentárias de 2023 em diante). A sensibilidade sem RPPS exclui PR e RS; a quebra de pessoal de RJ, PR e RS existe só na série sem RPPS (docs/nota_quebras.md).",
    "LIMITES", "Municípios e conjunto regional do E5: pendentes (carga municipal em andamento). A classe do gap governa só a narrativa. Faixa do P1 regional: não é intervalo de 80%.", sprintf("[1] %s", NOTA_CONCEITO), sprintf("[3] %s", NOTA_BCB))
}

# ---- gravacao ---------------------------------------------------------------------------------------------------------------------------

.bloco <- function(wb, aba, linha, titulo, d, estilo_t, estilo_h) {
  openxlsx::writeData(wb, aba, titulo, startRow = linha, startCol = 1); openxlsx::addStyle(wb, aba, estilo_t, rows = linha, cols = 1)
  if (is.null(d) || !NROW(d)) { openxlsx::writeData(wb, aba, "(sem dados nesta rodada)", startRow = linha + 1, startCol = 1); return(linha + 3L) }
  openxlsx::writeData(wb, aba, d, startRow = linha + 1, startCol = 1); openxlsx::addStyle(wb, aba, estilo_h, rows = linha + 1, cols = seq_len(ncol(d)), gridExpand = TRUE)
  linha + NROW(d) + 3L
}

#' Monta o texto e a planilha e grava em `arq_xlsx` e `arq_md`. Retorna lista(texto, abas).
escrever_informe <- function(I, arq_xlsx, arq_md, arq_interno = NULL) {
  stopifnot(requireNamespace("openxlsx", quietly = TRUE))
  T <- informe_texto(I); S <- sinais_tudo(I); P1 <- informe_p1(I); CR <- informe_crescimento(I)
  wb <- openxlsx::createWorkbook(); st_t <- openxlsx::createStyle(textDecoration = "bold", fontSize = 12); st_h <- openxlsx::createStyle(textDecoration = "bold", fgFill = "#DDE6F0", border = "bottom")
  st_a <- openxlsx::createStyle(textDecoration = "bold", fontColour = "#FFFFFF", fgFill = "#B00020", fontSize = 12)
  add <- function(nome) { openxlsx::addWorksheet(wb, nome); openxlsx::setColWidths(wb, nome, cols = 1:14, widths = "auto"); nome }
  # Resumo
  a <- add("Resumo"); l <- 1L
  if (!I$oficial) { openxlsx::writeData(wb, a, "RODADA DE TESTE (não oficial)", startRow = 1, startCol = 1); openxlsx::addStyle(wb, a, st_a, rows = 1, cols = 1:6, gridExpand = TRUE); l <- 3L }
  l <- .bloco(wb, a, l, "Carimbo", informe_carimbo(I), st_t, st_h)
  l <- .bloco(wb, a, l, "Manchete regional", data.frame(texto = T$blocos[1], faixa_cobertura = if (is.na(I$txt_cob)) "-" else I$txt_cob, stringsAsFactors = FALSE), st_t, st_h)
  l <- .bloco(wb, a, l, "Quadro por esfera (P1, SRW em R$ bi; resultado no conceito do Banco Central)", informe_esferas(I), st_t, st_h)
  l <- .bloco(wb, a, l, "Crescimento real projetado (E5) com erro típico do modelo no mesmo corte (RMSE em p.p. do crescimento do total dos estados)", CR[, c("esfera", "serie", "conceito", "modelo", "projetado_real_pct", "rmse_pp", "n_anos_rmse", "rmse_pp_sem_2020_21", "n_anos_rmse_sem_2020_21", "status")], st_t, st_h)
  l <- .bloco(wb, a, l, "Alertas (contagem)", I$alertas_contagem, st_t, st_h)
  l <- .bloco(wb, a, l, "Comentário do analista (campo livre; vazio por padrão)", data.frame(comentario = ""), st_t, st_h)
  # P1
  a <- add("P1"); l <- .bloco(wb, a, 1L, "P1 por esfera (R$ bi; superávit positivo)", P1$tabela, st_t, st_h)
  l <- .bloco(wb, a, l, "Checagem de linearidade (SRW regional - (estados + municípios), R$ bi)", data.frame(valor_bi = P1$linearidade_bi), st_t, st_h)
  l <- .bloco(wb, a, l, "Cobertura da faixa do regional", data.frame(texto = if (is.na(P1$cobertura)) "-" else P1$cobertura), st_t, st_h)
  l <- .bloco(wb, a, l, "Histórico de previsões emitidas (SRW oficial)", P1$historico, st_t, st_h)
  # Crescimento projetado
  a <- add("Crescimento projetado"); l <- .bloco(wb, a, 1L, "Acumulado real até o bimestre e projetado no ano (E5); RMSE = erro típico agregado do modelo adotado no mesmo corte, backtest do E5 (amostra A)", CR, st_t, st_h)
  # P2 estados
  a <- add("P2 estados"); l <- .bloco(wb, a, 1L, "P2 por categoria (R$ bi; variação real por IPCA bimestral e nominal contra o mesmo período do ano anterior)", I$p2_cat, st_t, st_h)
  l <- .bloco(wb, a, l, "Resultado primário (R$ bi): consolidado (oficial), bruto com intra e sem RPPS (referência da LDO, 2023+)", I$p2_tot, st_t, st_h)
  # Gap
  a <- add("Gap"); l <- .bloco(wb, a, 1L, "Gap P2 - P1 dos estados, por bimestre (R$ bi e % da receita). A classe governa só a narrativa.", I$gap, st_t, st_h)
  # Alertas
  a <- add("Alertas"); l <- .bloco(wb, a, 1L, "Lista (grupo 'ultimo' primeiro, depois 'revisao')", I$alertas_lista, st_t, st_h); l <- .bloco(wb, a, l, "Contagem por tipo", I$alertas_contagem, st_t, st_h)
  # Notas
  a <- add("Notas"); openxlsx::writeData(wb, a, data.frame(notas = informe_notas(I)), startRow = 1, startCol = 1); openxlsx::addStyle(wb, a, st_h, rows = 1, cols = 1)
  dir.create(dirname(arq_xlsx), showWarnings = FALSE, recursive = TRUE); openxlsx::saveWorkbook(wb, arq_xlsx, overwrite = TRUE)
  if (!is.null(arq_interno)) {          # arquivo SEPARADO: rotulo nao impede encaminhamento, arquivo separado impede
    wb <- openxlsx::createWorkbook()
    a <- add("Carimbo"); openxlsx::writeData(wb, a, "USO INTERNO, NÃO PUBLICAR. Não entra no número nem no texto do informe.", startRow = 1, startCol = 1); openxlsx::addStyle(wb, a, st_a, rows = 1, cols = 1:6, gridExpand = TRUE)
    .bloco(wb, a, 3L, "Carimbo da rodada", informe_carimbo(I), st_t, st_h)
    # Sinais
    a <- add("Sinais"); openxlsx::writeData(wb, a, "USO INTERNO, NÃO PUBLICAR. Não entra no número nem no texto do informe.", startRow = 1, startCol = 1); openxlsx::addStyle(wb, a, st_a, rows = 1, cols = 1:8, gridExpand = TRUE)
    l <- .bloco(wb, a, 3L, "m3 (sombra) por esfera ao lado do SRW (R$ bi); o m3 usa o PIB das premissas", S$m3, st_t, st_h)
    l <- .bloco(wb, a, l, "Candidatos do torneio do P1 no corte atual (R$ bi): previsão por esfera e RMSE relativo ao SRW na faixa do corte (nota_p1; + = pior que o SRW). Só informação; o número do informe é o SRW", S$candidatos, st_t, st_h)
    l <- .bloco(wb, a, l, "Gap implícito P2 projetado - P1 dos estados (R$ bi), classe pela regra do E3.6 adaptada ao horizonte anual", if (!is.null(S$gap)) S$gap$resumo else NULL, st_t, st_h)
    l <- .bloco(wb, a, l, "Decomposição: acumulado x hipótese do restante x diferença sazonal RREO-BCB do ano anterior (R$ bi)", if (!is.null(S$gap)) S$gap$decomposicao else NULL, st_t, st_h)
    l <- .bloco(wb, a, l, "Gap realizado anual (P2 por diferença - P1) usado como referência da classe", if (!is.null(S$gap)) S$gap$realizado else NULL, st_t, st_h)
    l <- .bloco(wb, a, l, sprintf("Erro histórico do SRW no mesmo corte (previsão - realizado, superávit positivo): anos de eleição estadual x demais%s", if (isTRUE(S$srw$ano_alvo_eleicao)) " (o ano-alvo é de eleição estadual)" else ""), S$srw$resumo, st_t, st_h)
    l <- .bloco(wb, a, l, "Anos de eleição estadual, por ano", S$srw$por_ano, st_t, st_h)
    dir.create(dirname(arq_interno), showWarnings = FALSE, recursive = TRUE); openxlsx::saveWorkbook(wb, arq_interno, overwrite = TRUE)
  }
  txt <- c(sprintf("# Informe: texto gerado pela rodada de %s%s", I$dia, if (I$oficial) "" else " (RODADA DE TESTE, não oficial)"), "", T$blocos, "", T$notas, "", "Comentário do analista: ")
  writeLines(txt, arq_md, useBytes = TRUE)
  invisible(list(texto = T, sinais = S, crescimento = CR))
}
