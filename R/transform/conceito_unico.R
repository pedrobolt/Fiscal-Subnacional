# Conceito único de receita e despesa do Anexo 6 dos estados. O Anexo 6 não trata igual, entre UFs e anos, a dedução do FUNDEB e a
# cota-parte dos municípios: em alguns UF-anos a receita vem líquida das duas, em outros bruta de uma ou das duas (e a despesa
# carrega o que não foi deduzido, em "outras despesas correntes"). O conceito único é receita líquida de FUNDEB e cota-parte,
# despesa sem esses repasses. O ajuste tira o mesmo valor da receita e da despesa, então o resultado primário não muda
# (a identidade é tautológica; a validação do ajuste está em `validar_conceito_unico()`).

IMPOSTOS_AJUSTE <- c("ICMS", "IPVA", "ITCD", "FPE")
CAT_A6_IMPOSTO <- c(RREO6ICMS = "ICMS", RREO6IPVA = "IPVA", RREO6ITCD = "ITCD", RREO6CotaParteDoFPE = "FPE", RREO6FPE = "FPE")

#' Que deduções o Anexo 6 já fez, por UF x ano x imposto, comparando o acumulado do 6º bimestre com as combinações da DCA.
#' `fatores`: fatores_dca(); `a6_anual`: cod_ibge, exercicio, categoria, a6_acum. Devolve fatores + ded_fundeb_a6, ded_transf_a6, conceito.
conceito_deducoes_a6 <- function(fatores, a6_anual, tol = 0.005) {
  f <- merge(fatores, a6_anual, by = c("cod_ibge", "exercicio", "categoria"))
  cand <- list(nenhuma = f$bruto - f$outras, fundeb = f$bruto - f$fundeb - f$outras, transf = f$bruto - f$transf - f$outras,
               ambas = f$bruto - f$fundeb - f$transf - f$outras)
  dif <- sapply(cand, function(v) abs(f$a6_acum - v) / f$bruto)
  # empate (deduções zeradas na DCA): vale a candidata com menos deduções
  melhor <- apply(dif, 1, function(r) { ok <- which(r <= tol); if (length(ok)) names(cand)[ok[1]] else "fora" })
  f$conceito <- melhor
  f$ded_fundeb_a6 <- f$conceito %in% c("fundeb", "ambas"); f$ded_transf_a6 <- f$conceito %in% c("transf", "ambas")
  f$ded_fundeb_a6[f$conceito == "fora"] <- NA; f$ded_transf_a6[f$conceito == "fora"] <- NA
  f
}

#' Parcelas medianas observadas (deduções/bruto) por imposto, para estimar o que a DCA não mostra.
parcelas_medianas <- function(fatores) {
  med <- function(x) { x <- x[is.finite(x) & x > 0]; if (length(x)) stats::median(x) else 0 }
  do.call(rbind, lapply(split(fatores, fatores$categoria), function(z)
    data.frame(categoria = z$categoria[1], sh_fundeb = med(z$sh_fundeb), sh_transf = med(z$sh_transf))))
}

#' Valor a retirar da receita e da despesa por UF x imposto x ano: o que o Anexo 6 não deduziu, vezes o bruto do ano.
#' Parcela usada: a observada na DCA do ano, se há; senão a mediana do imposto. `bruto_bim`: cod_ibge, categoria, exercicio, periodo, bruto.
ajuste_conceito_unico <- function(bruto_bim, conceito, medianas) {
  c1 <- conceito[, c("cod_ibge", "exercicio", "categoria", "sh_fundeb", "sh_transf", "ded_fundeb_a6", "ded_transf_a6", "conceito")]
  a <- merge(bruto_bim, c1, by = c("cod_ibge", "exercicio", "categoria"), all.x = TRUE)
  a <- merge(a, setNames(medianas, c("categoria", "med_fundeb", "med_transf")), by = "categoria", all.x = TRUE)
  usa <- function(obs, med) ifelse(is.finite(obs) & obs > 0, obs, med)
  a$ajuste <- ifelse(is.na(a$ded_fundeb_a6), NA_real_,
                     a$bruto * (ifelse(a$ded_fundeb_a6, 0, usa(a$sh_fundeb, a$med_fundeb)) + ifelse(a$ded_transf_a6, 0, usa(a$sh_transf, a$med_transf))))
  a$ajuste_nao_reconstruivel <- is.na(a$ajuste)
  a
}

#' Total do ajuste por UF x ano x bimestre (soma dos impostos) e marca de não reconstruível se algum imposto ficou de fora.
ajuste_total <- function(aj) {
  ch <- paste(aj$cod_ibge, aj$exercicio, aj$periodo)
  tot <- tapply(aj$ajuste, ch, function(v) sum(v, na.rm = TRUE))
  nr <- tapply(aj$ajuste_nao_reconstruivel, ch, any)
  p <- strsplit(names(tot), " ")
  data.frame(cod_ibge = as.integer(vapply(p, `[`, "", 1)), exercicio = as.integer(vapply(p, `[`, "", 2)), periodo = as.integer(vapply(p, `[`, "", 3)),
             ajuste_total = as.numeric(tot), nao_reconstruivel = as.logical(nr[names(tot)]), stringsAsFactors = FALSE)
}

#' Aplica o ajuste aos fluxos do Anexo 6. `fluxos`: cod_ibge, exercicio, periodo, rec_total, desp_total, desp_custeio (R$, bimestre).
#' Bimestre que não pode ser reconstruído (algum imposto fora de qualquer conceito) não é excluído: fica com o Anexo 6 sem ajuste e
#' `conceito_original = TRUE` (o primário é o mesmo). Flags automáticos, sem correção manual: `flag_custeio_nao_positivo`.
aplicar_conceito_unico <- function(fluxos, ajt) {
  x <- merge(fluxos, ajt, by = c("cod_ibge", "exercicio", "periodo"), all.x = TRUE)
  x$conceito_original <- is.na(x$ajuste_total) | x$nao_reconstruivel
  x$ajuste_aplicado <- ifelse(x$conceito_original, 0, x$ajuste_total)
  x$rec_unica <- x$rec_total - x$ajuste_aplicado
  x$desp_unica <- x$desp_total - x$ajuste_aplicado
  x$custeio_unico <- x$desp_custeio - x$ajuste_aplicado
  x$primario_a6 <- x$rec_total - x$desp_total
  x$primario_unico <- x$rec_unica - x$desp_unica
  x$flag_custeio_nao_positivo <- !x$conceito_original & !is.na(x$custeio_unico) & x$custeio_unico <= 0
  x
}

# Limite definido em 29/10/2026: o agregado é rotulado "parcial" se os bimestres UF em conceito original (sem ajuste) somam mais de
# 5% da receita total do agregado; abaixo disso, "completo" (com a lista de UFs em conceito original ao lado).
LIMITE_PARCIAL <- 0.05

#' Rótulo do agregado de um ano x bimestre: parcela da receita em conceito original e rótulo "completo"/"parcial".
rotular_agregado <- function(x, limite = LIMITE_PARCIAL) {
  out <- lapply(split(x, paste(x$exercicio, x$periodo)), function(z) {
    tot <- sum(z$rec_total, na.rm = TRUE)
    sh <- if (tot > 0) sum(z$rec_total[z$conceito_original], na.rm = TRUE) / tot else NA_real_
    data.frame(exercicio = z$exercicio[1], periodo = z$periodo[1], ufs = nrow(z), ufs_conceito_original = sum(z$conceito_original),
               parcela_receita_original = sh, rotulo = ifelse(is.na(sh) || sh > limite, "parcial", "completo"), stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, out); out[order(out$exercicio, out$periodo), ]
}

#' Testes que validam o ajuste (a identidade da receita menos despesa é tautológica):
#' (1) "custeio" (outras despesas correntes) reconstruído deve ser positivo; lista UF x ano x bimestre que violam;
#' (2) não pode haver quebra na troca de regime: razão anual custeio/receita no 6º bimestre; na troca (conceito do ano muda) a variação
#'     da razão reconstruída não pode superar o percentil `p` das variações nos anos sem troca. Lista as trocas que violam.
validar_conceito_unico <- function(x, conceito, p = 0.9) {
  viol_pos <- x[!is.na(x$custeio_unico) & x$custeio_unico <= 0 & !x$conceito_original, c("cod_ibge", "exercicio", "periodo", "desp_custeio", "ajuste_total", "custeio_unico")]
  a <- x[x$periodo == 6 & !x$conceito_original & is.finite(x$custeio_unico) & x$rec_unica > 0, ]
  a$r_unica <- a$custeio_unico / a$rec_unica; a$r_a6 <- a$desp_custeio / a$rec_total
  cc <- unique(conceito[, c("cod_ibge", "exercicio", "categoria", "conceito")])
  chave <- tapply(cc$conceito, paste(cc$cod_ibge, cc$exercicio), function(v) paste(sort(v), collapse = "+"))
  a <- a[order(a$cod_ibge, a$exercicio), ]
  a$chave_conceito <- unname(chave[paste(a$cod_ibge, a$exercicio)])
  ant <- c(NA, seq_len(nrow(a) - 1L)); ant[c(TRUE, a$cod_ibge[-1] != a$cod_ibge[-nrow(a)])] <- NA
  a$d_unica <- abs(a$r_unica - a$r_unica[ant]); a$d_a6 <- abs(a$r_a6 - a$r_a6[ant])
  a$troca <- !is.na(ant) & a$exercicio - a$exercicio[ant] == 1L & a$chave_conceito != a$chave_conceito[ant]
  lim <- stats::quantile(a$d_unica[!a$troca & !is.na(a$d_unica)], p, na.rm = TRUE)
  trocas <- a[a$troca, c("cod_ibge", "exercicio", "chave_conceito", "r_a6", "r_unica", "d_a6", "d_unica")]
  trocas$limite <- as.numeric(lim); trocas$viola <- trocas$d_unica > lim
  trocas$melhora_vs_a6 <- trocas$d_unica < trocas$d_a6
  list(positividade = viol_pos, trocas = trocas, limite = as.numeric(lim))
}

#' Fluxos bimestrais do Anexo 6 (soma das folhas, pelo dicionário): receita total e despesa em caixa (total e "custeio"), mais o
#' acumulado do 6º bimestre por imposto (para classificar o conceito). Despesa em caixa só de 2018 em diante.
fluxos_a6_conceito <- function(rreo, dic_contas, dic_colunas) {
  d <- aplicar_dicionario(rreo[rreo$anexo == "RREO-Anexo 06", ], dic_contas, dic_colunas)
  d <- d[!is.na(d$papel_conta), ]
  d$chave <- paste(d$cod_ibge, d$exercicio, d$periodo)
  corrente <- d$ano_rel %in% c("corrente", "nao_se_aplica")
  rec <- d[d$papel_coluna %in% "receita_p2" & corrente & d$papel_conta == "rec_folha", ]
  rec <- rec[!duplicated(rec[, c("chave", "cod_conta", "coluna")]), ]
  dsp <- d[d$papel_coluna %in% "despesa_caixa_p2" & d$papel_conta == "desp_folha", ]
  dsp <- dsp[!duplicated(dsp[, c("chave", "cod_conta", "estagio", "coluna")]), ]
  agr <- function(x, serie, filtro = TRUE) {
    y <- x[filtro, ]
    if (!NROW(y)) return(NULL)
    s <- aggregate(valor ~ cod_ibge + exercicio + periodo, y, sum); s$serie <- serie; s
  }
  long <- rbind(agr(rec, "rec_total"), agr(dsp, "desp_total"), agr(dsp, "desp_custeio", dsp$categoria_p2 %in% "custeio"))
  long <- acumulado_para_fluxo(long, serie = c("cod_ibge", "serie"), valor = "valor")
  long$fluxo[long$acum_anterior_ausente] <- NA_real_
  fl <- stats::reshape(long[, c("cod_ibge", "exercicio", "periodo", "serie", "fluxo")], idvar = c("cod_ibge", "exercicio", "periodo"), timevar = "serie", direction = "wide")
  names(fl) <- sub("^fluxo\\.", "", names(fl))
  imp <- rec <- d[d$papel_coluna %in% "receita_p2" & corrente & d$cod_conta %in% names(CAT_A6_IMPOSTO) & d$periodo == 6, ]
  imp$categoria <- unname(CAT_A6_IMPOSTO[imp$cod_conta])
  imp <- imp[!duplicated(imp[, c("cod_ibge", "exercicio", "categoria")]), c("cod_ibge", "exercicio", "categoria", "valor")]
  names(imp)[4] <- "a6_acum"
  # fluxo bimestral por imposto (acumulado -> fluxo), para a continuidade do imposto líquido reconstruído
  ri <- d[d$papel_coluna %in% "receita_p2" & corrente & d$cod_conta %in% names(CAT_A6_IMPOSTO), ]
  ri$categoria <- unname(CAT_A6_IMPOSTO[ri$cod_conta])
  ri <- ri[!duplicated(ri[, c("cod_ibge", "exercicio", "periodo", "categoria")]), c("cod_ibge", "exercicio", "periodo", "categoria", "valor")]
  ri <- acumulado_para_fluxo(ri, serie = c("cod_ibge", "categoria"), valor = "valor")
  ri$fluxo[ri$acum_anterior_ausente] <- NA_real_
  fi <- ri[, c("cod_ibge", "exercicio", "periodo", "categoria", "fluxo")]; names(fi)[5] <- "a6_fluxo"
  list(fluxos = fl, a6_anual = imp, fluxo_imposto = fi)
}

# Limite definido em 29/10/2026: a razão (receita líquida reconstruída do imposto) / (bruto do Anexo 3 calibrado) é constante se o
# ajuste está certo; variação anual acima de 2 pontos percentuais da razão é quebra (alerta, não bloqueia).
LIMITE_CONTINUIDADE <- 0.02

#' Continuidade do imposto líquido reconstruído por UF x imposto x ano: razão anual líquida/bruto, variação anual e se o conceito
#' do Anexo 6 mudou na virada. `fluxo_imposto`: cod_ibge, exercicio, periodo, categoria, a6_fluxo; `aj`: saída de ajuste_conceito_unico().
continuidade_imposto <- function(fluxo_imposto, aj, limite = LIMITE_CONTINUIDADE) {
  m <- merge(fluxo_imposto, aj[, c("cod_ibge", "exercicio", "periodo", "categoria", "bruto", "ajuste", "conceito")],
             by = c("cod_ibge", "exercicio", "periodo", "categoria"))
  m <- m[is.finite(m$ajuste) & is.finite(m$a6_fluxo) & m$bruto > 0, ]
  m$liq <- m$a6_fluxo - m$ajuste
  a <- aggregate(cbind(liq, bruto) ~ cod_ibge + categoria + exercicio, m, sum)
  cc <- unique(m[, c("cod_ibge", "categoria", "exercicio", "conceito")]); a <- merge(a, cc[!duplicated(cc[, 1:3]), ], by = c("cod_ibge", "categoria", "exercicio"))
  a$razao <- a$liq / a$bruto
  a <- a[order(a$cod_ibge, a$categoria, a$exercicio), ]
  ch <- paste(a$cod_ibge, a$categoria); ant <- c(NA, seq_len(nrow(a) - 1L)); ant[c(TRUE, ch[-1] != ch[-nrow(a)])] <- NA
  a$ano_anterior_consecutivo <- !is.na(ant) & a$exercicio - a$exercicio[ant] == 1L
  a$delta <- ifelse(a$ano_anterior_consecutivo, a$razao - a$razao[ant], NA_real_)
  a$troca_conceito <- a$ano_anterior_consecutivo & a$conceito != a$conceito[ant]
  a$quebra <- !is.na(a$delta) & abs(a$delta) > limite
  a
}
