# E5 estados: roda a especificacao fixada (docs/e5_especificacao.md): B0, M1-M4, Ca, Cb, M5; criterios de aceitacao; variantes; testes informativos.
# Uso: LC_ALL=C.UTF-8 Rscript scripts/e5_rodar.R [--rapida] [--sem-m4] [--sem-variantes] [--sem-registro]
# Saidas (FISCAL_DADOS/outputs): e5_previsoes.csv, e5_metricas.csv, e5_criterios.csv, e5_decisao.csv, e5_variantes.csv, e5_testes_painel.csv, e5_entes.csv, e5_diag_estimacao.csv,
# e5_diag_categorias.csv; linhas em experiments/registro.csv (status e5_v4, hash do commit do codigo).
source("R/utils_io.R", encoding = "UTF-8"); carregar_r("scripts/e5_dados.R")
carregar_r("R/evaluation/registro.R")
args <- commandArgs(TRUE); sem_m4 <- "--sem-m4" %in% args || "--rapida" %in% args; rapida <- "--rapida" %in% args
modelos <- if (sem_m4) c("M1", "M2", "M3") else c("M1", "M2", "M3", "M4")
saida <- function(x, nome) gravar_csv(x, dados(file.path("outputs", paste0("e5_", nome, ".csv"))))
D <- e5_montar(); base <- D$base
sh <- function(cmd) trimws(system(cmd, intern = TRUE))
commit <- sh("git rev-parse --short HEAD"); espec <- sh("git log -1 --format=%h -- docs/e5_especificacao.md")
cat(sprintf("E5: commit do codigo %s; commit da especificacao %s; modelos %s\n", commit, espec, paste(modelos, collapse = ",")))

rodar_tudo <- function(b, amostras, series, modelos, com_entes = TRUE) {
  pr <- list(); dg <- list()
  for (am in amostras) for (s in series) {
    r <- e5_rodar_serie(b, s, am, E5_AMOSTRAS[[am]], modelos, quieto = TRUE)
    pr[[length(pr) + 1]] <- r$pred; dg[[length(dg) + 1]] <- r$diag
    if (com_entes && s %in% E5_ALVOS) { ce <- e5_candidatos_entes(b, D$a6, s, am, E5_AMOSTRAS[[am]]); if (!is.null(ce)) pr[[length(pr) + 1]] <- ce }
    message(sprintf("  %s %s feito (%s)", s, am, format(Sys.time(), "%H:%M")))
  }
  list(pred = do.call(rbind, pr), diag = do.call(rbind, dg))
}

# ---- 1. totais (aceitacao) em A, S e S3; categorias (diagnostico) em A sem M4 ------------------------------------------------------------------
message("Totais...")
R1 <- rodar_tudo(base, c("A", "S", "S3"), E5_ALVOS, modelos)
message("Categorias (diagnostico)...")
R2 <- rodar_tudo(base, "A", E5_DIAG, c("M1", "M2", "M3"), com_entes = FALSE)
pred <- rbind(R1$pred, R2$pred); diag <- rbind(R1$diag, R2$diag)
saida(diag, "diag_estimacao")
nao_ok <- diag[diag$diag != "ok", ]; cat(sprintf("Celulas de estimacao sem previsao: %d de %d\n", nrow(nao_ok), nrow(diag)))

# ---- 2. criterios e aceitacao --------------------------------------------------------------------------------------------------------------------
erros <- function(p) e5_erros(p, base)
EA <- erros(pred)
cand <- c(modelos, "Ca", "Cb")
crit <- function(E, am, s, f, m) { x <- e5_criterios(E[E$amostra == am & E$serie == s & E$faixa == f, ], m); cbind(serie = s, amostra = am, faixa = f, x) }
CR <- list()
for (s in E5_ALVOS) for (f in names(E5_FAIXAS)) for (am in c("A", "S", "S3")) for (m in cand) {
  if (!any(EA$amostra == am & EA$serie == s & EA$faixa == f & EA$modelo == m)) next
  CR[[length(CR) + 1]] <- crit(EA, am, s, f, m)
}
CR <- do.call(rbind.data.frame, lapply(CR, function(z) z[, Reduce(intersect, lapply(CR, names))]))
decide <- function(CR) {
  a <- CR[CR$amostra == "A" & !is.na(CR$c1_rmse10), ]; s <- CR[CR$amostra == "S" & !is.na(CR$razao_rmse), c("serie", "faixa", "modelo", "razao_rmse")]
  names(s)[4] <- "razao_rmse_S"; a <- merge(a, s, by = c("serie", "faixa", "modelo"), all.x = TRUE)
  a$passa_A <- with(a, c1_rmse10 & c2_pares & c3_sinal & c4_vies & c5_boot)
  a$c6_S <- !is.na(a$razao_rmse_S) & a$razao_rmse_S <= 1
  a$aceito <- a$passa_A & a$c6_S
  a$status <- ifelse(a$aceito, "aceito", ifelse(a$passa_A, "ressalva_sombra", "sombra"))
  a
}
DEC <- decide(CR)

# ---- 3. M5 (media dos aceitos) e decisao oficial -------------------------------------------------------------------------------------------------
m5 <- list()
for (s in E5_ALVOS) for (f in names(E5_FAIXAS)) {
  ac <- DEC$modelo[DEC$serie == s & DEC$faixa == f & DEC$aceito]
  if (!length(ac)) next
  p <- pred[pred$serie == s & pred$faixa == f & pred$modelo %in% ac, ]
  g <- aggregate(logr_hat ~ serie + amostra + faixa + cod_ibge + exercicio + corte, p, mean); g$modelo <- "M5"; g$n_aceitos <- length(ac); m5[[length(m5) + 1]] <- g
}
if (length(m5)) {
  M5 <- do.call(rbind, m5); EM5 <- e5_erros(M5[, names(pred)], base)
  CR5 <- list()
  for (s in E5_ALVOS) for (f in names(E5_FAIXAS)) for (am in c("A", "S", "S3")) {
    b0 <- EA[EA$amostra == am & EA$serie == s & EA$faixa == f & EA$modelo == "B0", ]; e5m <- EM5[EM5$amostra == am & EM5$serie == s & EM5$faixa == f, ]
    if (!nrow(e5m)) next
    CR5[[length(CR5) + 1]] <- cbind(serie = s, amostra = am, faixa = f, e5_criterios(rbind(b0, e5m), "M5"))
  }
  CR5 <- do.call(rbind.data.frame, lapply(CR5, function(z) z[, Reduce(intersect, lapply(CR5, names))]))
  CRall <- rbind(CR, CR5[, names(CR)]); EA <- rbind(EA, EM5)
} else { CRall <- CR; CR5 <- NULL }
saida(CRall, "criterios")
DECall <- decide(CRall)
oficial <- do.call(rbind, lapply(split(DECall, interaction(DECall$serie, DECall$faixa)), function(d) {
  na <- sum(d$aceito & d$modelo != "M5"); m5ok <- any(d$modelo == "M5" & d$aceito) && na >= 2
  esc <- if (m5ok) "M5" else if (na >= 1) { x <- d[d$aceito & d$modelo != "M5", ]; x$modelo[which.min(x$RMSE_c)] } else "B0"
  data.frame(serie = d$serie[1], faixa = d$faixa[1], n_aceitos = na, oficial = esc, aceitos = paste(d$modelo[d$aceito & d$modelo != "M5"], collapse = "+"))
}))
saida(DECall, "decisao"); saida(oficial, "oficial")

# ---- 4. metricas, previsoes e registro -----------------------------------------------------------------------------------------------------------
MET <- e5_resumo(EA); saida(MET, "metricas")
MET_F <- e5_resumo(EA, c("serie", "amostra", "faixa", "modelo")); saida(MET_F, "metricas_faixa")
saida(pred[pred$serie %in% E5_ALVOS, ], "previsoes")
cat_diag <- MET_F[MET_F$serie %in% E5_DIAG, ]; saida(cat_diag, "diag_categorias")

# ---- 5. reporte dos entes (sem peso na aceitacao) -------------------------------------------------------------------------------------------------
a6 <- D$a6; fin <- a6[a6$periodo == 6, ]
ent <- list()
for (s in E5_ALVOS) {
  cel <- unique(EA[EA$serie == s & EA$amostra == "A" & EA$modelo == "B0", c("cod_ibge", "exercicio", "corte", "faixa")])
  w <- a6[a6$periodo %in% 1:5, ]; w$corte <- w$periodo
  w <- merge(w, fin[, c("cod_ibge", "exercicio", "rec_real", "caixa")], by = c("cod_ibge", "exercicio"), suffixes = c("", "_fin"))
  w <- merge(cel, w, by = c("cod_ibge", "exercicio", "corte"))
  if (s == "rec:total") { w$e_atual <- 100 * (w$prev_atual - w$rec_real_fin) / w$rec_real_fin; w$e_loa <- 100 * (w$prev_loa - w$rec_real_fin) / w$rec_real_fin }
  else { w$e_atual <- 100 * (w$dotacao - w$caixa_fin) / w$caixa_fin; w$e_loa <- NA_real_ }
  w <- w[is.finite(w$e_atual), ]
  of <- oficial$oficial[oficial$serie == s]; names(of) <- oficial$faixa[oficial$serie == s]
  for (f in names(E5_FAIXAS)) {
    x <- w[w$faixa == f, ]; mo <- EA[EA$amostra == "A" & EA$serie == s & EA$faixa == f & EA$modelo == of[[f]], ]
    k <- merge(x, mo[, c("cod_ibge", "exercicio", "corte", "e")], by = c("cod_ibge", "exercicio", "corte"))
    ent[[length(ent) + 1]] <- data.frame(serie = s, faixa = f, oficial = of[[f]], n = nrow(k), vies_ente_pct = mean(k$e_atual), rmse_ente_atual = sqrt(mean(k$e_atual^2)),
      rmse_ente_loa = if (all(is.na(k$e_loa))) NA_real_ else sqrt(mean(k$e_loa^2, na.rm = TRUE)), rmse_modelo_oficial = sqrt(mean(k$e^2)), ente_melhor = sqrt(mean(k$e_atual^2)) < sqrt(mean(k$e^2)))
  }
}
ENT <- do.call(rbind, ent); saida(ENT, "entes")

# ---- 6. testes de painel (informacao, nao decidem) -----------------------------------------------------------------------------------------------
TP <- list()
for (s in E5_ALVOS) for (f in names(E5_FAIXAS)) for (cc in E5_FAIXAS[[f]]) for (m in setdiff(unique(EA$modelo[EA$serie == s & EA$faixa == f & EA$amostra == "A"]), "B0")) {
  x <- EA[EA$amostra == "A" & EA$serie == s & EA$faixa == f & EA$corte == cc & EA$modelo %in% c("B0", m), ]
  cj <- merge(x[x$modelo == "B0", c("cod_ibge", "exercicio", "That", "T")], x[x$modelo == m, c("cod_ibge", "exercicio", "That")], by = c("cod_ibge", "exercicio"), suffixes = c("_0", "_1"))
  if (nrow(cj) < 30) next
  M <- function(v) { w <- reshape(cj[, c("cod_ibge", "exercicio", v)], idvar = "cod_ibge", timevar = "exercicio", direction = "wide"); w <- w[stats::complete.cases(w), ]; list(m = as.matrix(w[, -1]), uf = w$cod_ibge) }
  a0 <- M("That_0"); a1 <- M("That_1"); rr <- M("T")
  uf <- Reduce(intersect, list(a0$uf, a1$uf, rr$uf)); if (length(uf) < 10) next
  g <- function(z) z$m[match(uf, z$uf), , drop = FALSE]
  t1 <- tryCatch(pEPA::pool_av.S1.test(g(a0), g(a1), g(rr), loss.type = "SPE"), error = function(e) NULL)
  TP[[length(TP) + 1]] <- data.frame(serie = s, faixa = f, corte = cc, modelo = m, n_uf = length(uf), n_anos = ncol(g(rr)), S1_estat = if (is.null(t1)) NA else unname(t1$statistic), S1_p = if (is.null(t1)) NA else t1$p.value)
}
if (length(TP)) saida(do.call(rbind, TP), "testes_painel")

# ---- 7. variantes de robustez (amostra A; M1-M3 e entes; sem M4) -----------------------------------------------------------------------------------
if (!"--sem-variantes" %in% args && !rapida) {
  VA <- list()
  var_def <- list(sem_RJ = function(b) b[b$cod_ibge != 33L, ], sem_RS = function(b) b[b$cod_ibge != 43L, ],
                  sem_conceito_original = function(b) { k <- paste(b$cod_ibge, b$exercicio) %in% paste(D$uf_conceito_original$cod_ibge, D$uf_conceito_original$exercicio); b[!(k & b$serie == "rec:total"), ] })
  for (v in names(var_def)) {
    bv <- var_def[[v]](base); message("Variante ", v)
    rv <- rodar_tudo(bv, "A", E5_ALVOS, c("M1", "M2", "M3"))
    Ev <- e5_erros(rv$pred, bv)
    for (s in E5_ALVOS) for (f in names(E5_FAIXAS)) for (m in c("M1", "M2", "M3", "Ca", "Cb")) {
      x <- Ev[Ev$serie == s & Ev$faixa == f, ]; if (!any(x$modelo == m)) next
      cr <- e5_criterios(x, m); VA[[length(VA) + 1]] <- cbind(variante = v, serie = s, faixa = f, cr[, c("modelo", "n", "razao_rmse", "c1_rmse10", "c2_pares", "c3_sinal", "c4_vies", "prob_boot", "c5_boot")])
    }
  }
  saida(do.call(rbind, VA), "variantes")
}

# ---- 8. registro (experiments/registro.csv) -------------------------------------------------------------------------------------------------------
if (!"--sem-registro" %in% args && !rapida) {
  MT <- MET[MET$serie %in% E5_ALVOS & MET$amostra %in% c("A", "S"), ]
  for (k in unique(paste(MT$serie, MT$amostra, MT$faixa, MT$modelo, sep = "|"))) {
    p <- strsplit(k, "|", fixed = TRUE)[[1]]; x <- MT[MT$serie == p[1] & MT$amostra == p[2] & MT$faixa == p[3] & MT$modelo == p[4], ]
    x$modelo <- paste("e5", p[1], p[3], p[4], sep = "_")
    registrar_experimento(x, x$modelo[1], sprintf("unidade=pct_total_anual;espec=%s", espec), p[2], commit, status = "e5_v4")
  }
}
cat("\n==== Decisao por serie x faixa ====\n"); print(oficial, row.names = FALSE)
cat("\n==== Criterios (amostra A) ====\n")
print(transform(DECall[, c("serie", "faixa", "modelo", "n", "razao_rmse", "share_uf_ano", "share_anos", "prob_boot", "razao_rmse_S", "status")], razao_rmse = round(razao_rmse, 3), share_uf_ano = round(share_uf_ano, 2), share_anos = round(share_anos, 2), prob_boot = round(prob_boot, 2), razao_rmse_S = round(razao_rmse_S, 3)), row.names = FALSE)
