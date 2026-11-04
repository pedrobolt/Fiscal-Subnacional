# E5 estados: descritivos POS-RESULTADO (nao fazem parte da aceitacao): erro por ano, cobertura do M4 e comparacao nas mesmas celulas, ablacao (so x1), PIP do BMS, testes de painel.
# Le outputs/e5_*.csv da rodada. Uso: LC_ALL=C.UTF-8 Rscript scripts/e5_relatorio.R
source("R/utils_io.R", encoding = "UTF-8"); carregar_r("scripts/e5_dados.R")
suppressPackageStartupMessages(library(BMS)); D <- e5_montar(); base <- D$base
o <- function(n) dados(file.path("outputs", paste0("e5_", n, ".csv")))
pred <- ler_csv(o("previsoes")); of <- ler_csv(o("oficial")); dec <- ler_csv(o("decisao"))
E <- e5_erros(pred[pred$amostra == "A", ], base)
# 1. RMSE por ano: B0 e cada modelo estimado, por serie x faixa
pa <- e5_resumo(E, c("serie", "faixa", "modelo", "exercicio")); pa$RMSE <- round(pa$RMSE, 2)
w <- reshape(pa[, c("serie", "faixa", "exercicio", "modelo", "RMSE")], idvar = c("serie", "faixa", "exercicio"), timevar = "modelo", direction = "wide")
gravar_csv(w, o("por_ano"))
# 2. M4: cobertura e comparacao nas mesmas celulas (UF-ano-corte em que o M4 convergiu)
m4 <- list()
for (s in E5_ALVOS) for (f in names(E5_FAIXAS)) {
  x <- E[E$serie == s & E$faixa == f, ]; k <- unique(x[x$modelo == "M4", c("cod_ibge", "exercicio", "corte")])
  if (!nrow(k)) next
  xk <- merge(x, k, by = c("cod_ibge", "exercicio", "corte")); tot <- unique(x[x$modelo == "B0", c("cod_ibge", "exercicio", "corte")])
  r0 <- tapply(xk$e, xk$modelo, function(z) sqrt(mean(z^2))); r <- setNames(rep(NA_real_, 5), c("B0", "M1", "M2", "M3", "M4")); r[names(r0)[names(r0) %in% names(r)]] <- r0[names(r0) %in% names(r)]
  m4[[length(m4) + 1]] <- data.frame(serie = s, faixa = f, celulas_B0 = nrow(tot), celulas_M4 = nrow(k), anos_M4 = length(unique(k$exercicio)), anos_B0 = length(unique(tot$exercicio)),
    t(round(r, 2)))
}
M4 <- do.call(rbind, m4); gravar_csv(M4, o("m4_celulas_comuns"))
# 3. Ablacao: M1 so com x1 (+corte) contra M1 completo, nas mesmas celulas (amostra A)
ab <- list()
for (s in E5_ALVOS) {
  b <- base[base$serie == s & complete.cases(base[, c("y", "x1", "x2")]), ]
  if (s == "desp:total") b <- b[complete.cases(b[, c("x3", "x4")]), ]
  for (f in names(E5_FAIXAS)) {
    bf <- b[b$corte %in% E5_FAIXAS[[f]], ]; pr <- list()
    for (t in sort(unique(bf$exercicio[bf$alvo]))) {
      tr <- bf[bf$exercicio < t, ]; al <- bf[bf$exercicio == t & bf$alvo, ]; if (nrow(tr) < 20 || !nrow(al)) next
      for (nm in c("so_x1", "x1_x2", "completo")) {
        tm <- switch(nm, so_x1 = "x1", x1_x2 = c("x1", "x2"), completo = e5_termos(s))
        yh <- e5_prever(tr, al, tm, "M1")$yhat
        pr[[length(pr) + 1]] <- data.frame(serie = s, amostra = "A", faixa = f, cod_ibge = al$cod_ibge, exercicio = t, corte = al$corte, modelo = nm, logr_hat = al$x1 + yh)
      }
    }
    pr <- do.call(rbind, pr); Eab <- e5_erros(pr, base); Eab <- Eab[order(Eab$cod_ibge, Eab$exercicio, Eab$corte), ]
    ab[[length(ab) + 1]] <- cbind(e5_resumo(Eab, c("serie", "faixa", "modelo"))[, c("serie", "faixa", "modelo", "n", "RMSE")])
  }
}
AB <- do.call(rbind, ab); AB$RMSE <- round(AB$RMSE, 2); gravar_csv(AB, o("ablacao"))
# 4. PIP do BMS (descritivo, amostra toda, por serie x faixa; sem 2020-21)
pip <- list()
for (s in E5_ALVOS) for (f in names(E5_FAIXAS)) {
  b <- base[base$serie == s & base$corte %in% E5_FAIXAS[[f]] & !base$exercicio %in% 2020:2021, ]
  tm <- setdiff(e5_termos(s), "x1"); tm <- c("x1", tm); b <- b[complete.cases(b[, c("y", tm)]), ]
  X <- b[, tm, drop = FALSE]; X <- X[, vapply(X, function(z) stats::var(z) > 0, logical(1)), drop = FALSE]
  if (length(unique(b$corte)) > 1) X$corte2 <- as.numeric(b$corte == max(b$corte))
  X[] <- lapply(X, function(z) if (length(unique(z)) > 2) as.numeric(scale(z)) else z)
  m <- tryCatch(BMS::bms(cbind(y = b$y, X), burn = 20000, iter = 50000, mprior = "uniform", user.int = FALSE), error = function(e) NULL)
  if (is.null(m)) next
  co <- coef(m); pip[[length(pip) + 1]] <- data.frame(serie = s, faixa = f, n = nrow(b), preditor = rownames(co), PIP = round(co[, "PIP"], 3))
}
gravar_csv(do.call(rbind, pip), o("pip_bms"))
cat("\n== RMSE por ano (B0, M1-M4) ==\n"); print(w, row.names = FALSE)
cat("\n== M4: celulas comuns ==\n"); print(M4, row.names = FALSE)
cat("\n== Ablacao (M1) ==\n"); print(AB, row.names = FALSE)
cat("\n== PIP BMS ==\n"); print(do.call(rbind, pip), row.names = FALSE)
cat("\n== Testes S1 do painel (p) ==\n"); tp <- ler_csv(o("testes_painel")); print(tp, row.names = FALSE, digits = 3)
