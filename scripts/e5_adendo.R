# E5 estados: adendo ao relatorio (05/11/2026), checagens pedidas antes de adotar. NAO muda as regras de aceitacao.
# (1) M5 sem M4 (decisao operacional pos-resultado); (a) B0' (SRW em R$) nas mesmas celulas; (b) variantes nas 3 celulas candidatas; (c) erro por ano.
# Le outputs/e5_previsoes.csv e e5_decisao.csv da rodada; as variantes sao reestimadas (M1-M3, rapido). Uso: LC_ALL=C.UTF-8 Rscript scripts/e5_adendo.R
source("R/utils_io.R", encoding = "UTF-8"); carregar_r("scripts/e5_dados.R")
D <- e5_montar(); base <- D$base
o <- function(n) dados(file.path("outputs", paste0("e5_", n, ".csv")))
pred <- ler_csv(o("previsoes")); dec <- ler_csv(o("decisao"))
SM <- c("M1", "M2", "M3")
acc <- dec[dec$aceito %in% c(TRUE, "TRUE") & dec$modelo %in% SM, c("serie", "faixa", "modelo")]   # aceitos sem M4 (Ca e Cb nao foram aceitos)
cel <- unique(acc[, c("serie", "faixa")])
f1 <- function(x, k = 2) formatC(x, format = "f", digits = k, decimal.mark = ",")
md_tab <- function(d) { d[] <- lapply(d, function(z) ifelse(is.na(z), "-", as.character(z))); c(paste0("| ", paste(names(d), collapse = " | "), " |"), paste0("|", paste(rep("---", ncol(d)), collapse = "|"), "|"), apply(d, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))) }
rot <- function(s) ifelse(grepl("^rec", s), "receita total", "despesa total")

m5s4 <- function(p, acc) {   # media dos aceitos (sem M4) em cada celula
  out <- list()
  for (i in seq_len(nrow(cel))) {
    ms <- acc$modelo[acc$serie == cel$serie[i] & acc$faixa == cel$faixa[i]]
    x <- p[p$serie == cel$serie[i] & p$faixa == cel$faixa[i] & p$modelo %in% ms, ]
    if (!nrow(x)) next
    g <- aggregate(logr_hat ~ serie + amostra + faixa + cod_ibge + exercicio + corte, x, mean); g$modelo <- "M5s4"; g$n_aceitos <- length(ms); out[[length(out) + 1]] <- g
  }
  do.call(rbind, out)
}
cand <- function(s, f) { n <- sum(acc$serie == s & acc$faixa == f); if (n >= 2) "M5s4" else acc$modelo[acc$serie == s & acc$faixa == f][1] }   # regra do protocolo: M5 se >= 2 aceitos

# ---- 1. M5 sem M4: criterios (A; razao em S) ----------------------------------------------------------------------------------------------------
M5 <- m5s4(pred, acc); P <- rbind(pred[, names(M5)[names(M5) != "n_aceitos"]], M5[, names(M5) != "n_aceitos"])
E <- e5_erros(P, base)
cr1 <- list()
for (i in seq_len(nrow(cel))) {
  s <- cel$serie[i]; f <- cel$faixa[i]; m <- cand(s, f)
  ca <- e5_criterios(E[E$amostra == "A" & E$serie == s & E$faixa == f, ], m); cs <- e5_criterios(E[E$amostra == "S" & E$serie == s & E$faixa == f, ], m)
  cr1[[i]] <- data.frame(serie = s, faixa = f, candidato = m, aceitos = paste(acc$modelo[acc$serie == s & acc$faixa == f], collapse = "+"), n = ca$n, razao_rmse = ca$razao_rmse, share_uf_ano = ca$share_uf_ano, share_anos = ca$share_anos,
    c1 = ca$c1_rmse10, c2 = ca$c2_pares, c3 = ca$c3_sinal, c4 = ca$c4_vies, prob_boot = ca$prob_boot, c5 = ca$c5_boot, razao_S = cs$razao_rmse, c6 = cs$razao_rmse <= 1)
  cr1[[i]]$aceito <- with(cr1[[i]], c1 & c2 & c3 & c4 & c5 & c6)
}
CR1 <- do.call(rbind, cr1); gravar_csv(CR1, o("adendo_m5_sem_m4"))

# ---- (a) B0' (SRW em R$ do P1: restante(t-1) nominal, mesmo corte) nas mesmas celulas ---------------------------------------------------------
bb <- base[, c("serie", "cod_ibge", "exercicio", "corte", "T_ant", "r_ant", "A")]; bb$R_ant <- bb$T_ant * bb$r_ant / (1 + bb$r_ant); bb$logr_p <- log(bb$R_ant / bb$A)
b0 <- P[P$modelo == "B0" & P$amostra == "A", c("serie", "amostra", "faixa", "cod_ibge", "exercicio", "corte")]
bp <- merge(b0, bb[, c("serie", "cod_ibge", "exercicio", "corte", "logr_p")], by = c("serie", "cod_ibge", "exercicio", "corte")); bp$modelo <- "B0p"; names(bp)[names(bp) == "logr_p"] <- "logr_hat"
PA <- rbind(P[P$amostra == "A", ], bp[, names(P)]); EA <- e5_erros(PA, base)
rm_ <- function(x) sqrt(mean(x$e^2))
ra <- list(); rc <- list(); cr_p <- list()
for (s in unique(EA$serie)) for (f in names(E5_FAIXAS)) {
  x <- EA[EA$serie == s & EA$faixa == f, ]; if (!any(x$modelo == "B0p")) next
  m <- if (nrow(cel[cel$serie == s & cel$faixa == f, ])) cand(s, f) else NA
  k <- unique(x[x$modelo == "B0", c("cod_ibge", "exercicio", "corte")]); k <- merge(k, unique(x[x$modelo == "B0p", c("cod_ibge", "exercicio", "corte")]))
  if (!is.na(m)) k <- merge(k, unique(x[x$modelo == m, c("cod_ibge", "exercicio", "corte")]))
  xk <- merge(x, k, by = c("cod_ibge", "exercicio", "corte"))
  r <- tapply(xk$e, xk$modelo, function(z) sqrt(mean(z^2)))
  ra[[length(ra) + 1]] <- data.frame(serie = s, faixa = f, n = nrow(k), candidato = ifelse(is.na(m), "-", m), RMSE_B0 = r[["B0"]], RMSE_B0p = r[["B0p"]], RMSE_cand = if (is.na(m)) NA else r[[m]])
  for (cc in E5_FAIXAS[[f]]) { xc <- xk[xk$corte == cc, ]; rr <- tapply(xc$e, xc$modelo, function(z) sqrt(mean(z^2)))
    rc[[length(rc) + 1]] <- data.frame(serie = s, corte = cc, RMSE_B0 = rr[["B0"]], RMSE_B0p = rr[["B0p"]], RMSE_cand = if (is.na(m)) NA else rr[[m]]) }
  if (!is.na(m)) { xx <- xk[xk$modelo %in% c("B0p", m), ]; xx$modelo[xx$modelo == "B0p"] <- "B0"; xx$modelo[xx$modelo == m] <- "cand"
    cp <- e5_criterios(xx, "cand"); cr_p[[length(cr_p) + 1]] <- data.frame(serie = s, faixa = f, candidato = m, razao_rmse_vs_B0p = cp$razao_rmse, share_uf_ano = cp$share_uf_ano, share_anos = cp$share_anos, prob_boot = cp$prob_boot, c3_sinal = cp$c3_sinal, c4_vies = cp$c4_vies) }
}
RA <- do.call(rbind, ra); RC <- do.call(rbind, rc); CP <- do.call(rbind, cr_p)
gravar_csv(RA, o("adendo_b0p_faixa")); gravar_csv(RC, o("adendo_b0p_corte")); gravar_csv(CP, o("adendo_b0p_criterios"))

# ---- (b) variantes nas tres celulas candidatas ---------------------------------------------------------------------------------------------------------
var_def <- list(sem_conceito_original = function(b) { k <- paste(b$cod_ibge, b$exercicio) %in% paste(D$uf_conceito_original$cod_ibge, D$uf_conceito_original$exercicio); b[!(k & b$serie == "rec:total"), ] },
                sem_RJ = function(b) b[b$cod_ibge != 33L, ], sem_RS = function(b) b[b$cod_ibge != 43L, ])
vr <- list()
for (v in names(var_def)) {
  bv <- var_def[[v]](base)
  pv <- do.call(rbind, lapply(unique(cel$serie), function(s) e5_rodar_serie(bv, s, "A", integer(0), SM, quieto = TRUE)$pred))
  Mv <- m5s4(pv, acc); Ev <- e5_erros(rbind(pv, Mv[, names(pv)]), bv)
  for (i in seq_len(nrow(cel))) {
    s <- cel$serie[i]; f <- cel$faixa[i]; x <- Ev[Ev$serie == s & Ev$faixa == f, ]
    for (m in unique(c(acc$modelo[acc$serie == s & acc$faixa == f], if (sum(acc$serie == s & acc$faixa == f) >= 2) "M5s4"))) {
      cr <- e5_criterios(x, m)
      vr[[length(vr) + 1]] <- data.frame(variante = v, serie = s, faixa = f, modelo = m, n = cr$n, razao_rmse = cr$razao_rmse, share_uf_ano = cr$share_uf_ano, share_anos = cr$share_anos,
        c1 = cr$c1_rmse10, c2 = cr$c2_pares, c3 = cr$c3_sinal, c4 = cr$c4_vies, prob_boot = cr$prob_boot, c5 = cr$c5_boot, passa_1a5 = cr$c1_rmse10 & cr$c2_pares & cr$c3_sinal & cr$c4_vies & cr$c5_boot)
    }
  }
}
VR <- do.call(rbind, vr); gravar_csv(VR, o("adendo_variantes"))

# ---- (c) erro por ano nas tres celulas ------------------------------------------------------------------------------------------------------------------
py <- list()
for (i in seq_len(nrow(cel))) {
  s <- cel$serie[i]; f <- cel$faixa[i]; m <- cand(s, f); x <- EA[EA$serie == s & EA$faixa == f & EA$modelo %in% c("B0", "B0p", m), ]
  k <- Reduce(merge, lapply(c("B0", "B0p", m), function(mm) unique(x[x$modelo == mm, c("cod_ibge", "exercicio", "corte")]))); xk <- merge(x, k, by = c("cod_ibge", "exercicio", "corte"))
  sse <- function(mm, a) sum(xk$e[xk$modelo == mm & xk$exercicio == a]^2)
  anos <- sort(unique(xk$exercicio)); dif <- vapply(anos, function(a) sse("B0", a) - sse(m, a), numeric(1))
  loo <- vapply(anos, function(a) { z <- xk[xk$exercicio != a, ]; sqrt(mean(z$e[z$modelo == m]^2)) / sqrt(mean(z$e[z$modelo == "B0"]^2)) }, numeric(1))
  py[[i]] <- data.frame(serie = s, faixa = f, candidato = m, exercicio = anos, n = vapply(anos, function(a) sum(xk$modelo == "B0" & xk$exercicio == a), integer(1)),
    RMSE_B0 = vapply(anos, function(a) sqrt(mean(xk$e[xk$modelo == "B0" & xk$exercicio == a]^2)), numeric(1)), RMSE_B0p = vapply(anos, function(a) sqrt(mean(xk$e[xk$modelo == "B0p" & xk$exercicio == a]^2)), numeric(1)),
    RMSE_cand = vapply(anos, function(a) sqrt(mean(xk$e[xk$modelo == m & xk$exercicio == a]^2)), numeric(1)), parcela_do_ganho = dif / sum(dif), razao_sem_o_ano = loo)
}
PY <- do.call(rbind, py); gravar_csv(PY, o("adendo_por_ano"))

# ---- Texto ------------------------------------------------------------------------------------------------------------------------------------------------

pyg <- function(s, f) PY[PY$serie == s & PY$faixa == f, ]
db5 <- pyg("desp:total", "b5"); r43 <- pyg("rec:total", "b3_b4"); r5 <- pyg("rec:total", "b5")
vp <- function(v, s, f, m) VR$passa_1a5[VR$variante == v & VR$serie == s & VR$faixa == f & VR$modelo == m]
vm <- function(m, s, f) paste(VR$variante[VR$serie == s & VR$faixa == f & VR$modelo == m & !VR$passa_1a5], collapse = ", ")
LEIT <- c("## Leitura", "",
  sprintf("1. **Os aceitos tambem batem o B0'** (SRW em R$, o do P1), com razao de RMSE de %s (receita b3-b4), %s (receita b5) e %s (despesa b5) e bootstrap por ano de %s, %s e %s.",
    f1(CP$razao_rmse_vs_B0p[CP$serie == "rec:total" & CP$faixa == "b3_b4"], 2), f1(CP$razao_rmse_vs_B0p[CP$serie == "rec:total" & CP$faixa == "b5"], 2), f1(CP$razao_rmse_vs_B0p[CP$serie == "desp:total"], 2),
    f1(CP$prob_boot[CP$serie == "rec:total" & CP$faixa == "b3_b4"], 2), f1(CP$prob_boot[CP$serie == "rec:total" & CP$faixa == "b5"], 2), f1(CP$prob_boot[CP$serie == "desp:total"], 2)),
  sprintf("2. **Instabilidade da razao:** na receita o B0 e o B0' ficam no mesmo nivel (RMSE %s e %s em b3-b4; %s e %s em b5), entao o ganho do candidato nao vem de a razao ser instavel. Na despesa b5 o B0 (%s) e bem pior que o B0' (%s): cerca de %s dos %s do ganho sobre o B0 e fraqueza da razao (concentrada em 2022: B0 %s contra B0' %s); o ganho sobre o B0' e de %s. Nos cortes iniciais da despesa o B0 e pior no corte 1 (%s contra %s do B0') mas melhor nos demais cortes de b1-b4.",
    f1(RA$RMSE_B0[RA$serie == "rec:total" & RA$faixa == "b3_b4"]), f1(RA$RMSE_B0p[RA$serie == "rec:total" & RA$faixa == "b3_b4"]), f1(RA$RMSE_B0[RA$serie == "rec:total" & RA$faixa == "b5"]), f1(RA$RMSE_B0p[RA$serie == "rec:total" & RA$faixa == "b5"]),
    f1(RA$RMSE_B0[RA$serie == "desp:total" & RA$faixa == "b5"]), f1(RA$RMSE_B0p[RA$serie == "desp:total" & RA$faixa == "b5"]),
    paste0(f1(100 * (1 - RA$RMSE_B0p[RA$serie == "desp:total" & RA$faixa == "b5"] / RA$RMSE_B0[RA$serie == "desp:total" & RA$faixa == "b5"]), 0), "%"), paste0(f1(100 * (1 - RA$RMSE_cand[RA$serie == "desp:total" & RA$faixa == "b5"] / RA$RMSE_B0[RA$serie == "desp:total" & RA$faixa == "b5"]), 0), "%"),
    f1(db5$RMSE_B0[db5$exercicio == 2022]), f1(db5$RMSE_B0p[db5$exercicio == 2022]), paste0(f1(100 * (1 - CP$razao_rmse_vs_B0p[CP$serie == "desp:total"]), 0), "%"),
    f1(RC$RMSE_B0[RC$serie == "desp:total" & RC$corte == 1]), f1(RC$RMSE_B0p[RC$serie == "desp:total" & RC$corte == 1])),
  sprintf("3. **Variantes:** receita b3-b4 segue aceita (criterios 1-5) em todas as variantes, M5 sem M4 e membros. Receita b5 **falha sem conceito_original** (M5 sem M4: razao %s, anos %s, bootstrap %s) e passa sem RJ e sem RS. Despesa b5 (M3) **falha sem o RS** (pares UF-ano %s, abaixo de 0,50; razao de RMSE %s) e passa nas outras duas.",
    f1(VR$razao_rmse[VR$variante == "sem_conceito_original" & VR$serie == "rec:total" & VR$faixa == "b5" & VR$modelo == "M5s4"], 3), f1(VR$share_anos[VR$variante == "sem_conceito_original" & VR$serie == "rec:total" & VR$faixa == "b5" & VR$modelo == "M5s4"]), f1(VR$prob_boot[VR$variante == "sem_conceito_original" & VR$serie == "rec:total" & VR$faixa == "b5" & VR$modelo == "M5s4"]),
    f1(VR$share_uf_ano[VR$variante == "sem_RS" & VR$serie == "desp:total"]), f1(VR$razao_rmse[VR$variante == "sem_RS" & VR$serie == "desp:total"], 3)),
  sprintf("4. **Por ano:** receita b3-b4 e espalhada (nenhum ano responde por mais de %s da reducao; retirando qualquer ano a razao fica entre %s e %s; o candidato perde para o B0 em %s dos %d anos). **Receita b5 e concentrada em 2020** (%s da reducao; sem 2020 a razao sobe para %s; o candidato perde para o B0 em %s dos %d anos). **Despesa b5 e concentrada em 2022** (%s da reducao; sem 2022 a razao e %s; ainda melhor que o B0 nos 5 anos).",
    paste0(f1(100 * max(r43$parcela_do_ganho), 0), "%"), f1(min(r43$razao_sem_o_ano), 2), f1(max(r43$razao_sem_o_ano), 2), sum(r43$RMSE_cand > r43$RMSE_B0), nrow(r43),
    paste0(f1(100 * r5$parcela_do_ganho[r5$exercicio == 2020], 0), "%"), f1(r5$razao_sem_o_ano[r5$exercicio == 2020], 2), sum(r5$RMSE_cand > r5$RMSE_B0), nrow(r5),
    paste0(f1(100 * db5$parcela_do_ganho[db5$exercicio == 2022], 0), "%"), f1(db5$razao_sem_o_ano[db5$exercicio == 2022], 2)),
  "5. **Em suma:** favoravel para a receita b3-b4. Para a receita b5 as checagens **nao** sao favoraveis (ganho de um ano, 2020, e falha em uma variante); para a despesa b5 sao parcialmente favoraveis (ganho forte e estavel nos anos, mas concentrado em 2022 e fragil sem o RS). A decisao de adotar e do Pedro; as regras de aceitacao nao foram alteradas.", "")
L <- character(); add <- function(...) L <<- c(L, ...)
ent <- ler_csv(o("entes")); er <- ent[ent$serie == "rec:total", ]
add("# Adendo ao relatorio E5 (05/11/2026): checagens antes de adotar", "",
    "Pedido de 05/11: (1) M4 fora da producao, M5 de producao = media dos aceitos **sem o M4**, criterios recalculados (**decisao operacional pos-resultado**, sem nova rodada); (a) B0' (SRW em R$) nas mesmas celulas; (b) variantes; (c) erro por ano. As regras de aceitacao nao mudaram. Script: `scripts/e5_adendo.R`; CSVs `outputs/e5_adendo_*.csv`.", "",
    LEIT, "",
    "## 1. M5 sem M4: criterios", "",
    md_tab(data.frame(serie = rot(CR1$serie), faixa = CR1$faixa, candidato = ifelse(CR1$candidato == "M5s4", "M5 sem M4", CR1$candidato), aceitos = CR1$aceitos, n = CR1$n, razao_RMSE = f1(CR1$razao_rmse, 3), pares = f1(CR1$share_uf_ano), anos = f1(CR1$share_anos),
      sinal = ifelse(CR1$c3, "ok", "falha"), vies = ifelse(CR1$c4, "ok", "falha"), boot = f1(CR1$prob_boot), razao_S = f1(CR1$razao_S, 3), aceito = ifelse(CR1$aceito, "sim", "nao"))), "",
    "Receita b3-b4: M1+M2+M3; receita b5: M1+M3; despesa b5: so o M3 (com um unico aceito a regra do protocolo manda o proprio M3).", "")
add("## (a) Benchmark em R$: B0 (razao), B0' (SRW em R$, restante(t-1) nominal) e candidato nas mesmas celulas", "",
    "RMSE em % do total anual, amostra A; `n` = celulas UF-ano-corte comuns aos tres. Candidato: M5 sem M4 (receita) ou M3 (despesa b5); nas celulas sem aceito, so os dois benchmarks.", "",
    md_tab(data.frame(serie = rot(RA$serie), faixa = RA$faixa, n = RA$n, candidato = ifelse(RA$candidato == "M5s4", "M5 sem M4", RA$candidato), B0 = f1(RA$RMSE_B0), `B0'` = f1(RA$RMSE_B0p), candidato_RMSE = f1(RA$RMSE_cand), check.names = FALSE)), "",
    "Por corte (mesmas celulas):", "",
    md_tab(data.frame(serie = rot(RC$serie), corte = RC$corte, B0 = f1(RC$RMSE_B0), `B0'` = f1(RC$RMSE_B0p), candidato = f1(RC$RMSE_cand), check.names = FALSE)), "",
    "Candidato contra o B0' (informacao, mesmos criterios 2-5 com o B0' como base):", "",
    md_tab(data.frame(serie = rot(CP$serie), faixa = CP$faixa, candidato = ifelse(CP$candidato == "M5s4", "M5 sem M4", CP$candidato), razao_RMSE_vs_B0p = f1(CP$razao_rmse_vs_B0p, 3), pares = f1(CP$share_uf_ano), anos = f1(CP$share_anos), boot = f1(CP$prob_boot), sinal = ifelse(CP$c3_sinal, "ok", "falha"), vies = ifelse(CP$c4_vies, "ok", "falha"))), "")
add("## (b) Variantes de robustez nas tres celulas candidatas (amostra A; criterios 1-5; o criterio 6 usa a amostra S e nao foi reestimado nas variantes)", "",
    md_tab(data.frame(variante = VR$variante, serie = rot(VR$serie), faixa = VR$faixa, modelo = ifelse(VR$modelo == "M5s4", "M5 sem M4", VR$modelo), n = VR$n, razao_RMSE = f1(VR$razao_rmse, 3), pares = f1(VR$share_uf_ano), anos = f1(VR$share_anos), boot = f1(VR$prob_boot), `passa 1-5` = ifelse(VR$passa_1a5, "sim", "nao"), check.names = FALSE)), "")
add("## (c) Erro por ano nas tres celulas (RMSE %, todas as UFs do ano e cortes da faixa)", "",
    "`parcela` = parte da reducao total da soma dos erros ao quadrado (B0 menos candidato) que cada ano responde; `sem o ano` = razao de RMSE candidato/B0 retirando aquele ano.", "",
    md_tab(data.frame(serie = rot(PY$serie), faixa = PY$faixa, ano = PY$exercicio, n = PY$n, B0 = f1(PY$RMSE_B0), `B0'` = f1(PY$RMSE_B0p), candidato = f1(PY$RMSE_cand), parcela = f1(PY$parcela_do_ganho), `sem o ano` = f1(PY$razao_sem_o_ano, 3), check.names = FALSE)), "")
add("## Para o texto do informe", "",
    sprintf("Os entes subestimam a receita na previsao atualizada: vies de %s%% (b1-b2), %s%% (b3-b4) e %s%% (b5) do total anual (`outputs/e5_entes.csv`, previsao atualizada contra a receita realizada, Anexo 6, 27 UFs, 2018-2025).", f1(er$vies_ente_pct[er$faixa == "b1_b2"], 1), f1(er$vies_ente_pct[er$faixa == "b3_b4"], 1), f1(er$vies_ente_pct[er$faixa == "b5"], 1)), "")
writeLines(L, "docs/relatorio_e5_adendo.md")
cat("\n"); cat(L, sep = "\n")
