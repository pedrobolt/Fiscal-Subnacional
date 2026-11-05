# Rodada de TESTE 2026 (pedido de Pedro, 05/11/2026): gap implicito P2 projetado - P1 por esfera, decomposicao, m3 sombra e erro do SRW em anos de eleicao estadual.
# Descritivo: nao muda modelos; o primario implicito do P2 nao vai para a planilha nem para o texto do informe. Le a rodada de teste de FISCAL_DADOS/outputs/teste/rodada/<data>/.
# Uso: LC_ALL=C.UTF-8 Rscript scripts/teste_2026_gap.R [--data=2026-11-05]. Saidas: FISCAL_DADOS/outputs/teste/relatorio_2026/*.csv (docs/projecao_2026_teste.md sai de scripts/teste_2026_md.R).
source("R/utils_io.R", encoding = "UTF-8")
args <- commandArgs(TRUE); dia <- sub("^--data=", "", grep("^--data=", args, value = TRUE)); if (!length(dia)) dia <- "2026-11-05"
arqs <- list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE); arqs <- c(arqs[!grepl("candidatos_p1", arqs)], arqs[grepl("candidatos_p1", arqs)])
carregar_r(arqs); carregar_r("scripts/e5_dados.R")
RD <- dados(file.path("outputs", "teste", "rodada", dia)); SD <- dados(file.path("outputs", "teste", "relatorio_2026")); dir.create(SD, showWarnings = FALSE, recursive = TRUE)
ANO <- 2026L; M_P1 <- 9L; B_P2 <- 4L
saida <- function(x, nome) gravar_csv(x, file.path(SD, paste0(nome, ".csv")))

# ---- insumos -------------------------------------------------------------------------------------------------------------------------------
ult <- function(cod) { f <- sort(list.files(dados("data/raw"), sprintf("^bcb_sgs_%s_.*\\.json$", cod), full.names = TRUE)); f[length(f)] }
S <- lapply(c(regional = 4642L, estaduais = 4643L, municipais = 4644L), function(c) { s <- ler_sgs(ult(c)); primario_bi(s[s$data >= SGS_INICIO_ANALISE, ]) })
est <- S$estaduais
D <- e5_montar(); base <- D$base
uf <- ler_csv(file.path(RD, "p2_projecao_uf.csv")); cres <- ler_csv(file.path(RD, "p2_projecao.csv")); prem <- ler_premissas(ano_t = ANO)
adocao <- e5_ler_adocao(); plano <- e5_plano_faixa(adocao, B_P2); of <- plano[plano$oficial, ]
mod_of <- function(s) of$modelo[of$serie == s]

# ---- 1. P2 realizado anual (rec - desp, consolidado) e P1 estaduais realizado ----------------------------------------------------------------
t_an <- base[base$corte == 1 & base$serie %in% c("rec:total", "desp:total"), c("serie", "cod_ibge", "exercicio", "T")]
w <- reshape(t_an, idvar = c("cod_ibge", "exercicio"), timevar = "serie", direction = "wide"); names(w) <- sub("T\\.", "", sub(":", "_", names(w)))
w <- w[stats::complete.cases(w), ]
real <- do.call(rbind, lapply(split(w, w$exercicio), function(d) data.frame(exercicio = d$exercicio[1], n_ufs = nrow(d), rec_bi = sum(d$rec_total) / 1e9, desp_bi = sum(d$desp_total) / 1e9)))
real <- real[real$n_ufs == 27L, ]; real$p2_real_bi <- real$rec_bi - real$desp_bi
real$p1_real_bi <- vapply(real$exercicio, function(a) soma_meses(est, a, 1:12), 0); real$gap_real_bi <- real$p2_real_bi - real$p1_real_bi; real$r_real <- real$gap_real_bi / real$rec_bi
# gap oficial do E3.6 (A6) somado no ano, so como referencia de conceito
g36 <- tryCatch(ler_csv(dados("outputs/gap_estados_bimestral.csv")), error = function(e) NULL)
if (!is.null(g36)) { g36 <- g36[g36$variante == "com_2020_22", ]; a <- aggregate(cbind(g, rec) ~ exercicio, g36, sum); a$n <- as.vector(table(g36$exercicio)[as.character(a$exercicio)]); a <- a[a$n == 6, ]
  real$gap_e36_a6_bi <- a$g[match(real$exercicio, a$exercicio)] }

# ---- 2. P2 projetado em b4 (modelo adotado da faixa b3_b4) nos anos do backtest e SRW estaduais no mes 9 --------------------------------------
pred <- ler_csv(dados("outputs/e5_previsoes.csv")); pred <- pred[pred$amostra == "A" & pred$corte == B_P2, ]
membros <- strsplit(adocao$membros[adocao$serie == "rec:total" & adocao$faixa == "b3_b4" & adocao$oficial], "+", fixed = TRUE)[[1]]
mk <- function(s, m) { if (m == "M5s4") { x <- pred[pred$serie == s & pred$modelo %in% membros, ]; g <- aggregate(logr_hat ~ serie + amostra + faixa + cod_ibge + exercicio + corte, x, mean); g$modelo <- "M5s4"; g } else pred[pred$serie == s & pred$modelo == m, ] }
PP <- rbind(mk("rec:total", mod_of("rec:total")), mk("desp:total", mod_of("desp:total")))
E <- e5_erros(PP[, c("serie", "amostra", "faixa", "cod_ibge", "exercicio", "corte", "modelo", "logr_hat")], base)
hist <- do.call(rbind, lapply(split(E, E$exercicio), function(d) {
  r <- d[d$serie == "rec:total", ]; x <- d[d$serie == "desp:total", ]; ok <- intersect(r$cod_ibge, x$cod_ibge)
  if (length(ok) < 27L) return(NULL); r <- r[match(ok, r$cod_ibge), ]; x <- x[match(ok, x$cod_ibge), ]
  data.frame(exercicio = r$exercicio[1], p2_proj_bi = (sum(r$That) - sum(x$That)) / 1e9, rec_proj_bi = sum(r$That) / 1e9, p2_real_bi = (sum(r$T) - sum(x$T)) / 1e9, A_p2_bi = (sum(r$A) - sum(x$A)) / 1e9)
}))
hist$p1_srw9_bi <- vapply(hist$exercicio, function(a) prever_srw(est, a, M_P1), 0); hist$p1_real_bi <- real$p1_real_bi[match(hist$exercicio, real$exercicio)]
hist$p2_erro_bi <- hist$p2_proj_bi - hist$p2_real_bi; hist$p1_erro_bi <- hist$p1_srw9_bi - hist$p1_real_bi
hist$gap_impl_bi <- hist$p2_proj_bi - hist$p1_srw9_bi; hist$r_impl <- hist$gap_impl_bi / hist$rec_proj_bi
hist$gap_real_bi <- hist$p2_real_bi - hist$p1_real_bi; hist$r_real <- hist$gap_real_bi / real$rec_bi[match(hist$exercicio, real$exercicio)]

# ---- 3. 2026: P2 projetado, P1 por esfera, gap implicito -------------------------------------------------------------------------------------
u <- uf[uf$modelo == mod_of("rec:total") & uf$serie == "rec:total" | uf$modelo == mod_of("desp:total") & uf$serie == "desp:total", ]
u <- u[u$cod_ibge %in% unique(uf$cod_ibge[uf$serie == "rec:total"]), ]
rec <- u[u$serie == "rec:total", ]; des <- u[u$serie == "desp:total", ]; stopifnot(nrow(rec) == 27L, nrow(des) == 27L)
p2_26 <- (sum(rec$That) - sum(des$That)) / 1e9; rec26 <- sum(rec$That) / 1e9
p1_est9 <- prever_srw(est, ANO, M_P1); p1_est8 <- prever_srw(est, ANO, 2L * B_P2)
p1e <- p1_srw_esferas(S, ANO, M_P1)
gap26 <- p2_26 - p1_est9; r26 <- gap26 / rec26

# regra do E3.6 adaptada ao horizonte anual: referencia = mediana e MAD do r realizado dos 3 anos anteriores (mesmo segmento, a partir da fronteira 2023), K = 4 MAD, piso 1% da receita, minimo 2 observacoes
classe_anual <- function(r, ano, ref) {
  seg <- function(a) as.integer(a >= GAP_FRONTEIRA); j <- ref$exercicio < ano & ref$exercicio >= ano - GAP_ANOS_REF & seg(ref$exercicio) == seg(ano) & is.finite(ref$r_real)
  if (sum(j) < GAP_MIN_REF) return(data.frame(classe = "sem_referencia", med_ref = NA_real_, mad_ref = NA_real_, n_ref = sum(j)))
  md <- stats::median(ref$r_real[j]); ma <- stats::median(abs(ref$r_real[j] - md))
  data.frame(classe = if (abs(r - md) > max(GAP_K_MAD * ma, GAP_PISO)) "atipico" else "consistente", med_ref = md, mad_ref = ma, n_ref = sum(j))
}
ref <- real[, c("exercicio", "r_real")]
cl_h <- do.call(rbind, lapply(seq_len(nrow(hist)), function(i) cbind(classe_anual(hist$r_impl[i], hist$exercicio[i], ref), classe_realizado = classe_anual(hist$r_real[i], hist$exercicio[i], ref)$classe)))
hist <- cbind(hist, cl_h); names(hist)[names(hist) == "classe"] <- "classe_implicito"
c26 <- classe_anual(r26, ANO, ref)
gi <- data.frame(ano = ANO, p2_proj_bi = p2_26, rec_proj_bi = rec26, p1_srw_estaduais_m9_bi = p1_est9, p1_srw_estaduais_m8_bi = p1_est8, p1_srw_regional_m9_bi = p1e$previsao_bi[p1e$esfera == "regional"], p1_srw_municipais_m9_bi = p1e$previsao_bi[p1e$esfera == "municipais"],
                 gap_impl_bi = gap26, r_impl = r26, classe = c26$classe, med_ref = c26$med_ref, mad_ref = c26$mad_ref, n_ref = c26$n_ref, limiar = max(GAP_K_MAD * c26$mad_ref, GAP_PISO),
                 modelo_receita = mod_of("rec:total"), modelo_despesa = mod_of("desp:total"), ipca_premissa = prem$anos$ipca[prem$anos$ano == ANO])
saida(gi, "gap_implicito_2026"); saida(hist, "gap_historico"); saida(real, "p2_p1_realizado")

# ---- 4. decomposicao: acumulado ate o corte x hipotese do restante ----------------------------------------------------------------------------
Ant <- base[base$exercicio == ANO - 1L & base$corte == B_P2 & base$serie %in% c("rec:total", "desp:total"), c("serie", "cod_ibge", "A", "T")]
ar <- Ant[Ant$serie == "rec:total", ]; ad <- Ant[Ant$serie == "desp:total", ]
A_p2 <- (sum(rec$A) - sum(des$A)) / 1e9; R_p2 <- p2_26 - A_p2
Rrec_hat <- (sum(rec$That) - sum(rec$A)) / 1e9; Rdes_hat <- (sum(des$That) - sum(des$A)) / 1e9
Rrec_ant <- (sum(ar$T) - sum(ar$A)) / 1e9; Rdes_ant <- (sum(ad$T) - sum(ad$A)) / 1e9; R_p2_ant <- Rrec_ant - Rdes_ant
A_p1 <- soma_meses(est, ANO, 1:(2L * B_P2)); R_p1 <- soma_meses(est, ANO - 1L, (2L * B_P2 + 1L):12)
dec <- data.frame(componente = c("P2 projetado (b4)", "P1 SRW estaduais (mes 8)", "diferenca total (P2 - P1, mesmo corte b4/mes 8)",
  "  (i) acumulado ate o corte: P2 realizado - P1 realizado (jan-ago)", "  (ii) restante: P2 projetado - P1 restante(t-1) em R$", "     (ii-a) razao do P2 vs restante(t-1) em R$ do proprio P2 (hipotese do modelo)", "     (ii-b) restante(t-1): P2 realizado - P1 realizado (gap realizado no fim de t-1)",
  "memo: passagem do SRW do mes 8 ao mes 9 (P1)", "memo: gap implicito no corte do P1 (P2 projetado - SRW mes 9)", "memo: restante projetado, receita (P2)", "memo: restante projetado, despesa (P2)", "memo: restante(t-1) realizado, receita (P2)", "memo: restante(t-1) realizado, despesa (P2)"),
  valor_bi = c(p2_26, p1_est8, p2_26 - p1_est8, A_p2 - A_p1, R_p2 - R_p1, R_p2 - R_p2_ant, R_p2_ant - R_p1, p1_est9 - p1_est8, gap26, Rrec_hat, Rdes_hat, Rrec_ant, Rdes_ant))
A_p2_ant <- (sum(ar$A) - sum(ad$A)) / 1e9; A_p1_ant <- soma_meses(est, ANO - 1L, 1:(2L * B_P2))
ctx <- data.frame(componente = c("memo: P2 com restante(t-1) em R$ (SRW em R$ no restante, B0')", "memo: acumulado jan-ago de t-1, P2", "memo: acumulado jan-ago de t-1, P1", "memo: acumulado jan-ago de t, P2", "memo: acumulado jan-ago de t, P1"),
  valor_bi = c(A_p2 + R_p2_ant, A_p2_ant, A_p1_ant, A_p2, A_p1), detalhe = "")
dec$detalhe <- c(sprintf("acumulado %.1f + restante %.1f", A_p2, R_p2), sprintf("acumulado %.1f + restante(t-1) %.1f", A_p1, R_p1), rep("", 11))[seq_len(13)]
dec <- rbind(dec, ctx); saida(dec, "decomposicao_2026")

# ---- 5. m3 (sombra), somente informacao ------------------------------------------------------------------------------------------------------
cod_pib <- ler_csv(file.path(RD, "p1.csv")); pib26 <- prem$anos$pib_nominal[prem$anos$ano == ANO]
pib_h <- tryCatch({ a <- ult("x"); NULL }, error = function(e) NULL)
arq_pib <- c(anual = sort(list.files(dados("data/raw"), "^ibge_pib_6784_", full.names = TRUE), decreasing = TRUE)[1], trimestral = sort(list.files(dados("data/raw"), "^ibge_pib_1846_", full.names = TRUE), decreasing = TRUE)[1])
pib <- pib_ibge_anual(arq_pib[["anual"]], arq_pib[["trimestral"]])[, c("ano", "pib_bi")]; pib <- rbind(pib[pib$ano < ANO, ], data.frame(ano = ANO, pib_bi = pib26))
info <- montar_info(list(bcb = S$regional, bcb_est = S$estaduais, bcb_mun = S$municipais, pib = pib), ANO, M_P1)
m3_reg <- CANDIDATOS_P1_BASE$m3(info, ANO, M_P1); m3_est <- prever_total_restante(info, ANO, M_P1, ESPEC_M3_ESTADOS, serie = info$bcb_est); m3_mun <- prever_total_restante(info, ANO, M_P1, ESPEC_M3_MUNICIPIOS, serie = info$bcb_mun)
m3 <- data.frame(esfera = c("regional (m3 do regional)", "estaduais (m3 do componente, E4.1)", "municipais (m3 do componente, E4.1)"), m3_bi = c(m3_reg, m3_est, m3_mun),
  srw_bi = c(p1e$previsao_bi[p1e$esfera == "regional"], p1_est9, p1e$previsao_bi[p1e$esfera == "municipais"]), pib_2026_bi = pib26)
m3$m3_menos_srw_bi <- m3$m3_bi - m3$srw_bi; saida(m3, "m3_sombra_2026")

# ---- 6. erro do SRW por esfera e corte, anos de eleicao estadual x demais (descritivo) -------------------------------------------------------------
er <- list()
for (e in names(S)) { s <- S[[e]]; for (a in 2007:2025) { real_a <- soma_meses(s, a, 1:12); for (m in 1:11) { p <- prever_srw(s, a, m); if (is.finite(p) && is.finite(real_a)) er[[length(er) + 1]] <- data.frame(esfera = e, ano = a, corte = m, srw_bi = p, realizado_bi = real_a, erro_bi = p - real_a) } } }
er <- do.call(rbind, er); er$eleicao_estadual <- er$ano %% 4L == 2L; er$pandemia <- er$ano %in% 2020:2021
saida(er, "srw_erro_por_ano_corte")
rs <- do.call(rbind, lapply(split(er, list(er$esfera, er$corte), drop = TRUE), function(d) {
  f <- function(x) c(n = nrow(x), me = mean(x$erro_bi), mae = mean(abs(x$erro_bi)))
  e1 <- f(d[d$eleicao_estadual, ]); o1 <- f(d[!d$eleicao_estadual, ]); o2 <- f(d[!d$eleicao_estadual & !d$pandemia, ])
  data.frame(esfera = d$esfera[1], corte = d$corte[1], n_eleicao = e1[["n"]], me_eleicao = e1[["me"]], mae_eleicao = e1[["mae"]], n_demais = o1[["n"]], me_demais = o1[["me"]], mae_demais = o1[["mae"]], n_demais_sem_2020_21 = o2[["n"]], me_demais_sem_2020_21 = o2[["me"]], mae_demais_sem_2020_21 = o2[["mae"]])
}))
rs <- rs[order(rs$esfera, rs$corte), ]; saida(rs, "srw_erro_eleicao_resumo")
cat(sprintf("Gap implicito 2026: P2 %.1f - P1 estaduais (m9) %.1f = %.1f bi; classe %s\n", p2_26, p1_est9, gap26, c26$classe))
