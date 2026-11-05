# E5 (estados): painel UF x serie x ano x corte, candidatos B0, M1-M4, Ca, Cb, M5 e avaliacao.
# Especificacao fixada: docs/e5_especificacao.md (PR #66). Serie: COM RPPS, sem intraorcamentarias (conceito consolidado, harmonizada).
# Resposta dos modelos em diferenca: y = log r(t) - log r(t-1), r = restante/acumulado no corte (aprovado em 04/11).
# Codigo so em ASCII.

E5_ALVOS <- c("rec:total", "desp:total")
E5_DIAG <- c("rec:ICMS", "rec:IPVA", "rec:FPE/FPM", "rec:demais receitas", "desp:pessoal", "desp:custeio", "desp:investimento")
E5_FAIXAS <- list(b1_b2 = 1:2, b3_b4 = 3:4, b5 = 5L)
E5_SEMENTE <- 20261104L
E5_SEMENTE_STAN <- 20261105L
E5_AMOSTRAS <- list(A = integer(0), S = 2020:2021, S3 = 2020:2022)   # anos excluidos do treino e do teste (S: 2022 dentro, marcado)
E5_TREINO_MIN <- 3L

# ---- IPCA --------------------------------------------------------------------------------------------------------------------------------------

#' Funcao ind(exercicio, bimestre) = media do indice acumulado dos dois meses do bimestre (base: primeiro mes da serie).
e5_ipca_bim <- function(sgs) {
  sgs <- sgs[order(sgs$data), ]; ind <- cumprod(1 + sgs$valor / 100); chave <- format(sgs$data, "%Y-%m")
  function(ex, b) (ind[match(sprintf("%d-%02d", ex, 2L * b - 1L), chave)] + ind[match(sprintf("%d-%02d", ex, 2L * b), chave)]) / 2
}

# ---- Painel ------------------------------------------------------------------------------------------------------------------------------------

#' Totais de receita e despesa (soma das series rec:* e desp:*) acrescentados ao fluxo. `x`: cod_ibge, serie, exercicio, periodo, valor.
e5_com_totais <- function(x) {
  x <- x[, c("cod_ibge", "serie", "exercicio", "periodo", "valor")]
  tot <- function(pref, nome) {
    y <- x[grepl(pref, x$serie) & !is.na(x$valor), ]
    a <- aggregate(valor ~ cod_ibge + exercicio + periodo, y, sum); a$serie <- nome; a[, names(x)]
  }
  rbind(x, tot("^rec:", "rec:total"), tot("^desp:", "desp:total"))
}

#' Painel de UF-anos validos: uma linha por UF x serie x ano x corte (b = 1..5). Valido = 6 bimestres, acumulado e restante > 0 nos 5 cortes.
#' Colunas: A (acumulado), T (total do ano), R (restante), r, Areal, Treal (deflacionados bimestre a bimestre, mesma base).
e5_painel <- function(P, ind_bim, series) {
  P <- P[P$serie %in% series & !is.na(P$valor) & P$periodo %in% 1:6, c("cod_ibge", "serie", "exercicio", "periodo", "valor")]
  P$real <- P$valor / ind_bim(P$exercicio, P$periodo)
  ch <- split(P, list(P$cod_ibge, P$serie, P$exercicio), drop = TRUE)
  out <- lapply(ch, function(d) {
    v <- rep(NA_real_, 6); vr <- v; v[d$periodo] <- d$valor; vr[d$periodo] <- d$real
    if (anyNA(v) || anyNA(vr)) return(NULL)
    ac <- cumsum(v); acr <- cumsum(vr); b <- 1:5
    if (any(ac[b] <= 0) || any(ac[6] - ac[b] <= 0)) return(NULL)
    data.frame(cod_ibge = d$cod_ibge[1], serie = d$serie[1], exercicio = d$exercicio[1], corte = b, A = ac[b], T = ac[6], R = ac[6] - ac[b],
               r = (ac[6] - ac[b]) / ac[b], Areal = acr[b], Treal = acr[6])
  })
  out <- do.call(rbind, out)
  if (is.null(out)) return(data.frame(cod_ibge = integer(0), serie = character(0), exercicio = integer(0), corte = integer(0), A = numeric(0), T = numeric(0), R = numeric(0), r = numeric(0), Areal = numeric(0), Treal = numeric(0)))
  rownames(out) <- NULL
  out[order(out$cod_ibge, out$serie, out$exercicio, out$corte), ]
}

#' Marca os alvos: UF-ano valido, ano anterior valido e pelo menos `treino` UF-anos validos antes (mesma regra do E5.0).
e5_marcar_alvos <- function(painel, treino = E5_TREINO_MIN) {
  ch <- unique(painel[, c("cod_ibge", "serie", "exercicio")]); ch <- ch[order(ch$cod_ibge, ch$serie, ch$exercicio), ]
  ch$alvo <- FALSE
  for (k in split(seq_len(nrow(ch)), paste(ch$cod_ibge, ch$serie))) {
    ex <- ch$exercicio[k]
    ch$alvo[k] <- ((ex - 1L) %in% ex) & (seq_along(ex) - 1L >= treino)
  }
  merge(painel, ch, by = c("cod_ibge", "serie", "exercicio"), sort = FALSE)
}

#' Dummies de quebra (secao 3 da especificacao). d_resto/d_base: LC 194 (2022 b4-b6) em receita total e ICMS; d_yoy: RS 2023 (despesa total e pessoal)
#' e RS 2024 (pessoal e custeio); d_intra23: ano de 2023 na despesa total (pendencias incluem intra, nao separavel).
e5_dummies <- function(d) {
  s <- d$serie
  d$d_resto <- as.numeric(s %in% c("rec:total", "rec:ICMS") & d$exercicio == 2022L & d$corte < 4L)
  d$d_base <- as.numeric(s %in% c("rec:total", "rec:ICMS") & d$exercicio == 2023L & d$corte < 4L)
  d$d_yoy <- as.numeric(d$cod_ibge == 43L & ((s %in% c("desp:total", "desp:pessoal") & d$exercicio == 2023L) | (s %in% c("desp:pessoal", "desp:custeio") & d$exercicio == 2024L)))
  d$d_intra23 <- as.numeric(s == "desp:total" & d$exercicio == 2023L)
  d
}

#' Linhas do modelo: ano t com o ano t-1 (mesmo UF, serie, corte). y = log r(t) - log r(t-1); x1 = log r(t-1); x2 = log do acumulado real t / t-1.
#' `pend`: data.frame(cod_ibge, exercicio, corte, liq_menos_paga, emp_menos_liq) nominais (A6, despesa total); `den`: despesa total bruta do ano anterior (real).
e5_base_modelo <- function(painel, ind_bim = NULL, pend = NULL, den = NULL) {
  ant <- painel[, c("cod_ibge", "serie", "exercicio", "corte", "r", "Areal", "Treal", "T")]
  ant$exercicio <- ant$exercicio + 1L; names(ant)[5:8] <- c("r_ant", "Areal_ant", "Treal_ant", "T_ant")
  d <- merge(painel, ant, by = c("cod_ibge", "serie", "exercicio", "corte"), sort = FALSE)
  d$x1 <- log(d$r_ant); d$y <- log(d$r) - d$x1; d$x2 <- log(d$Areal / d$Areal_ant)
  d$x3 <- NA_real_; d$x4 <- NA_real_
  if (!is.null(pend) && !is.null(den) && !is.null(ind_bim)) {
    k <- d$serie == "desp:total"
    m <- merge(d[k, c("cod_ibge", "exercicio", "corte")], pend, by = c("cod_ibge", "exercicio", "corte"), all.x = TRUE, sort = FALSE)
    m <- merge(m, den, by = c("cod_ibge", "exercicio"), all.x = TRUE, sort = FALSE)   # den: cod_ibge, exercicio (t), Treal_bruta_ant
    esc <- m$Treal_bruta_ant * ind_bim(m$exercicio, m$corte)
    m$x3 <- m$liq_menos_paga / esc; m$x4 <- m$emp_menos_liq / esc
    idx <- match(paste(d$cod_ibge[k], d$exercicio[k], d$corte[k]), paste(m$cod_ibge, m$exercicio, m$corte))
    d$x3[k] <- m$x3[idx]; d$x4[k] <- m$x4[idx]
  }
  d <- e5_dummies(d)
  d[order(d$serie, d$cod_ibge, d$exercicio, d$corte), ]
}

#' Termos (preditores pre-registrados) por serie.
e5_termos <- function(serie) {
  if (serie == "rec:total" || serie == "rec:ICMS") return(c("x1", "x2", "d_resto", "d_base"))
  if (serie == "desp:total") return(c("x1", "x2", "x3", "x4", "d_yoy", "d_intra23"))
  if (serie %in% c("desp:pessoal", "desp:custeio")) return(c("x1", "x2", "d_yoy"))
  c("x1", "x2")
}

# ---- A6: pendencias, previsao e dotacao dos entes -------------------------------------------------------------------------------------------

#' Itens do total primario do Anexo 6 (com RPPS): acumulados ate o bimestre. Retorna data.frame largo por UF x ano x periodo:
#' rec_real, prev_atual, prev_loa, dotacao, empenhada, liquidada, paga, rp_proc_pago, rpnp_pago.
e5_a6_totais <- function(rreo, dic, dc) {
  d <- aplicar_dicionario(rreo[rreo$anexo == "RREO-Anexo 06", ], dic, dc)
  d <- d[d$papel_conta %in% c("rec_total", "desp_total") & d$rpps %in% c("inclui_rpps", "incluido_nao_separavel") & d$ano_rel %in% c("corrente", "nao_se_aplica"), ]
  rot <- normalizar_rotulo(d$coluna)
  d$item <- ifelse(d$papel_conta == "rec_total" & d$estagio == "receita_realizada", "rec_real",
            ifelse(d$papel_conta == "rec_total" & d$estagio == "previsao" & grepl("atualizada", rot), "prev_atual",
            ifelse(d$papel_conta == "rec_total" & d$estagio == "previsao" & grepl("orcamentaria", rot), "prev_loa",
            ifelse(d$papel_conta == "desp_total" & d$estagio %in% c("dotacao", "empenhada", "liquidada", "paga", "rp_processado_pago", "rpnp_pago"), d$estagio, NA_character_))))
  d$item[d$item == "rp_processado_pago"] <- "rp_proc_pago"
  d <- d[!is.na(d$item), ]
  d <- d[!duplicated(d[, c("cod_ibge", "exercicio", "periodo", "item", "cod_conta", "coluna")]), ]
  a <- aggregate(valor ~ cod_ibge + exercicio + periodo + item, d, function(z) z[1])
  w <- reshape(a, idvar = c("cod_ibge", "exercicio", "periodo"), timevar = "item", direction = "wide")
  names(w) <- sub("^valor\\.", "", names(w))
  for (n in c("rec_real", "prev_atual", "prev_loa", "dotacao", "empenhada", "liquidada", "paga", "rp_proc_pago", "rpnp_pago")) if (!n %in% names(w)) w[[n]] <- NA_real_
  w$caixa <- ifelse(is.na(w$paga), NA_real_, w$paga + ifelse(is.na(w$rp_proc_pago), 0, w$rp_proc_pago) + ifelse(is.na(w$rpnp_pago), 0, w$rpnp_pago))
  rownames(w) <- NULL; w
}

# ---- Estimacao ---------------------------------------------------------------------------------------------------------------------------------

#' Padroniza x2, x3, x4 pelo treino, remove termos sem variacao e prepara fatores.
e5_prepara <- function(tr, al, termos) {
  for (v in intersect(termos, c("x2", "x3", "x4"))) {
    m <- mean(tr[[v]]); s <- stats::sd(tr[[v]]); if (!is.finite(s) || s == 0) s <- 1
    tr[[v]] <- (tr[[v]] - m) / s; al[[v]] <- (al[[v]] - m) / s
  }
  ok <- vapply(termos, function(v) isTRUE(stats::var(tr[[v]]) > 0), logical(1)); termos <- termos[ok]
  tr$corte_f <- factor(tr$corte); al$corte_f <- factor(al$corte, levels = levels(tr$corte_f))
  tr$uf <- factor(tr$cod_ibge); al$uf <- factor(al$cod_ibge, levels = levels(tr$uf))
  tr$ano <- factor(tr$exercicio); al$ano <- factor(al$exercicio)
  rhs <- c(termos, if (nlevels(tr$corte_f) > 1) "corte_f")
  list(tr = tr, al = al, rhs = rhs)
}

#' Priori do M4 (versionadas na especificacao, secao 6).
e5_stan_cfg <- list(chains = 4L, iter = 2000L, adapt_delta = 0.95, seed = E5_SEMENTE_STAN, rhat_max = 1.01, ess_min = 400)

#' Previsao de y (diferenca em log r) para as linhas `al` dado o treino `tr`. modelo: "M1".."M4". NA se nao estimavel ou sem convergencia.
e5_prever <- function(tr, al, termos, modelo, cfg = e5_stan_cfg) {
  na <- rep(NA_real_, nrow(al))
  if (nrow(tr) < 20 || length(unique(tr$exercicio)) < 2) return(list(yhat = na, diag = "treino_curto"))
  p <- e5_prepara(tr, al, termos); tr <- p$tr; al <- p$al; rhs <- p$rhs
  f_fix <- paste(c("y ~ 1", rhs), collapse = " + ")
  res <- tryCatch(suppressWarnings(suppressMessages({
    if (modelo == "M1") list(yhat = as.numeric(stats::predict(stats::lm(stats::as.formula(f_fix), tr), al)), diag = "ok")
    else if (modelo == "M2") list(yhat = as.numeric(stats::predict(stats::lm(stats::as.formula(paste(f_fix, "+ uf")), tr), al)), diag = "ok")
    else {
      f_mix <- stats::as.formula(paste(f_fix, "+ (1 | uf) + (1 | ano)"))
      if (modelo == "M3") {
        fit <- lme4::lmer(f_mix, tr, REML = TRUE)
        list(yhat = as.numeric(stats::predict(fit, al, allow.new.levels = TRUE)), diag = "ok")
      } else {
        fit <- rstanarm::stan_glmer(f_mix, data = tr, family = stats::gaussian(),
          prior = rstanarm::normal(0, 1, autoscale = FALSE), prior_intercept = rstanarm::normal(0, 1, autoscale = FALSE),
          prior_aux = rstanarm::exponential(1, autoscale = FALSE), prior_covariance = rstanarm::decov(2, 1, 1, 1),
          chains = cfg$chains, iter = cfg$iter, adapt_delta = cfg$adapt_delta, seed = cfg$seed, refresh = 0, cores = min(cfg$chains, 2L))
        sm <- as.data.frame(summary(fit)); sm <- sm[!grepl("^b\\[|Sigma", rownames(sm)), ]
        nd <- rstan::get_num_divergent(fit$stanfit)
        ok <- all(sm$Rhat < cfg$rhat_max, na.rm = TRUE) && all(sm$n_eff > cfg$ess_min, na.rm = TRUE) && nd == 0
        if (!ok) list(yhat = na, diag = sprintf("nao_convergiu(rhat=%.3f,ess=%.0f,div=%d)", max(sm$Rhat, na.rm = TRUE), min(sm$n_eff, na.rm = TRUE), nd))
        else list(yhat = colMeans(rstanarm::posterior_epred(fit, newdata = al, allow_new_levels = TRUE)), diag = "ok")
      }
    }
  })), error = function(e) list(yhat = na, diag = paste0("erro: ", substr(conditionMessage(e), 1, 80))))
  res
}

#' Previsoes rolantes de uma serie numa amostra. `b`: saida de e5_base_modelo() filtrada na serie. `excl`: anos fora do treino e do teste.
#' Retorna data.frame(serie, amostra, faixa, cod_ibge, exercicio, corte, modelo, logr_hat) e a tabela de diagnosticos das celulas.
e5_rodar_serie <- function(b, serie, amostra, excl = integer(0), modelos = c("M1", "M2", "M3", "M4"), cfg = e5_stan_cfg, quieto = FALSE) {
  b <- b[b$serie == serie & !b$exercicio %in% excl, ]
  termos <- e5_termos(serie); need <- intersect(c("y", "x1", "x2", "x3", "x4"), c("y", termos))
  b <- b[stats::complete.cases(b[, need]), ]
  pred <- list(); dg <- list()
  for (f in names(E5_FAIXAS)) {
    cf <- E5_FAIXAS[[f]]; bf <- b[b$corte %in% cf, ]
    for (t in sort(unique(bf$exercicio[bf$alvo]))) {
      tr <- bf[bf$exercicio < t, ]; al <- bf[bf$exercicio == t & bf$alvo, ]
      if (!nrow(al)) next
      base <- data.frame(serie = serie, amostra = amostra, faixa = f, cod_ibge = al$cod_ibge, exercicio = al$exercicio, corte = al$corte)
      pred[[length(pred) + 1]] <- cbind(base, modelo = "B0", logr_hat = al$x1)
      for (m in modelos) {
        r <- e5_prever(tr, al, termos, m, cfg)
        pred[[length(pred) + 1]] <- cbind(base, modelo = m, logr_hat = al$x1 + r$yhat)
        dg[[length(dg) + 1]] <- data.frame(serie = serie, amostra = amostra, faixa = f, exercicio = t, modelo = m, n_treino = nrow(tr), n_alvo = nrow(al), diag = r$diag)
        if (!quieto) message(sprintf("%s %s %s %d %s: %s", serie, amostra, f, t, m, r$diag))
      }
    }
  }
  list(pred = do.call(rbind, pred), diag = do.call(rbind, dg))
}

# ---- Ca e Cb (previsoes dos entes corrigidas) ----------------------------------------------------------------------------------------------

#' Ca (receita total) e Cb (despesa total) em log r. `b`: base do modelo da serie; `a6`: e5_a6_totais(). Treino do vies/taxa: anos < t (e fora de `excl`), pool de UFs,
#' mesmo corte (b). Ca: P_hat = P_atual / (1 + vies medio), vies = (P_atual(b) - T_A6) / T_A6; r_hat = (P_hat - A_A6) / A_A6.
#' Cb: E_hat = dotacao(b) x taxa media (caixa final / dotacao(b)); r_hat = (E_hat - caixa(b)) / caixa(b). Calculados no conceito do A6 e aplicados ao acumulado harmonizado.
e5_candidatos_entes <- function(b, a6, serie, amostra, excl = integer(0)) {
  b <- b[b$serie == serie & b$alvo & !b$exercicio %in% excl, ]
  a6 <- a6[a6$periodo %in% 1:6, ]
  fin <- a6[a6$periodo == 6, ]
  w <- a6[a6$periodo %in% 1:5, ]; names(w)[names(w) == "periodo"] <- "corte"
  if (serie == "rec:total") {
    w$A6 <- w$rec_real; w$P <- w$prev_atual; fin$Tfin <- fin$rec_real
    w <- merge(w, fin[, c("cod_ibge", "exercicio", "Tfin")], by = c("cod_ibge", "exercicio"))
    w$er <- (w$P - w$Tfin) / w$Tfin; mod <- "Ca"
  } else {
    w$A6 <- w$caixa; w$P <- w$dotacao; fin$Tfin <- fin$caixa
    w <- merge(w, fin[, c("cod_ibge", "exercicio", "Tfin")], by = c("cod_ibge", "exercicio"))
    w$er <- w$Tfin / w$P; mod <- "Cb"
  }
  w <- w[is.finite(w$er) & is.finite(w$A6) & w$A6 > 0 & is.finite(w$P) & w$P > 0, ]
  out <- list()
  for (f in names(E5_FAIXAS)) for (t in sort(unique(b$exercicio[b$corte %in% E5_FAIXAS[[f]]]))) for (cc in E5_FAIXAS[[f]]) {
    hist <- w[w$corte == cc & w$exercicio < t & !w$exercicio %in% excl, ]
    al <- b[b$exercicio == t & b$corte == cc, ]; cur <- w[w$exercicio == t & w$corte == cc, ]
    if (!nrow(al) || length(unique(hist$exercicio)) < 2) next
    k <- merge(al[, c("cod_ibge", "exercicio", "corte")], cur, by.x = c("cod_ibge", "exercicio", "corte"), by.y = c("cod_ibge", "exercicio", "corte"))
    if (!nrow(k)) next
    if (mod == "Ca") { Ph <- k$P / (1 + mean(hist$er)); rh <- (Ph - k$A6) / k$A6 } else { Eh <- k$P * mean(hist$er); rh <- (Eh - k$A6) / k$A6 }
    ok <- is.finite(rh) & rh > 0
    if (any(ok)) out[[length(out) + 1]] <- data.frame(serie = serie, amostra = amostra, faixa = f, cod_ibge = k$cod_ibge[ok], exercicio = t, corte = cc, modelo = mod, logr_hat = log(rh[ok]))
  }
  if (!length(out)) return(NULL)
  do.call(rbind, out)
}

# ---- Erros e metricas -------------------------------------------------------------------------------------------------------------------------

#' Anexa os erros: e = 100 (T_hat - T) / T, T_hat = A (1 + exp(logr_hat)); acerto de sinal do crescimento real (restante deflacionado pela razao real/nominal realizada).
e5_erros <- function(pred, b) {
  k <- b[, c("serie", "cod_ibge", "exercicio", "corte", "A", "T", "Areal", "Treal", "Treal_ant")]
  d <- merge(pred, k, by = c("serie", "cod_ibge", "exercicio", "corte"))
  d$That <- d$A * (1 + exp(d$logr_hat)); d$e <- 100 * (d$That - d$T) / d$T
  Rr <- d$Treal - d$Areal; Rn <- d$T - d$A
  d$Thatreal <- d$Areal + (d$That - d$A) * (Rr / Rn)
  d$acerto <- as.numeric(sign(d$Thatreal / d$Treal_ant - 1) == sign(d$Treal / d$Treal_ant - 1))
  d$ok <- is.finite(d$e)
  d[d$ok, ]
}

e5_resumo <- function(E, por = c("serie", "amostra", "faixa", "modelo", "corte")) {
  g <- split(E, E[, por], drop = TRUE)
  out <- lapply(g, function(d) cbind(d[1, por, drop = FALSE], n = nrow(d), ME = mean(d$e), MAE = mean(abs(d$e)), RMSE = sqrt(mean(d$e^2)), acerto = mean(d$acerto)))
  out <- do.call(rbind, out); rownames(out) <- NULL; out
}

#' Criterios de aceitacao de um candidato contra o B0 nas mesmas celulas (UF, ano, corte). `E`: erros de uma serie x amostra x faixa. `B`: reamostragens de bootstrap.
e5_criterios <- function(E, modelo, B = 2000L, semente = E5_SEMENTE) {
  c_ <- E[E$modelo == modelo, ]; b0 <- E[E$modelo == "B0", ]
  m <- merge(c_[, c("cod_ibge", "exercicio", "corte", "e", "acerto")], b0[, c("cod_ibge", "exercicio", "corte", "e", "acerto")], by = c("cod_ibge", "exercicio", "corte"), suffixes = c("_c", "_b"))
  if (nrow(m) < 10) return(data.frame(modelo = modelo, n = nrow(m), n_anos = NA_integer_, RMSE_c = NA_real_, RMSE_b0 = NA_real_, razao_rmse = NA_real_, ME_c = NA_real_, ME_b0 = NA_real_,
    acerto_c = NA_real_, acerto_b0 = NA_real_, c1_rmse10 = NA, c2_pares = NA, share_uf_ano = NA_real_, share_anos = NA_real_, c3_sinal = NA, c4_vies = NA, prob_boot = NA_real_, c5_boot = NA))
  rm <- function(x) sqrt(mean(x^2))
  rmse_c <- rm(m$e_c); rmse_b <- rm(m$e_b)
  por_corte <- vapply(split(m, m$corte), function(d) rm(d$e_c) < rm(d$e_b), logical(1))
  uf_ano <- aggregate(cbind(ac = abs(e_c), ab = abs(e_b)) ~ cod_ibge + exercicio, m, mean)
  por_ano <- vapply(split(m, m$exercicio), function(d) rm(d$e_c) < rm(d$e_b), logical(1))
  me_c <- mean(m$e_c); me_b <- mean(m$e_b)
  set.seed(semente); anos <- sort(unique(m$exercicio)); idx <- split(seq_len(nrow(m)), m$exercicio)
  win <- replicate(B, { s <- sample(anos, length(anos), replace = TRUE); i <- unlist(idx[as.character(s)]); rm(m$e_c[i]) < rm(m$e_b[i]) })
  data.frame(modelo = modelo, n = nrow(m), n_anos = length(anos), RMSE_c = rmse_c, RMSE_b0 = rmse_b, razao_rmse = rmse_c / rmse_b,
    ME_c = me_c, ME_b0 = me_b, acerto_c = mean(m$acerto_c), acerto_b0 = mean(m$acerto_b),
    c1_rmse10 = (rmse_c <= 0.9 * rmse_b) && all(por_corte), c2_pares = mean(uf_ano$ac < uf_ano$ab) > 0.5 && mean(por_ano) > 0.5,
    share_uf_ano = mean(uf_ano$ac < uf_ano$ab), share_anos = mean(por_ano),
    c3_sinal = mean(m$acerto_c) >= mean(m$acerto_b), c4_vies = abs(me_c) <= abs(me_b) + 0.1 * rmse_b,
    prob_boot = mean(win), c5_boot = mean(win) >= 0.80)
}
