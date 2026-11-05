library(testthat)
source_utf8("../R/utils_io.R")
for (f in c("models/fatia_minima.R", "evaluation/intervalos.R", "evaluation/vazamento.R", "evaluation/torneio.R", "models/candidatos_restante.R", "models/candidatos_p1.R", "transform/gap_p1_p2.R", "pipeline/rodada.R", "export/informe.R", "export/sinais.R")) source_utf8(file.path("../R", f))

serie <- function(v, ini = 2024) data.frame(data = seq(as.Date(sprintf("%d-01-01", ini)), by = "month", length.out = length(v)), valor_bi = v)
mk_I <- function(prev = -12.8, est24 = 26, est25 = 7.1, con = 0.01, d = 6.8, r = 3.6, n_desp = 18) {
  # estados: acumulado ate agosto (m = 8) cai de est24 para est25; municipios ficam parados
  e <- c(rep(est24 / 8, 8), rep(0.5, 4), rep(est25 / 8, 8)); mu <- rep(0.4, 20); rg <- e + mu
  list(dia = "2026-11-05", oficial = FALSE, status = "DEGRADADA", commit = "abc", corte = list(ultimo = as.Date("2025-08-01"), ano_alvo = 2025L, m = 8L, completo = FALSE), bim_ref = c(2025L, 4L), prem = list(versao = "v", fonte = "f"),
    p1 = data.frame(esfera = c("regional", "estaduais", "municipais"), ano_alvo = 2025L, corte_m = 8L, acumulado_bi = c(sum(rg[13:20]), sum(e[13:20]), sum(mu[13:20])), restante_ano_anterior_bi = c(1, 1, 1), previsao_bi = c(prev, -14, 1), dif_regional_vs_soma_bi = c(0, NA, NA),
                    faixa_intervalo_inf = c(-20, NA, NA), faixa_intervalo_sup = c(5, NA, NA), stringsAsFactors = FALSE),
    txt_cob = "contem o resultado em 74% dos anos-alvo", pib = data.frame(ano = 2024:2025, pib_bi = c(10000, 12000)), series = list(regional = serie(rg), estaduais = serie(e), municipais = serie(mu)),
    proj = NULL, alertas_lista = data.frame(grupo = "ultimo", tipo = "b"), alertas_contagem = data.frame(grupo = "ultimo", tipo = "b", subtipo = "x", n = 1L), gap = data.frame(exercicio = 2025L, periodo = 1L, p2 = 1, p1 = 1, g = 0, r = 0, classe_informe = "x", classe_sem_2020_22 = "x"),
    p2_tot = data.frame(exercicio = 2025L, periodo = 1L, p2_com = 1), p2_cat = NULL, rmse = NULL, arquivo = NULL, fh_tot = NULL, base_ant = NULL)
}

test_that("manchete: verbo e sinal por condicional, campos dos CSVs", {
  I <- mk_I(prev = -12.8); I$series$regional <- serie(c(rep(0.79, 12), rep(0.5, 8))); t1 <- informe_texto(I)$blocos[1]
  expect_match(t1, "registrem déficit primário de R\\$ 12,8 bilhões \\(0,1% do PIB\\) em 2025, revertendo o superávit de R\\$ 9,5 bilhões \\(0,1% do PIB\\) de 2024")
  I$p1$previsao_bi[1] <- -20; I$series$regional <- serie(c(rep(-1, 12), rep(0.5, 8))); expect_match(informe_texto(I)$blocos[1], "ampliando o déficit")
  I$p1$previsao_bi[1] <- -3; expect_match(informe_texto(I)$blocos[1], "reduzindo o déficit")
})

test_that("acumulado dos estados: recuo e concentracao condicional", {
  t2 <- informe_texto(mk_I())$blocos[2]
  expect_match(t2, "No acumulado até agosto, o superávit dos estados recuou de R\\$ 26,0 bilhões para R\\$ 7,1 bilhões na comparação com o mesmo período de 2024")
  expect_match(t2, "A piora se concentra nos estados")
  I1 <- mk_I(est25 = 0.9); expect_match(informe_texto(I1)$blocos[2], "para R\\$ 0,9 bilhão na")
  I <- mk_I(); I$series$municipais <- serie(c(rep(0.4, 12), rep(-5, 8))); I$series$regional <- serie(I$series$estaduais$valor_bi + I$series$municipais$valor_bi)
  expect_false(grepl("se concentra", informe_texto(I)$blocos[2]))     # municipios pioram mais
  I2 <- mk_I(est25 = -3); expect_match(informe_texto(I2)$blocos[2], "passou de superávit de R\\$ 26,0 bilhões para déficit de R\\$ 3,0 bilhões")
})

test_that("blocos 3 a 5: sem E5 saem pendentes e o comentario do analista fica vazio; notas fixas", {
  T <- informe_texto(mk_I()); expect_match(T$blocos[3], "pendente"); expect_match(T$blocos[4], "pendente"); expect_match(T$blocos[5], "pendente")
  expect_equal(T$comentario, ""); expect_match(T$notas[1], "conceito consolidado"); expect_match(T$notas[3], "conceito do Banco Central"); expect_false(any(grepl("m3|Sinais", c(T$blocos, T$notas))))
})

test_that("bloco 3 com E5: razao, contagem de UFs e direcao", {
  I <- mk_I(); uf <- expand.grid(cod_ibge = 1:27, serie = c("rec:total", "desp:total"), stringsAsFactors = FALSE); uf$modelo <- ifelse(uf$serie == "rec:total", "M5s4", "B0"); uf$Areal_ant <- 100
  uf$Areal <- ifelse(uf$serie == "rec:total", 103, ifelse(uf$cod_ibge <= 18, 110, 101))
  cr <- data.frame(conceito = "consolidado", serie = c("rec:total", "desp:total"), modelo = c("M5s4", "B0"), oficial = TRUE, cresc_real_pct = c(3.6, 6.8), stringsAsFactors = FALSE)
  I$proj <- list(corte = 4L, cresc = cr, uf = uf, plano = data.frame(serie = c("rec:total", "desp:total"), modelo = c("M5s4", "B0"), membros = "", oficial = TRUE))
  t3 <- informe_texto(I)$blocos[3]
  expect_match(t3, "expansão real de 6,8% em 2025, quase o dobro do crescimento projetado para a arrecadação \\(3,6%\\)\\[1\\]")
  expect_match(t3, "Até agosto, as despesas primárias cresciam acima da arrecadação em 18 das 27 UFs")
  cr$cresc_real_pct <- c(5, 5.2); I$proj$cresc <- cr; expect_match(informe_texto(I)$blocos[3], "em linha com o")
  cr$cresc_real_pct <- c(5, -1); I$proj$cresc <- cr; expect_match(informe_texto(I)$blocos[3], "queda real de 1,0%")
})

test_that("RMSE agregado: procura por serie, corte, modelo e membros; ausente vira NA", {
  rm <- data.frame(serie = "rec:total", corte = 4L, modelo = c("M5s4", "M5s4", "B0"), membros = c("M1+M2+M3", "M1+M3", ""), n_anos = 6L, rmse_pp = c(1.7, 1.5, 2.6), me_pp = 0, n_anos_sem_2020_21 = 4L, rmse_pp_sem_2020_21 = c(0.9, 0.8, 1.9), anos = "x")
  expect_equal(rmse_agregado(rm, "rec:total", 4L, "M5s4", "M1+M2+M3")$rmse_pp, 1.7); expect_equal(rmse_agregado(rm, "rec:total", 4L, "B0")$rmse_pp_sem_2020_21, 1.9)
  expect_true(is.na(rmse_agregado(rm, "desp:total", 4L, "B0")$rmse_pp)); expect_true(is.na(rmse_agregado(NULL, "rec:total", 4L, "B0")$n_anos))
})

test_that("crescimento projetado: RMSE ao lado do projetado; municipios e regionais pendentes", {
  I <- mk_I(); cr <- data.frame(conceito = "consolidado", serie = c("rec:total", "desp:total"), modelo = c("B0", "M3"), oficial = TRUE, cresc_real_pct = c(3, 5), acum_real_pct = c(2, 4), stringsAsFactors = FALSE)
  I$proj <- list(corte = 4L, cresc = cr, uf = NULL, plano = data.frame(serie = c("rec:total", "desp:total"), modelo = c("B0", "M3"), membros = "", oficial = TRUE))
  I$rmse <- data.frame(serie = c("rec:total", "desp:total"), corte = 4L, modelo = c("B0", "M3"), membros = "", n_anos = c(6L, 4L), rmse_pp = c(2.6, 0.4), me_pp = 0, n_anos_sem_2020_21 = c(4L, 4L), rmse_pp_sem_2020_21 = c(1.9, 0.4), anos = "x")
  x <- informe_crescimento(I); e <- x[x$esfera == "estados" & x$status == "oficial", ]
  expect_equal(e$rmse_pp, c(2.6, 0.4)); expect_equal(e$rmse_pp_sem_2020_21, c(1.9, 0.4)); expect_equal(e$n_anos_rmse, c(6L, 4L)); expect_equal(e$acumulado_real_pct, c(2, 4))
  expect_true(all(x$status[x$esfera %in% c("municípios", "regionais")] == "pendente"))
})

test_that("P2 estados: acumulado real e nominal ate o ultimo bimestre completo", {
  ind <- function(a, b) 1.01^((a - 2024) * 6 + b)
  cat <- rbind(data.frame(exercicio = 2024L, periodo = 1:2, serie = "desp:total", valor_bi = c(10, 10), n_ufs = 27L, mesmo_bim_ano_ant_bi = NA, var_pct = NA),
               data.frame(exercicio = 2025L, periodo = 1:2, serie = "desp:total", valor_bi = c(11, 12), n_ufs = 27L, mesmo_bim_ano_ant_bi = c(10, 10), var_pct = c(10, 20)))
  d <- informe_p2(cat, ind, 2025L); a <- d[grepl("acum", d$periodo), ]
  expect_equal(a$valor_bi, 23); expect_equal(a$var_nominal_pct, 15); expect_true(a$var_real_pct < a$var_nominal_pct)
})

test_that("sinais: classe do gap pela regra adaptada, P2 anual sem despesa nao reconstruida, erro do SRW em eleicao", {
  ref <- data.frame(exercicio = 2023:2025, r_real = c(-0.008, -0.001, -0.006))
  expect_equal(sinais_classe_gap(-0.031, 2026, ref)$classe, "atipico"); expect_equal(sinais_classe_gap(-0.004, 2026, ref)$classe, "consistente")
  expect_equal(sinais_classe_gap(0.01, 2026, ref[1, ])$classe, "sem_referencia")     # fronteira de 2023: um so ano na serie
  fh <- expand.grid(cod_ibge = 1:27, exercicio = 2017:2018, periodo = 1:6, serie = c("rec:total", "desp:total"), stringsAsFactors = FALSE); fh$valor <- ifelse(fh$serie == "rec:total", 1e9, ifelse(fh$exercicio == 2017, 0, 0.9e9))
  p <- sinais_p2_anual(fh); expect_equal(p$exercicio, 2018L); expect_equal(p$p2_bi, 27 * 6 * 0.1)
  s <- serie(c(rep(1, 12), rep(2, 12), rep(3, 12), rep(4, 12)), 2018)
  e <- sinais_srw_eleicao(list(estaduais = s), 6L, 2022L, anos = 2019:2021); expect_equal(e$resumo$n_eleicao, 0L); expect_true(e$ano_alvo_eleicao)
})

test_that("planilha: abas, marca de teste, Sinais interna fora do Resumo e do texto, comentario do analista vazio", {
  skip_if_not_installed("openxlsx")
  I <- mk_I(); I$fh_tot <- NULL; f <- tempfile(fileext = ".xlsx"); m <- tempfile(fileext = ".md")
  suppressWarnings(escrever_informe(I, f, m))
  expect_equal(openxlsx::getSheetNames(f), c("Resumo", "P1", "Crescimento projetado", "P2 estados", "Gap", "Alertas", "Notas", "Sinais"))
  s <- openxlsx::read.xlsx(f, "Sinais", colNames = FALSE); expect_match(s[1, 1], "USO INTERNO, NÃO PUBLICAR")
  r <- unlist(openxlsx::read.xlsx(f, "Resumo", colNames = FALSE)); expect_match(r[1], "RODADA DE TESTE"); expect_false(any(grepl("m3", r, ignore.case = FALSE)))
  p <- unlist(openxlsx::read.xlsx(f, "P1", colNames = FALSE)); expect_false(any(grepl("m3", p)))
  txt <- readLines(m, encoding = "UTF-8"); expect_false(any(grepl("m3|Sinais|gap implícito", txt))); expect_match(tail(txt, 1), "^Comentário do analista: $")
})
