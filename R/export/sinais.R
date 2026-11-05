# Aba INTERNA "Sinais" do E6.2 (pedido de 05/11/2026): serve para redigir o texto; NAO entra no numero nem no gabarito. Descritivo, nao muda modelos.
# Conteudo: (1) m3 sombra por esfera ao lado do SRW; (2) gap implicito P2 projetado - P1 dos estados, classe pela regra do E3.6 (adaptada ao horizonte anual) e decomposicao
# (acumulado x hipotese do restante x diferenca sazonal RREO-BCB do ano anterior); (3) erro historico do SRW no mesmo corte em anos de eleicao estadual x demais.

#' m3 por esfera (regional; componentes estadual e municipal do E4.1) com o SRW ao lado. `series`: lista regional/estaduais/municipais (data, valor_bi); `pib`: data.frame(ano, pib_bi) com o ano-alvo.
sinais_m3 <- function(series, pib, ano, m, p1) {
  info <- tryCatch(montar_info(list(bcb = series$regional, bcb_est = series$estaduais, bcb_mun = series$municipais, pib = pib), ano, m), error = function(e) NULL)
  g <- function(f) if (is.null(info)) NA_real_ else tryCatch(f(), error = function(e) NA_real_)
  v <- c(regional = g(function() CANDIDATOS_P1_BASE$m3(info, ano, m)), estaduais = g(function() prever_total_restante(info, ano, m, ESPEC_M3_ESTADOS, serie = info$bcb_est)),
         municipais = g(function() prever_total_restante(info, ano, m, ESPEC_M3_MUNICIPIOS, serie = info$bcb_mun)))
  srw <- p1$previsao_bi[match(names(v), p1$esfera)]
  data.frame(esfera = names(v), m3_bi = unname(v), srw_bi = srw, m3_menos_srw_bi = unname(v) - srw, pib_ano_bi = pib$pib_bi[pib$ano == ano][1], row.names = NULL, stringsAsFactors = FALSE)
}

#' P2 realizado anual por diferenca (receita total - despesa total, 27 UFs) a partir dos fluxos harmonizados com totais. Retorna data.frame(exercicio, rec_bi, desp_bi, p2_bi).
sinais_p2_anual <- function(fh_tot, n_ufs = 27L) {
  x <- fh_tot[fh_tot$serie %in% c("rec:total", "desp:total") & !is.na(fh_tot$valor), ]
  g <- aggregate(valor ~ cod_ibge + exercicio + serie, x, function(z) sum(z)); n <- aggregate(periodo ~ cod_ibge + exercicio + serie, x, function(z) length(unique(z)))
  g <- merge(g, n); g <- g[g$periodo == 6L, ]
  out <- lapply(split(g, g$exercicio), function(d) { r <- d[d$serie == "rec:total", ]; s <- d[d$serie == "desp:total", ]; ok <- intersect(r$cod_ibge, s$cod_ibge)
    if (length(ok) < n_ufs) return(NULL); data.frame(exercicio = d$exercicio[1], rec_bi = sum(r$valor[r$cod_ibge %in% ok]) / 1e9, desp_bi = sum(s$valor[s$cod_ibge %in% ok]) / 1e9) })
  out <- do.call(rbind, out); if (is.null(out)) return(data.frame(exercicio = integer(0), rec_bi = numeric(0), desp_bi = numeric(0), p2_bi = numeric(0)))
  out <- out[out$rec_bi > 0 & out$desp_bi > 0, ]   # total de despesa 0 = nao reconstruido (ausente nao e zero)
  out$p2_bi <- out$rec_bi - out$desp_bi; rownames(out) <- NULL; out
}

#' Classe do gap (regra do E3.6 adaptada ao horizonte anual): referencia = mediana e MAD do gap realizado (% da receita) dos `anos_ref` anos anteriores, mesma serie (a partir da fronteira de 2023),
#' minimo `min_ref` observacoes; atipico se |r - mediana| > max(K * MAD, piso). `ref`: data.frame(exercicio, r_real).
sinais_classe_gap <- function(r, ano, ref) {
  seg <- function(a) as.integer(a >= GAP_FRONTEIRA); j <- ref$exercicio < ano & ref$exercicio >= ano - GAP_ANOS_REF & seg(ref$exercicio) == seg(ano) & is.finite(ref$r_real)
  if (sum(j) < GAP_MIN_REF) return(data.frame(classe = "sem_referencia", med_ref = NA_real_, mad_ref = NA_real_, n_ref = sum(j), limiar = NA_real_, stringsAsFactors = FALSE))
  md <- stats::median(ref$r_real[j]); ma <- stats::median(abs(ref$r_real[j] - md)); lim <- max(GAP_K_MAD * ma, GAP_PISO)
  data.frame(classe = if (abs(r - md) > lim) "atipico" else "consistente", med_ref = md, mad_ref = ma, n_ref = sum(j), limiar = lim, stringsAsFactors = FALSE)
}

#' Gap implicito e decomposicao. `proj`: resultado de e5_projecao_rodada(); `est`: SGS estaduais (data, valor_bi); `p2_anual`: sinais_p2_anual(); `base_ant`: A e T do ano anterior no corte do P2 (cod_ibge, serie, A, T).
#' Decomposicao no mesmo corte (P2 ate o bimestre b, P1 no mes 2b): total = (i) acumulado + (ii-a) hipotese do restante + (ii-b) diferenca sazonal RREO - BCB do restante do ano anterior.
sinais_gap <- function(proj, est, p2_anual, base_ant, ano, m_p1) {
  if (is.null(proj)) return(NULL)
  b <- proj$corte; m8 <- 2L * b; plano <- proj$plano[proj$plano$oficial, ]; u <- proj$uf
  pega <- function(s) { mo <- plano$modelo[plano$serie == s]; u[u$serie == s & u$modelo == mo, ] }
  rec <- pega("rec:total"); des <- pega("desp:total"); if (!nrow(rec) || !nrow(des)) return(NULL)
  p2 <- (sum(rec$That) - sum(des$That)) / 1e9; rec_bi <- sum(rec$That) / 1e9
  p1_m <- prever_srw(est, ano, m_p1); p1_8 <- prever_srw(est, ano, m8)
  gap <- p2 - p1_m; r <- gap / rec_bi
  real <- p2_anual; real$p1_bi <- vapply(real$exercicio, function(a) soma_meses(est, a, 1:12), 0); real$gap_bi <- real$p2_bi - real$p1_bi; real$r_real <- real$gap_bi / real$rec_bi
  cl <- sinais_classe_gap(r, ano, real[, c("exercicio", "r_real")])
  A2 <- (sum(rec$A) - sum(des$A)) / 1e9; R2 <- p2 - A2
  ar <- base_ant[base_ant$serie == "rec:total", ]; ad <- base_ant[base_ant$serie == "desp:total", ]
  R2ant <- ((sum(ar$T) - sum(ar$A)) - (sum(ad$T) - sum(ad$A))) / 1e9
  A1 <- soma_meses(est, ano, 1:m8); R1 <- soma_meses(est, ano - 1L, (m8 + 1L):12)
  dec <- data.frame(componente = c("P2 projetado (corte do P2)", "P1 SRW estados (mesmo corte, mês 2b)", "diferença total (P2 - P1)", "(i) acumulado até o corte (P2 realizado - P1 realizado)",
      "(ii-a) hipótese do restante (restante projetado - restante de t-1, ambos em R$ do P2)", "(ii-b) diferença sazonal RREO - BCB no restante de t-1", "memo: SRW dos estados no corte atual do P1 (mês m)", "memo: gap implícito no corte do P1 (P2 projetado - SRW mês m)"),
    valor_bi = c(p2, p1_8, p2 - p1_8, A2 - A1, R2 - R2ant, R2ant - R1, p1_m, gap), stringsAsFactors = FALSE)
  list(resumo = data.frame(ano = ano, p2_projetado_bi = p2, srw_estados_bi = p1_m, gap_implicito_bi = gap, gap_pct_receita = 100 * r, classe = cl$classe, referencia_pct = 100 * cl$med_ref, mad_pct = 100 * cl$mad_ref, limiar_pp = 100 * cl$limiar,
                           n_ref = cl$n_ref, modelo_receita = plano$modelo[plano$serie == "rec:total"], modelo_despesa = plano$modelo[plano$serie == "desp:total"], stringsAsFactors = FALSE),
       decomposicao = dec, realizado = real)
}

#' Erro historico do SRW no corte `m`, por esfera, em anos de eleicao estadual (ano %% 4 == 2) x demais (e demais sem 2020-21). erro = previsao - realizado (superavit positivo).
sinais_srw_eleicao <- function(series, m, ano_alvo, anos = 2007:(ano_alvo - 1L)) {
  er <- do.call(rbind, lapply(names(series), function(e) do.call(rbind, lapply(anos, function(a) { p <- prever_srw(series[[e]], a, m); r <- soma_meses(series[[e]], a, 1:12)
    if (is.finite(p) && is.finite(r)) data.frame(esfera = e, ano = a, srw_bi = p, realizado_bi = r, erro_bi = p - r) else NULL }))))
  if (is.null(er)) return(NULL)
  er$eleicao <- er$ano %% 4L == 2L; er$pandemia <- er$ano %in% 2020:2021
  res <- do.call(rbind, lapply(split(er, er$esfera), function(d) { f <- function(x) c(n = nrow(x), me = mean(x$erro_bi), mae = mean(abs(x$erro_bi)))
    a <- f(d[d$eleicao, ]); b <- f(d[!d$eleicao, ]); c3 <- f(d[!d$eleicao & !d$pandemia, ])
    data.frame(esfera = d$esfera[1], corte_m = m, n_eleicao = a[["n"]], me_eleicao_bi = a[["me"]], mae_eleicao_bi = a[["mae"]], n_demais = b[["n"]], me_demais_bi = b[["me"]], mae_demais_bi = b[["mae"]],
               n_demais_sem_2020_21 = c3[["n"]], me_demais_sem_2020_21_bi = c3[["me"]], mae_demais_sem_2020_21_bi = c3[["mae"]], stringsAsFactors = FALSE) }))
  rownames(res) <- NULL
  list(resumo = res, por_ano = er[er$eleicao, c("esfera", "ano", "srw_bi", "realizado_bi", "erro_bi")], ano_alvo_eleicao = ano_alvo %% 4L == 2L)
}

#' Previsao do corte atual de todos os candidatos do torneio do P1 (lista corrente: SRW em R$ (base), SRW em % do PIB, acumulado j=5, m2, m3, E4.1, FPE/FPM, combinacao), por esfera quando
#' o candidato existe na esfera (SRW; E4.1 = m3 por componente), com o RMSE relativo ao SRW na faixa do corte (docs/nota_p1.md; data/protocolo/p1_rmse_relativo.csv). So informacao.
#' `stn`: transferencias da STN (carregar_stn) ou NULL (o FPE/FPM sai NA). `rel`: p1_rmse_relativo.csv ou NULL.
sinais_candidatos <- function(series, pib, ano, m, rel = NULL, stn = NULL) {
  fontes <- list(bcb = series$regional, bcb_est = series$estaduais, bcb_mun = series$municipais, pib = pib); if (!is.null(stn)) fontes$stn <- stn
  info <- tryCatch(montar_info(fontes, ano, m), error = function(e) NULL)
  g <- function(f) if (is.null(info)) NA_real_ else tryCatch(f(), error = function(e) NA_real_)
  cands <- CANDIDATOS_P1_COM_FPE
  reg <- vapply(cands, function(f) g(function() f(info, ano, m)), 0)
  reg[["combinacao"]] <- if (all(is.na(reg))) NA_real_ else mean(reg, na.rm = TRUE)    # media dos candidatos disponiveis no corte (definicao do contrato)
  est <- c(srw_brl = g(function() prever_srw(info$bcb_est, ano, m)), e41 = g(function() prever_total_restante(info, ano, m, ESPEC_M3_ESTADOS, serie = info$bcb_est)))
  mun <- c(srw_brl = g(function() prever_srw(info$bcb_mun, ano, m)), e41 = g(function() prever_total_restante(info, ano, m, ESPEC_M3_MUNICIPIOS, serie = info$bcb_mun)))
  nomes <- c(srw_brl = "SRW em R$ (base, oficial)", srw_pib = "SRW em % do PIB", acumulado_j5 = "acumulado j=5", m2 = "m2", m3 = "m3", e41 = "E4.1 (m3 por componente)", fpe_fpm = "FPE/FPM (m3 + g)", combinacao = "combinação")
  fx <- faixa_corte(m); out <- list()
  for (e in c("regional", "estaduais", "municipais")) {
    v <- switch(e, regional = reg, estaduais = est, municipais = mun)
    for (k in names(v)) out[[length(out) + 1]] <- data.frame(candidato = k, nome = nomes[[k]], esfera = e, previsao_bi = unname(v[[k]]), stringsAsFactors = FALSE)
  }
  d <- do.call(rbind, out); d$srw_mesma_esfera_bi <- d$previsao_bi[match(paste("srw_brl", d$esfera), paste(d$candidato, d$esfera))]; d$menos_srw_bi <- d$previsao_bi - d$srw_mesma_esfera_bi
  d$faixa <- if (is.na(fx)) NA_character_ else fx
  r <- if (is.null(rel) || is.na(fx)) NULL else rel[rel$faixa == fx, ]
  k <- if (is.null(r)) rep(NA_integer_, nrow(d)) else match(d$candidato, r$candidato)
  d$rel_rmse_vs_srw_sem_2020_22 <- if (is.null(r)) NA_real_ else r$rel_rmse_sem_2020_22[k]; d$n_anos_sem_2020_22 <- if (is.null(r)) NA_integer_ else r$n_anos_sem_2020_22[k]
  d$rel_rmse_vs_srw_todos <- if (is.null(r)) NA_real_ else r$rel_rmse_todos[k]; d$n_anos_todos <- if (is.null(r)) NA_integer_ else r$n_anos_todos[k]
  d$observacao <- ifelse(d$esfera != "regional" & d$candidato != "srw_brl", "RMSE e o do candidato regional (torneio do P1)", ifelse(is.na(d$previsao_bi) & d$candidato == "fpe_fpm", "STN indisponível nesta rodada", ""))
  d$rel_rmse_vs_srw_sem_2020_22[d$candidato == "srw_brl"] <- 0; d$rel_rmse_vs_srw_todos[d$candidato == "srw_brl"] <- 0
  d$srw_mesma_esfera_bi <- NULL; rownames(d) <- NULL; d
}

#' Tudo da aba Sinais. `I`: entrada do informe (series, pib, p1, proj, fh_tot, base_ant, corte).
sinais_tudo <- function(I) {
  ano <- I$corte$ano_alvo; m <- I$corte$m
  list(m3 = sinais_m3(I$series, I$pib, ano, m, I$p1), candidatos = sinais_candidatos(I$series, I$pib, ano, m, I$p1_rel, I$stn), gap = tryCatch(sinais_gap(I$proj, I$series$estaduais, sinais_p2_anual(I$fh_tot), I$base_ant, ano, m), error = function(e) NULL),
       srw = sinais_srw_eleicao(I$series, m, ano))
}
