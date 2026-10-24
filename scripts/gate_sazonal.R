# Gate pré-E4: (a) SRW no BCB; (b) ganho do primário RREO dos estados. Uso: Rscript scripts/gate_sazonal.R [--registrar]
# Escreve outputs/gate_*.csv e, com --registrar, acrescenta ao experiments/registro.csv.
invisible(lapply(list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE), source))
registrar <- "--registrar" %in% commandArgs(TRUE)
commit <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) NA_character_)
ultimo <- function(cod) { f <- sort(list.files("data/raw", sprintf("^bcb_sgs_%d_.*\\.json$", cod), full.names = TRUE)); f[length(f)] }
ser <- function(cod) { s <- ler_sgs(ultimo(cod)); primario_bi(s[s$data >= SGS_INICIO_ANALISE, ]) }
reg <- ser(4642); est <- ser(4643); mun <- ser(4644)
dir.create("outputs", showWarnings = FALSE)

# (a) SRW no BCB regional: amostra 2016-2025 e amostra longa (2003-2025, comum a j=5) por subperíodo
mods_a <- list(naive = function(s, t, m) prever_naive(s, t, m),
               acumulado_j5 = function(s, t, m) prever_acumulado(s, t, m, 5),
               srw = function(s, t, m) prever_srw(s, t, m))
bt_a <- do.call(rbind, lapply(names(mods_a), function(n) {
  b <- rodar_backtest(reg, anos = 2003:2025, modelos = list(x = function(s, t, m) mods_a[[n]](s, t, m))); b$modelo <- n; b }))
amostras_a <- list("2016-2025" = 2016:2025, "2003-2025" = 2003:2025, "2003-2015" = 2003:2015, "2016-2019" = 2016:2019, "2020-2025" = 2020:2025)
res_a <- do.call(rbind, lapply(names(amostras_a), function(a) cbind(amostra = a, resumir_erros(bt_a[bt_a$ano %in% amostras_a[[a]], ]))))
utils::write.csv(res_a, "outputs/gate_a_srw_bcb.csv", row.names = FALSE)

# (b) RREO dos estados -> BCB (estaduais e regionais); anos-alvo 2018-2025, mas a amostra pareada efetiva é 2020-2025 (2018: RS sem Anexo 6 b1-5; 2019 precisa de 2018)
rreo <- ler_rreo_pasta("data/raw/rreo", "E")
x <- rreo_primario_estados(rreo)
cat("RREO estados: anos", range(x$ano), "| bimestres completos (27 UFs):", sum(!is.na(x$valor_bi)), "de", nrow(x), "\n")
res_b <- list(); bts <- list()
for (alvo in c("estaduais", "regionais")) {
  bt <- backtest_modelos(modelos_gate(alvo, est, mun, x), if (alvo == "estaduais") est else reg, anos = 2018:2025, cortes = 3:11)
  bts[[alvo]] <- bt
  res_b[[alvo]] <- cbind(alvo = alvo, resumo_vs_srw(bt))
}
res_b <- do.call(rbind, res_b)
utils::write.csv(res_b, "outputs/gate_b_rreo_vs_srw.csv", row.names = FALSE)
utils::write.csv(do.call(rbind, lapply(names(bts), function(a) cbind(alvo = a, bts[[a]]))), "outputs/gate_b_backtest.csv", row.names = FALSE)

if (registrar) {
  for (a in names(amostras_a)) for (n in names(mods_a)) {
    r <- res_a[res_a$amostra == a, ]
    registrar_experimento(r, n, if (n == "srw") "janela=1;alvo=regionais" else if (n == "acumulado_j5") "janela=5;alvo=regionais" else "alvo=regionais", a, commit)
  }
  for (alvo in c("estaduais", "regionais")) for (n in setdiff(unique(res_b$modelo), "srw")) {
    r <- res_b[res_b$alvo == alvo, ]
    registrar_experimento(r, n, sprintf("alvo=%s;cortes=3-11;rreo=estados", alvo), "2020-2025", commit)
  }
  for (alvo in c("estaduais", "regionais"))
    registrar_experimento(res_b[res_b$alvo == alvo, ], "srw", sprintf("janela=1;alvo=%s;cortes=3-11", alvo), "2020-2025", commit)
}
