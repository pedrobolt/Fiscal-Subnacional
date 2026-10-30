# Continuidade da serie com RPPS por UF (E3.6). Criterio fixado em docs/nota_gap.md, secao 5.4, antes do calculo.

#' Razao resultado/receita por UF x ano, versao com RPPS. 2022 e anteriores: soma dos 6 bimestres de `primario_a6` e `rec_total` do conceito
#' unico (Anexo 6 original, que inclui o RPPS); 2023 em diante: XXXIV (VALOR) / XVI (RECEITAS REALIZADAS (a)) do 6o bimestre. Devolve tambem
#' R = XXXIV - XXXV (com - sem RPPS) em 2023+ e a receita usada.
#' `a6`: RREO Anexo 6, 6o bimestre (saida de `ler_rreo_pasta()`); `cu`: cod_ibge, exercicio, periodo, rec_total, primario_a6.
razao_com_rpps <- function(a6, cu) {
  pre <- do.call(rbind, lapply(split(cu, paste(cu$cod_ibge, cu$exercicio)), function(z) {
    ok <- nrow(z) == 6L && !anyNA(z$primario_a6) && !anyNA(z$rec_total)
    data.frame(cod_ibge = z$cod_ibge[1], exercicio = z$exercicio[1], resultado = if (ok) sum(z$primario_a6) else NA_real_,
               receita = if (ok) sum(z$rec_total) else NA_real_, R = NA_real_)
  }))
  pre <- pre[pre$exercicio <= 2022, ]
  a <- a6[a6$exercicio >= 2023 & a6$periodo == 6L, ]
  a <- a[order(a$cod_ibge, a$exercicio, a$cod_conta, a$coluna, a$baixado_em), ]
  a <- a[!duplicated(a[, c("cod_ibge", "exercicio", "cod_conta", "coluna")], fromLast = TRUE), ]
  pega <- function(conta, col) { x <- a[a$cod_conta == conta & a$coluna == col, ]; setNames(x$valor, paste(x$cod_ibge, x$exercicio)) }
  com <- pega("ResultadoPrimarioComRPPSAcimaDaLinha", "VALOR"); sem <- pega("ResultadoPrimarioSemRPPSAcimaDaLinha", "VALOR")
  rec <- pega("RREO6TotalReceitaPrimaria", "RECEITAS REALIZADAS (a)")
  k <- names(com); p <- strsplit(k, " ")
  pos <- data.frame(cod_ibge = as.integer(sapply(p, `[`, 1)), exercicio = as.integer(sapply(p, `[`, 2)), resultado = unname(com[k]),
                    receita = unname(rec[k]), R = unname(com[k] - sem[k]))
  d <- rbind(pre, pos); d$razao <- d$resultado / d$receita; d$x <- d$R / d$receita
  d[order(d$exercicio, d$cod_ibge), ]
}

#' Regressao MQO delta ~ x com erros-padrao HC3 e IC de 95% (t, n - 2 g.l.). delta_i = razao_ano - razao_2022; x_i = R_i / receita_i do ano.
continuidade_regressao <- function(d, ano, base = 2022L) {
  a <- d[d$exercicio == ano, c("cod_ibge", "razao", "x")]; b <- d[d$exercicio == base, c("cod_ibge", "razao")]
  m <- merge(a, b, by = "cod_ibge", suffixes = c("", "_base")); m <- m[stats::complete.cases(m), ]
  y <- m$razao - m$razao_base; X <- cbind(1, m$x); n <- nrow(m)
  XtXi <- solve(crossprod(X)); beta <- XtXi %*% crossprod(X, y); e <- as.vector(y - X %*% beta)
  h <- rowSums((X %*% XtXi) * X)
  V <- XtXi %*% crossprod(X * (e / (1 - h)), X * (e / (1 - h))) %*% XtXi
  se <- sqrt(V[2, 2]); tc <- stats::qt(0.975, n - 2L)
  data.frame(ano = ano, base = base, n = n, inclinacao = beta[2], se_hc3 = se, ic_inf = beta[2] - tc * se, ic_sup = beta[2] + tc * se,
             intercepto = beta[1], r2 = 1 - sum(e^2) / sum((y - mean(y))^2))
}

#' Decisao pelo IC: 0 dentro e 1 fora = continua; 1 dentro e 0 fora = nao_continua; resto = inconclusivo.
decidir_continuidade <- function(ic_inf, ic_sup) {
  d0 <- ic_inf <= 0 & 0 <= ic_sup; d1 <- ic_inf <= 1 & 1 <= ic_sup
  ifelse(d0 & !d1, "continua", ifelse(d1 & !d0, "nao_continua", "inconclusivo"))
}
