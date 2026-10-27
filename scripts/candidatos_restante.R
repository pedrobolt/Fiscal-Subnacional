# Candidatos do restante do ano em % do PIB (E3.4/E4). Uso: Rscript scripts/candidatos_restante.R [--registrar]
# Saídas: outputs/restante_*.csv. Não faz chamadas à API do Siconfi (usa só o BCB baixado e o RREO local dos estados).
invisible(lapply(list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE), source))
registrar <- "--registrar" %in% commandArgs(TRUE)
commit <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) NA_character_)
ultimo <- function(cod) { f <- sort(list.files("data/raw", sprintf("^bcb_sgs_%d_.*\\.json$", cod), full.names = TRUE)); f[length(f)] }
ser <- function(cod) { s <- ler_sgs(ultimo(cod)); primario_bi(s[s$data >= SGS_INICIO_ANALISE, ]) }
reg <- ser(4642); est <- ser(4643)
pib <- pib_anual(ler_sgs(ultimo(SGS_PIB)))
dir.create("outputs", showWarnings = FALSE)

painel <- painel_restante(reg, pib)
anos_alvo <- 2007:2025   # 8 anos de treino mínimo a partir de 1999
amostras <- list("2007-2025" = integer(0), "2007-2025 sem 2020-22" = ANOS_PANDEMIA)
resumos <- list(); bts <- list()
for (a in names(amostras)) {
  bt <- backtest_restante(painel, anos_alvo, excluir = amostras[[a]])
  # Referência: SRW em R$ (sem normalizar pelo PIB)
  ref <- do.call(rbind, lapply(sort(unique(painel$corte)), function(m) do.call(rbind, lapply(setdiff(anos_alvo, amostras[[a]]), function(t) {
    al <- painel[painel$corte == m & painel$ano == t, ]; prev <- prever_srw(reg, t, m)
    data.frame(ano = t, corte = m, modelo = "srw_brl", previsao = prev, realizado = al$Y, erro = prev - al$Y, erro_pp = (prev - al$Y) / al$pib * 100, pib = al$pib) }))))
  bt <- rbind(bt, ref)
  bts[[a]] <- cbind(amostra = a, bt)
  resumos[[a]] <- cbind(amostra = a, resumir_restante(bt))
}
res <- do.call(rbind, resumos)
utils::write.csv(res, "outputs/restante_resumo.csv", row.names = FALSE)
utils::write.csv(do.call(rbind, bts), "outputs/restante_backtest.csv", row.names = FALSE)

# Diagnóstico de tendência (o coeficiente do acumulado capta o declive 2004-2025?), corte ago (8), amostra completa e sem 2020-22
diag <- list()
for (ex in list(integer(0), ANOS_PANDEMIA)) {
  pm <- painel[painel$corte == 8 & painel$ano >= 1999 & !(painel$ano %in% ex), ]
  for (f in list(r ~ a + r_lag + E, r ~ a + r_lag + E + tend)) {
    s <- summary(stats::lm(f, data = pm))$coefficients
    diag[[length(diag) + 1]] <- data.frame(sem_2020_22 = length(ex) > 0, formula = paste(deparse(f), collapse = ""),
      termo = rownames(s), coef = s[, 1], p = s[, 4], n = nrow(pm))
  }
}
diag <- do.call(rbind, diag); utils::write.csv(diag, "outputs/restante_diag_tendencia.csv", row.names = FALSE)
cat("cor(a_t, ano) no corte 8:", round(stats::cor(painel$a[painel$corte == 8], painel$ano[painel$corte == 8], use = "complete.obs"), 2), "\n")

# Candidato 4 (estados): indicativo
rreo <- ler_rreo_pasta("data/raw/rreo", "E")
pend <- pendencias_estados(rreo)
pe <- painel_restante(est, pib)
com_amostra <- function(nome, d) if (is.null(d) || nrow(d) == 0) NULL else cbind(amostra = nome, d)
c4 <- rbind(com_amostra("2019-2025", teste_pendencias(pe, pend)),
            com_amostra("2019-2025 sem 2020-22 (n<=4: sem validade)", teste_pendencias(pe, pend, ANOS_PANDEMIA)))
utils::write.csv(c4, "outputs/restante_candidato4_estados.csv", row.names = FALSE)

if (registrar) {
  for (a in names(amostras)) for (n in setdiff(unique(res$modelo), character(0))) {
    r <- res[res$amostra == a, ]
    registrar_experimento(r, n, sprintf("restante;pib;alvo=regionais;min_treino=8;%s", if (n == "srw_brl") "R$" else "%PIB"), a, commit)
  }
}

# Previsão de 2026 no último corte disponível (apenas ilustrativa: a escolha do modelo sai do backtest por corte).
# PIB 2026: sem premissas.yml neste ambiente, usa-se o PIB acumulado em 12 meses mais recente do SGS 4382 como aproximação.
ult <- max(reg$data[format(reg$data, "%Y") == "2026"]); mcorte <- as.integer(format(ult, "%m"))
sg <- ler_sgs(ultimo(SGS_PIB)); pib26 <- sg$valor[nrow(sg)] / 1000
pib2 <- rbind(pib, data.frame(ano = 2026, pib_bi = pib26))
reg26 <- reg
pn <- painel_restante(reg, pib2, cortes = mcorte)
al <- data.frame(ano = 2026, corte = mcorte, A = soma_meses(reg, 2026, 1:mcorte), R = NA_real_, Y = NA_real_, pib = pib26)
al$a <- al$A / pib26; al$r <- NA_real_
Rl <- soma_meses(reg, 2025, (mcorte + 1):12); al$r_lag <- Rl / pib$pib_bi[pib$ano == 2025]
al$E <- 1L; al$Emun <- 0L; al$tend <- 26
pn <- rbind(pn[pn$ano != 2026, ], al)
prev26 <- do.call(rbind, lapply(c("srw_pib", "m2", "m3", "m3_tend", "m3_jan10"), function(n) {
  do.call(rbind, lapply(list(com_2020_22 = integer(0), sem_2020_22 = ANOS_PANDEMIA), function(ex) {
    rh <- prever_restante(pn, 2026, ESPEC_RESTANTE[[n]], ex)
    data.frame(modelo = n, treino = if (length(ex)) "sem 2020-22" else "com 2020-22", corte = mcorte,
               acumulado_bi = al$A, total_previsto_bi = al$A + rh * pib26) })) }))
prev26 <- rbind(prev26, data.frame(modelo = "srw_brl", treino = "-", corte = mcorte, acumulado_bi = al$A, total_previsto_bi = prever_srw(reg, 2026, mcorte)))
utils::write.csv(prev26, "outputs/restante_previsao_2026.csv", row.names = FALSE)
cat("2026: dados até mês", mcorte, "| PIB 2026 aprox.", round(pib26), "\n"); print(prev26, row.names = FALSE)
