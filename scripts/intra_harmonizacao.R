# Intraorcamentarias (A6 de 2023 em diante): simetria receita x despesa, harmonizacao e efeito no crescimento real.
# Criterios fixados antes de computar: docs/intra_criterios.md (commit 5378d5a). Serie COM RPPS, 27 UFs.
# Uso: LC_ALL=C.UTF-8 Rscript scripts/intra_harmonizacao.R   (precisa do bruto local do RREO estados; guarda cache em outputs/cache_rreo.rds)
# Saidas (git-ignored): outputs/intra_{simetria,liquido,validacao,crescimento}.csv
source("R/utils_io.R", encoding = "UTF-8")
carregar_r(c("R/download/snapshots.R", "R/download/siconfi_rreo.R", "R/transform/rreo.R", "R/transform/dicionario_contas.R", "R/transform/intra.R", "R/quality/alertas.R"))
fc <- dados("outputs/cache_rreo.rds")
if (file.exists(fc)) rreo <- readRDS(fc) else { rreo <- ler_rreo_pasta(dados("data/raw/rreo"), "E"); saveRDS(rreo, fc) }
rreo <- rreo[rreo$exercicio >= 2018, ]; rreo$col <- gsub("\\s+", " ", rreo$coluna)
a1 <- rreo[rreo$anexo == "RREO-Anexo 01", ]; a6 <- rreo[rreo$anexo == "RREO-Anexo 06", ]
pega <- function(d, contas, colpad, por = c("cod_ibge", "exercicio", "periodo")) {
  x <- d[d$cod_conta %in% contas & grepl(colpad, d$col), ]; x <- x[!duplicated(x[, c(por, "cod_conta")]), ]
  aggregate(x$valor, x[por], sum)
}
R1 <- "^Até o Bimestre \\(c\\)$"; D1 <- "^DESPESAS PAGAS ATÉ O BIMESTRE \\(j\\)$"; R6 <- "^RECEITAS REALIZADAS \\(a\\)$"
nm <- function(x, n) { names(x)[ncol(x)] <- n; x }
G_DESP <- c("PessoalEEncargosSociais", "OutrasDespesasCorrentes", "Investimentos", "InversoesFinanceiras")

# ---- 2a. simetria da receita (b6, 2018-2025) -----------------------------------------------------------------------------------------------
b6 <- function(x) x[x$periodo == 6, ]
ex <- nm(b6(pega(a1, "ReceitasExcetoIntraOrcamentarias", R1)), "ex"); fin <- nm(b6(pega(a1, c("ReceitasDeOperacoesDeCredito", "AlienacaoDeBens", "AmortizacoesDeEmprestimos"), R1)), "fin")
ir <- nm(b6(pega(a1, "ReceitasIntraOrcamentariasTotal", R1)), "intra_rec"); ap <- nm(b6(pega(a6, "RREO6AplicacoesFinanceiras", R6)), "aplic")
rp <- nm(b6(pega(a6, "RREO6TotalReceitaPrimaria", R6)), "a6_rec")
idesp <- lapply(G_DESP, function(g) nm(b6(pega(a1, paste0(g, "Intra"), D1)), g)); ide <- Reduce(function(a, b) merge(a, b, by = c("cod_ibge", "exercicio", "periodo"), all = TRUE), idesp)
ide$intra_desp <- rowSums(ide[, G_DESP], na.rm = TRUE)
m <- Reduce(function(a, b) merge(a, b, by = c("cod_ibge", "exercicio", "periodo"), all.x = TRUE), list(rp, ex, fin, ir, ap, ide[, c("cod_ibge", "exercicio", "periodo", "intra_desp")]))
for (v in c("fin", "intra_rec", "aplic", "intra_desp")) m[[v]][is.na(m[[v]])] <- 0
m$base <- m$ex - m$fin - m$aplic; m$res_sem <- (m$a6_rec - m$base) / m$a6_rec; m$res_com <- (m$a6_rec - m$base - m$intra_rec) / m$a6_rec
sim <- do.call(rbind, lapply(sort(unique(m$exercicio)), function(y) { d <- m[m$exercicio == y, ]
  s <- mean(abs(d$res_sem) <= .01, na.rm = TRUE); c_ <- mean(abs(d$res_com) <= .01, na.rm = TRUE)
  data.frame(exercicio = y, n_uf = sum(!is.na(d$res_sem)), pct_vale_sem_intra = round(100 * s, 1), pct_vale_com_intra = round(100 * c_, 1),
             leitura = ifelse(c_ >= .9 & s < .9, "inclui intra", ifelse(s >= .9 & c_ < .9, "exclui intra", "inconclusivo")),
             mediana_res_sem_pct = round(100 * median(d$res_sem, na.rm = TRUE), 2), mediana_res_com_pct = round(100 * median(d$res_com, na.rm = TRUE), 2)) }))
gravar_csv(sim, dados("outputs/intra_simetria.csv")); cat("==== 2a. Receita primaria do A6 inclui as intra? ====\n"); print(sim, row.names = FALSE)
m$liquido <- m$intra_rec - m$intra_desp; m$liq_pct_rec <- 100 * m$liquido / m$a6_rec; m$desp_pct_rec <- 100 * m$intra_desp / m$a6_rec; m$rec_pct_rec <- 100 * m$intra_rec / m$a6_rec
gravar_csv(m, dados("outputs/intra_liquido.csv"))
cat("\nIntra 2023-2025 (R$ bi, soma das 27 UFs) e liquido em % da receita primaria (mediana das UFs; minimo e maximo)\n")
l <- do.call(rbind, lapply(2023:2025, function(y) { d <- m[m$exercicio == y, ]; data.frame(exercicio = y, intra_rec_bi = round(sum(d$intra_rec) / 1e9, 1), intra_desp_bi = round(sum(d$intra_desp) / 1e9, 1),
  liquido_bi = round(sum(d$liquido) / 1e9, 1), liq_pct_rec_mediana = round(median(d$liq_pct_rec), 2), liq_pct_rec_min = round(min(d$liq_pct_rec), 2), liq_pct_rec_max = round(max(d$liq_pct_rec), 2),
  desp_intra_pct_rec_mediana = round(median(d$desp_pct_rec), 2)) })); print(l, row.names = FALSE)
cat("\nUFs com |liquido| > 2% da receita primaria em 2023-2025:\n"); w <- m[m$exercicio >= 2023 & abs(m$liq_pct_rec) > 2, c("cod_ibge", "exercicio", "intra_rec", "intra_desp", "liq_pct_rec")]
w$intra_rec <- round(w$intra_rec / 1e9, 2); w$intra_desp <- round(w$intra_desp / 1e9, 2); w$liq_pct_rec <- round(w$liq_pct_rec, 1); print(w[order(-abs(w$liq_pct_rec)), ], row.names = FALSE)

# ---- 2b. harmonizacao: fluxos de intra (A1) por bimestre e series ajustadas --------------------------------------------------------------------
INT <- fluxo_intra(rreo)   # R/transform/intra.R
fl <- readRDS(dados("outputs/cache_fluxos_com.rds")); fl <- fl[fl$exercicio >= 2021, c("cod_ibge", "serie", "exercicio", "periodo", "valor")]
h <- harmonizar_intra(fl, INT, series = INTRA_MAPA$serie)   # retirada em TODAS as categorias mapeadas (para validar o mapeamento)
names(h)[names(h) == "valor_bruto"] <- "bruto"; h$harm <- h$valor
T <- rbind(total_harmonizado(fl, INT, "rec"), total_harmonizado(fl, INT, "desp"))
T$harm <- T$harmonizado

# validacao do mapeamento por categoria (anual, b6 completo): yoy nominal 2023 contra a media de 2022 e 2024
ann <- aggregate(cbind(bruto, harm) ~ cod_ibge + serie + exercicio, h[h$periodo %in% 1:6, ], sum)
cnt <- aggregate(periodo ~ cod_ibge + serie + exercicio, h[h$periodo %in% 1:6 & !is.na(h$bruto), ], length); ann <- merge(ann, cnt, by = c("cod_ibge", "serie", "exercicio")); ann <- ann[ann$periodo == 6, ]
yo <- function(s, v) { w <- reshape(ann[ann$serie == s, c("cod_ibge", "exercicio", v)], idvar = "cod_ibge", timevar = "exercicio", direction = "wide"); names(w) <- sub(paste0(v, "\\."), "y", names(w))
  data.frame(cod_ibge = w$cod_ibge, y22 = w$y2022 / w$y2021 - 1, y23 = w$y2023 / w$y2022 - 1, y24 = w$y2024 / w$y2023 - 1) }
val <- do.call(rbind, lapply(sort(unique(INT$serie)), function(s) { b <- yo(s, "bruto"); a <- yo(s, "harm"); ok <- complete.cases(b) & complete.cases(a)
  db <- abs(b$y23 - (b$y22 + b$y24) / 2); da <- abs(a$y23 - (a$y22 + a$y24) / 2)
  mb <- median(b$y23[ok]); ma <- median(a$y23[ok]); ref <- median(((b$y22 + b$y24) / 2)[ok]); refa <- median(((a$y22 + a$y24) / 2)[ok])
  data.frame(serie = s, n_uf = sum(ok), yoy23_mediana_bruto_pct = round(100 * mb, 1), yoy22_24_media_bruto_pct = round(100 * ref, 1), yoy23_mediana_harm_pct = round(100 * ma, 1),
             yoy22_24_media_harm_pct = round(100 * refa, 1), pct_ufs_desvio_cai = round(100 * mean(da[ok] < db[ok]), 1),
             passa = abs(ma - refa) < abs(mb - ref) & mean(da[ok] < db[ok]) >= .5) }))
gravar_csv(val, dados("outputs/intra_validacao.csv")); cat("\n==== 2b. Validacao do mapeamento por categoria (yoy nominal 2023; criterio de docs/intra_criterios.md) ====\n"); print(val, row.names = FALSE)

# crescimento real com e sem a retirada (total, 27 UFs)
ip <- jsonlite::fromJSON("https://api.bcb.gov.br/dados/serie/bcdata.sgs.433/dados?formato=json&dataInicial=01/01/2021&dataFinal=31/12/2026")
ip$mes <- as.Date(ip$data, "%d/%m/%Y"); ip$v <- as.numeric(ip$valor) / 100; ip <- ip[order(ip$mes), ]; ip$ind <- cumprod(1 + ip$v)
ind_bim <- function(ex, b) mean(ip$ind[ip$mes %in% as.Date(sprintf("%d-%02d-01", ex, (2 * b - 1):(2 * b)))])
T$k <- mapply(ind_bim, T$exercicio, T$periodo); T$b_real <- T$bruto / T$k; T$h_real <- T$harm / T$k
jan <- list(list("2023 vs 2022 (b1-b6)", 2022L, 2023L, 6L), list("2024 vs 2023 (b1-b6)", 2023L, 2024L, 6L), list("2025 vs 2024 (b1-b6)", 2024L, 2025L, 6L), list("2026 vs 2025 (b1-b4)", 2025L, 2026L, 4L))
cr <- do.call(rbind, lapply(jan, function(j) do.call(rbind, lapply(c("rec", "desp"), function(l) {
  x <- T[T$lado == l & T$periodo <= j[[4]] & T$exercicio %in% c(j[[2]], j[[3]]), ]
  ok <- aggregate(periodo ~ cod_ibge + exercicio, x, length); ok <- ok[ok$periodo == j[[4]], ]; k <- intersect(ok$cod_ibge[ok$exercicio == j[[2]]], ok$cod_ibge[ok$exercicio == j[[3]]])
  s <- aggregate(cbind(b_real, h_real) ~ exercicio, x[x$cod_ibge %in% k, ], sum)
  g <- function(v) 100 * (s[[v]][s$exercicio == j[[3]]] / s[[v]][s$exercicio == j[[2]]] - 1)
  data.frame(janela = j[[1]], lado = l, n_uf = length(k), cresc_real_bruto_pct = g("b_real"), cresc_real_sem_intra_pct = g("h_real"), dif_pp = g("h_real") - g("b_real")) }))))
gravar_csv(cr, dados("outputs/intra_crescimento.csv")); cat("\n==== Crescimento real dos estados, com intra (bruto, A6 de 2023+) e sem intra (harmonizado) ====\n")
print(transform(cr, cresc_real_bruto_pct = round(cresc_real_bruto_pct, 2), cresc_real_sem_intra_pct = round(cresc_real_sem_intra_pct, 2), dif_pp = round(dif_pp, 2)), row.names = FALSE)

# ---- identidade: categorias + "intra nao alocada" = total harmonizado, UF x bimestre, 2021-2026 --------------------------------------------------
fh <- harmonizar_fluxos(fl, INT); ch <- checar_identidade_intra(fh, fl, INT)
na <- aggregate(valor ~ exercicio + serie, fh[grepl("nao alocada", fh$serie), ], sum); na$valor_bi <- round(na$valor / 1e9, 2)
gravar_csv(na, dados("outputs/intra_nao_alocada.csv"))
cat(sprintf("\n==== Identidade (categorias + intra nao alocada = total harmonizado): maior diferenca absoluta R$ %s em %d UF x bimestre x lado ====\n", format(ch$max_abs, digits = 3), nrow(ch$tabela)))
cat("Intra nao alocada (R$ bi, soma das 27 UFs, bimestres disponiveis) por ano:\n"); print(na[na$serie == "desp:intra nao alocada", c("exercicio", "valor_bi")], row.names = FALSE)
