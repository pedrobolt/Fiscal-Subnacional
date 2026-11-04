# E5.0: relatorio de anos-alvo, quebra RJ/PR/RS (despesa total e primario, serie COM RPPS), receita do RS COM x SEM e calibracao de poder.
# Criterios fixados antes de computar: docs/e5_0_criterios.md (commit 975865e). Nenhum modelo do E5; so o benchmark B0 (SRW na razao) para os erros.
# Uso: LC_ALL=C.UTF-8 Rscript scripts/e5_0_relatorio.R  (precisa do bruto local do RREO estados; guarda cache dos fluxos em outputs/cache_fluxos_{com,sem}.rds)
source("R/utils_io.R", encoding = "UTF-8")
carregar_r(c("R/download/snapshots.R", "R/download/siconfi_rreo.R", "R/transform/rreo.R", "R/transform/dicionario_contas.R", "R/quality/alertas.R"))
dir.create(dados("outputs"), showWarnings = FALSE)
cache <- function(v, dic, dc) {
  f <- dados(sprintf("outputs/cache_fluxos_%s.rds", v))
  if (file.exists(f)) return(readRDS(f))
  rreo <- ler_rreo_pasta(dados("data/raw/rreo"), "E"); x <- fluxos_a6_categorias(rreo, dic, dc); saveRDS(x, f); x
}
dic <- ler_dicionario("data/dicionario_contas_estados.csv"); dc <- ler_dicionario("data/dicionario_colunas_estados.csv")
dic_sem <- dic; dic_sem$papel[dic_sem$anexo == "RREO-Anexo 06" & dic_sem$rpps %in% "incluido"] <- "memo_rpps"
fl <- cache("com", dic, dc); fs <- cache("sem", dic_sem, dc)
UF3 <- c(RJ = 33L, PR = 41L, RS = 43L)
tot <- function(x, pref, nome) { y <- x[grepl(pref, x$serie), ]; a <- aggregate(valor ~ cod_ibge + exercicio + periodo, y, sum); a$serie <- nome; a[, names(x)[names(x) %in% names(a)]] }
mk <- function(x) { x <- x[, c("cod_ibge", "serie", "exercicio", "periodo", "valor")]; rbind(x, tot(x, "^rec:", "rec:total"), tot(x, "^desp:", "desp:total")) }
P <- mk(fl); PS <- mk(fs)

# ---- 1. anos-alvo ----------------------------------------------------------------------------------------------------------------------------------
valida <- function(P) {   # uma linha por UF-serie-ano: status e razoes r_b (b = 1..5)
  P <- P[!is.na(P$valor) & P$periodo %in% 1:6, ]
  ch <- split(P, list(P$cod_ibge, P$serie, P$exercicio), drop = TRUE)
  out <- lapply(ch, function(d) {
    v <- rep(NA_real_, 6); v[d$periodo] <- d$valor
    r <- rep(NA_real_, 5); st <- "valido"
    if (anyNA(v)) st <- "sem_b6_ou_bimestre_vazio" else {
      ac <- cumsum(v); rest <- ac[6] - ac[1:5]
      if (any(ac[1:5] <= 0) || any(rest <= 0)) st <- "nao_positivo" else r <- rest / ac[1:5]
    }
    data.frame(cod_ibge = d$cod_ibge[1], serie = d$serie[1], exercicio = d$exercicio[1], status = st, r1 = r[1], r2 = r[2], r3 = r[3], r4 = r[4], r5 = r[5])
  })
  do.call(rbind, out)
}
V <- valida(P); rownames(V) <- NULL
V <- V[V$exercicio <= 2025, ]; V <- V[order(V$cod_ibge, V$serie, V$exercicio), ]
alvos <- function(V, ano0, treino = 3L) {
  V <- V[V$exercicio >= ano0, ]; V$alvo <- FALSE
  for (k in unique(paste(V$cod_ibge, V$serie))) {
    i <- which(paste(V$cod_ibge, V$serie) == k); d <- V[i, ]
    ok <- d$status == "valido"; prev <- c(NA, d$exercicio[-nrow(d)])
    for (j in seq_len(nrow(d))) if (ok[j] && j > 1 && ok[j - 1] && prev[j] == d$exercicio[j] - 1L && sum(ok[seq_len(j - 1)]) >= treino) V$alvo[i[j]] <- TRUE
  }
  V
}
esc <- list(R1 = list(pref = "^rec:", ano0 = 2015L), R2 = list(pref = "^rec:", ano0 = 2019L), D1 = list(pref = "^desp:", ano0 = 2018L))
res <- list(); perda <- list(); AL <- list()
for (e in names(esc)) {
  x <- alvos(V[grepl(esc[[e]]$pref, V$serie), ], esc[[e]]$ano0); AL[[e]] <- x
  f <- function(d, rotulo) data.frame(escolha = e, amostra = rotulo, serie = d$serie[1], anos_alvo = length(unique(d$exercicio[d$alvo])), uf_anos = sum(d$alvo))
  for (s in unique(x$serie)) {
    d <- x[x$serie == s, ]; res[[length(res) + 1]] <- f(d, "todos"); res[[length(res) + 1]] <- f(d[!d$exercicio %in% 2020:2022, ], "sem 2020-22")
  }
  xt <- x[x$serie %in% c("rec:total", "desp:total"), ]; perda[[e]] <- data.frame(escolha = e, as.data.frame(table(status = xt$status, serie = xt$serie), stringsAsFactors = FALSE))
}
R <- do.call(rbind, res); gravar_csv(R, dados("outputs/e5_0_anos_alvo.csv")); gravar_csv(do.call(rbind, perda), dados("outputs/e5_0_perdas.csv"))
cat("==== 1. Anos-alvo e UF-anos efetivos (serie COM RPPS) ====\n")
print(reshape(R[R$serie %in% c("rec:total", "desp:total", "rec:ICMS", "rec:IPVA", "rec:FPE/FPM", "rec:demais receitas", "desp:pessoal", "desp:custeio", "desp:investimento"), ], idvar = c("escolha", "serie"), timevar = "amostra", direction = "wide"), row.names = FALSE)
cat("\nStatus dos UF-anos (receita total / despesa total), por escolha:\n"); print(do.call(rbind, perda), row.names = FALSE)

# ---- 2. quebra RJ/PR/RS 2025 (despesa total, receita total, primario; pessoal COM e SEM como controles) -----------------------------------------
flux <- function(P, s) { x <- P[P$serie == s, c("cod_ibge", "exercicio", "periodo", "valor")]; names(x)[4] <- s; x }
base <- Reduce(function(a, b) merge(a, b, by = c("cod_ibge", "exercicio", "periodo"), all = TRUE),
               list(flux(P, "rec:total"), flux(P, "desp:total"), flux(P, "desp:pessoal"), setNames(flux(PS, "desp:pessoal"), c("cod_ibge", "exercicio", "periodo", "pessoal_sem"))))
base$primario <- base$`rec:total` - base$`desp:total`; base$m <- base$primario / base$`rec:total`
base <- base[base$exercicio >= 2023, ]; base$idx <- base$exercicio * 6L + base$periodo
ant <- base[, c("cod_ibge", "idx", "rec:total", "desp:total", "desp:pessoal", "pessoal_sem", "m")]; ant$idx <- ant$idx + 6L
b <- merge(base, ant, by = c("cod_ibge", "idx"), suffixes = c("", "_ant"))
b$yoy_receita <- b$`rec:total` / b$`rec:total_ant` - 1; b$yoy_despesa <- b$`desp:total` / b$`desp:total_ant` - 1
b$yoy_pessoal_com <- b$`desp:pessoal` / b$`desp:pessoal_ant` - 1; b$yoy_pessoal_sem <- b$pessoal_sem / b$pessoal_sem_ant - 1; b$dm <- b$m - b$m_ant
b <- b[b$idx >= 2024L * 6L + 1L & b$idx <= 2026L * 6L + 4L, ]
vars <- c(despesa = "yoy_despesa", receita = "yoy_receita", primario = "dm", pessoal_com = "yoy_pessoal_com", pessoal_sem = "yoy_pessoal_sem")
lim <- c(despesa = .20, receita = .20, primario = .10, pessoal_com = .20, pessoal_sem = .20)
desv <- function(b, v) {
  b$desvio <- NA_real_
  for (id in unique(b$idx)) {
    k <- b$idx == id; x <- b[k, ]; ref <- x$cod_ibge[!x$cod_ibge %in% UF3]
    b$desvio[k] <- vapply(seq_len(nrow(x)), function(i) median(x[[v]][x$cod_ibge %in% setdiff(ref, x$cod_ibge[i])], na.rm = TRUE), 0)
    b$desvio[k] <- x[[v]] - b$desvio[k]
  }
  b
}
corridas <- function(d, limite, abs_ = FALSE) {   # d: cod_ibge, idx, desvio; devolve inicio e tamanho das corridas >= 2 bimestres consecutivos
  d <- d[order(d$cod_ibge, d$idx), ]; out <- list()
  for (u in unique(d$cod_ibge)) {
    x <- d[d$cod_ibge == u, ]; f <- if (abs_) abs(x$desvio) >= limite else x$desvio >= limite; f[is.na(f)] <- FALSE
    i <- 1
    while (i <= nrow(x)) if (f[i]) { j <- i; while (j < nrow(x) && f[j + 1] && x$idx[j + 1] == x$idx[j] + 1L) j <- j + 1L
      if (j - i + 1 >= 2) out[[length(out) + 1]] <- data.frame(cod_ibge = u, idx_ini = x$idx[i], n_bim = j - i + 1, desvio_medio = mean(x$desvio[i:j])); i <- j + 1 } else i <- i + 1
  }
  if (length(out)) do.call(rbind, out) else data.frame(cod_ibge = integer(0), idx_ini = integer(0), n_bim = integer(0), desvio_medio = numeric(0))
}
rotulo <- function(idx) sprintf("%d b%d", (idx - 1L) %/% 6L, (idx - 1L) %% 6L + 1L)
Q <- list(); FP <- list()
cat("\n==== 2. Quebra em 2025+ (desvio contra a mediana das outras UFs): corridas de >= 2 bimestres ====\n")
for (n in names(vars)) {
  d <- desv(b, vars[[n]]); r <- corridas(d[, c("cod_ibge", "idx", "desvio")], lim[[n]], abs_ = (n == "primario")); r$variavel <- n; r$inicio <- rotulo(r$idx_ini)
  r3 <- r[r$cod_ibge %in% UF3 & r$idx_ini >= 2025L * 6L + 1L, ]; Q[[n]] <- r
  fp <- r[!r$cod_ibge %in% UF3, ]
  FP[[n]] <- data.frame(variavel = n, ufs_fora_com_corrida_2024mais = length(unique(fp$cod_ibge)), ufs_fora_com_corrida_inicio_2025mais = length(unique(fp$cod_ibge[fp$idx_ini >= 2025L * 6L + 1L])), de = 24L)
  cat(sprintf("\n-- %s (limite %s p.p.): RJ/PR/RS com corrida iniciada em 2025+ --\n", n, lim[[n]] * 100))
  if (nrow(r3)) print(transform(r3[, c("cod_ibge", "inicio", "n_bim", "desvio_medio")], desvio_medio = round(100 * desvio_medio, 1)), row.names = FALSE) else cat("nenhuma\n")
}
Qa <- do.call(rbind, Q); gravar_csv(Qa, dados("outputs/e5_0_quebra_corridas.csv")); FPa <- do.call(rbind, FP); gravar_csv(FPa, dados("outputs/e5_0_quebra_falsos_positivos.csv"))
cat("\nFalsos positivos: UFs fora de RJ/PR/RS (24) com alguma corrida na janela 2024 b1+ / com inicio em 2025+\n"); print(FPa, row.names = FALSE)
gravar_csv(b, dados("outputs/e5_0_quebra_yoy.csv"))

# ---- 2b. descritivo SEM limiar (ACRESCENTADO APOS VER O RESULTADO DE 2; nao estava em docs/e5_0_criterios.md) ---------------------------------------
# desvio medio dos 6 bimestres de 2025 contra a mediana das outras UFs e posto da UF entre as 27, para ler o tamanho sem depender do limiar.
dd <- list()
for (n in names(vars)) { d <- desv(b, vars[[n]]); d <- d[d$exercicio == 2025L, ]; m <- aggregate(desvio ~ cod_ibge, d, mean)
  m$posto_desc <- rank(-m$desvio); m$variavel <- n; m$sd_24ufs <- sd(m$desvio[!m$cod_ibge %in% UF3]); dd[[n]] <- m[m$cod_ibge %in% UF3, ] }
dd <- do.call(rbind, dd); dd$desvio_medio_2025_pp <- round(100 * dd$desvio, 1); dd$sd_24ufs_pp <- round(100 * dd$sd_24ufs, 1)
gravar_csv(dd, dados("outputs/e5_0_quebra_descritivo_2025.csv"))
cat("\n-- 2b. (descritivo, pos-resultado) desvio medio em 2025, p.p., posto entre 27 UFs (1 = maior) e desvio-padrao do desvio nas 24 UFs --\n")
print(dd[, c("variavel", "cod_ibge", "desvio_medio_2025_pp", "posto_desc", "sd_24ufs_pp")], row.names = FALSE)

# ---- 3. receita do RS, COM x SEM -----------------------------------------------------------------------------------------------------------------
rc <- merge(P[P$cod_ibge == 43L & grepl("^rec:", P$serie) & P$exercicio >= 2023, ], PS[PS$cod_ibge == 43L & grepl("^rec:", PS$serie) & PS$exercicio >= 2023, ],
            by = c("cod_ibge", "serie", "exercicio", "periodo"), suffixes = c("_com", "_sem"), all = TRUE)
rc$dif <- rc$valor_com - rc$valor_sem
tt <- aggregate(valor_com ~ exercicio + periodo, rc[rc$serie != "rec:total", ], sum); names(tt)[3] <- "rec_total_com"
rc <- merge(rc, tt, by = c("exercicio", "periodo")); rc$dif_pct_receita <- rc$dif / rc$rec_total_com
gravar_csv(rc, dados("outputs/e5_0_rs_receita_com_sem.csv"))
cat("\n==== 3. RS: receita COM - SEM (R$ mi) por categoria e ano; % da receita total COM ====\n")
ra <- aggregate(cbind(dif, rec_total_com) ~ serie + exercicio, rc[rc$serie != "rec:total", ], sum); ra$dif_mi <- round(ra$dif / 1e6, 1); ra$pct <- round(100 * ra$dif / ra$rec_total_com, 2)
print(reshape(ra[abs(ra$dif) > 0, c("serie", "exercicio", "dif_mi")], idvar = "serie", timevar = "exercicio", direction = "wide"), row.names = FALSE)
cat("\nPor bimestre (categoria com diferenca), % da receita total:\n"); w <- rc[abs(rc$dif) > 0 & rc$serie != "rec:total", ]
print(reshape(transform(w, p = round(100 * dif_pct_receita, 2))[, c("serie", "exercicio", "periodo", "p")], idvar = c("serie", "exercicio"), timevar = "periodo", direction = "wide"), row.names = FALSE)

# ---- 4. calibracao de poder (benchmark B0: SRW na razao) -----------------------------------------------------------------------------------------
erros <- function(x, s) {   # x: V com alvo; erro = log r(t-1) - log r(t), cortes 1..5
  d <- x[x$serie == s & x$alvo, ]; out <- list()
  for (i in seq_len(nrow(d))) { a <- x[x$cod_ibge == d$cod_ibge[i] & x$serie == s & x$exercicio == d$exercicio[i] - 1L, ]
    out[[i]] <- data.frame(exercicio = d$exercicio[i], corte = 1:5, e = log(unlist(a[1, paste0("r", 1:5)])) - log(unlist(d[i, paste0("r", 1:5)]))) }
  do.call(rbind, out)
}
set.seed(20261104)
SER <- list(list("R1", "rec:total"), list("D1", "desp:total"), list("R1", "rec:ICMS"), list("D1", "desp:pessoal"))
rm_tab <- list(); pw <- list()
for (s in SER) {
  er <- erros(AL[[s[[1]]]], s[[2]]); er$ok <- TRUE
  rm_tab[[length(rm_tab) + 1]] <- cbind(escolha = s[[1]], serie = s[[2]], aggregate(e ~ corte, er, function(z) sqrt(mean(z^2))))
  anos <- split(er$e, er$exercicio); sig <- sqrt(mean(er$e^2)); pool <- er$e / sig
  for (T in c(3, 4, 5, 8, 12)) for (rho in c(.5, .8)) {
    rej <- replicate(2000, { y <- sample(names(anos), T, replace = TRUE); d <- vapply(y, function(a) { eb <- anos[[a]]; z <- sample(pool, length(eb), replace = TRUE)
      ec <- 0.9 * sig * (rho * eb / sig + sqrt(1 - rho^2) * z); mean(eb^2 - ec^2) }, 0)
      sd(d) > 0 && mean(d) / (sd(d) / sqrt(T)) > qt(.95, T - 1) })
    pw[[length(pw) + 1]] <- data.frame(escolha = s[[1]], serie = s[[2]], anos_alvo_disponiveis = length(anos), T = T, rho = rho, poder = mean(rej))
  }
}
RM <- do.call(rbind, rm_tab); names(RM)[4] <- "rmse_b0_log"; gravar_csv(RM, dados("outputs/e5_0_rmse_b0.csv")); PW <- do.call(rbind, pw); gravar_csv(PW, dados("outputs/e5_0_poder.csv"))
cat("\n==== 4. RMSE do B0 (log da razao) por corte ====\n"); print(transform(RM, rmse_b0_log = round(rmse_b0_log, 3)), row.names = FALSE)
cat("\nPoder (RMSE do candidato 10% menor, teste t por ano, unilateral 5%)\n"); print(reshape(transform(PW, poder = round(poder, 2))[, c("escolha", "serie", "anos_alvo_disponiveis", "T", "rho", "poder")], idvar = c("escolha", "serie", "anos_alvo_disponiveis", "rho"), timevar = "T", direction = "wide"), row.names = FALSE)
