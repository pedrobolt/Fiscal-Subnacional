# E2.8b: regeneracao da deteccao do inicio da reclassificacao de pessoal (regra: docs/nota_quebras.md, secao 6, fixada antes de computar).
# Duas versoes da serie de pessoal do Anexo 6: SEM RPPS (contas "com fontes RPPS" fora) e COM RPPS (serie oficial desde o #52).
# Uso: LC_ALL=C.UTF-8 Rscript scripts/reclassificacao_e28b.R   (precisa do bruto local: RREO estados e RGF)
# Saidas (outputs/, git-ignored): reclass_runs_{sem,com}.csv, reclass_yoy_{sem,com}.csv, reclass_grade_{sem,com}.csv, reclass_rpps_diferenca.csv
source("R/utils_io.R", encoding = "UTF-8")
for (f in c("R/download/snapshots.R", "R/download/siconfi_rreo.R", "R/download/extrato.R", "R/transform/rreo.R", "R/transform/dicionario_contas.R",
            "R/quality/alertas.R", "R/quality/reclassificacao.R")) carregar_r(f)
dir.create(dados("outputs"), showWarnings = FALSE)
dic <- ler_dicionario("data/dicionario_contas_estados.csv"); dc <- ler_dicionario("data/dicionario_colunas_estados.csv")
rreo <- ler_rreo_pasta(dados("data/raw/rreo"), "E")
rg <- pessoal_rgf_mensal()

# SEM RPPS: as duas contas "com fontes RPPS" saem das folhas (o pessoal fica so com a linha "Pessoal e Encargos Sociais")
dic_sem <- dic
dic_sem$papel[dic_sem$anexo == "RREO-Anexo 06" & dic_sem$rpps %in% "incluido"] <- "memo_rpps"
versoes <- list(sem = dic_sem, com = dic)
UF3 <- c(RJ = 33L, PR = 41L, RS = 43L)
res <- list()
for (v in names(versoes)) {
  fl <- fluxos_a6_categorias(rreo, versoes[[v]], dc)
  yy <- yoy_pessoal_rreo_rgf(fl, rg)
  pes <- fl[fl$serie == "desp:pessoal", c("cod_ibge", "exercicio", "periodo", "valor")]
  dsp <- aggregate(valor ~ cod_ibge + exercicio + periodo, fl[grepl("^desp:", fl$serie), ], sum)
  runs <- marcar_janela(runs_reclassificacao(yy))
  runs <- excedente_runs(runs, pes, dsp, yy)
  runs$versao <- v
  gravar_csv(yy, dados(sprintf("outputs/reclass_yoy_%s.csv", v)))
  gravar_csv(runs, dados(sprintf("outputs/reclass_runs_%s.csv", v)))
  gr <- grade_inicio(yy, UF3); gr$versao <- v
  gravar_csv(gr, dados(sprintf("outputs/reclass_grade_%s.csv", v)))
  res[[v]] <- list(fl = fl, yy = yy, runs = runs, grade = gr, pes = pes)
  cat(sprintf("\n==== Versao %s: %d corridas (todas as UFs), %d na janela 2024+ ====\n", toupper(v), nrow(runs), sum(runs$na_janela)))
  print(transform(runs[runs$na_janela, ], exc_bi = round(excedente / 1e9, 2), pct_desp = round(100 * excedente_sobre_despesa, 1),
                  rreo_pct = round(100 * rreo_yoy_medio), rgf_pct = round(100 * rgf_yoy_medio))[, c("cod_ibge", "ini_exercicio", "ini_periodo", "fim_exercicio", "fim_periodo", "n_bim", "rreo_pct", "rgf_pct", "exc_bi", "pct_desp")], row.names = FALSE)
  cat("\nCorridas antes da janela (informativas): UFs", paste(sort(unique(runs$cod_ibge[!runs$na_janela])), collapse = ", "), "\n")
}

# Diferenca COM - SEM no pessoal (parte do pessoal com fontes RPPS) para RJ/PR/RS: teste da hipotese de absorcao / dupla contagem
d <- merge(res$com$pes, res$sem$pes, by = c("cod_ibge", "exercicio", "periodo"), suffixes = c("_com", "_sem"))
d$rpps_pessoal <- d$valor_com - d$valor_sem; d$parcela_rpps <- d$rpps_pessoal / d$valor_com
gravar_csv(d, dados("outputs/reclass_rpps_diferenca.csv"))
cat("\n==== Parcela das fontes RPPS no pessoal (COM - SEM) / COM, 2023-2026, RJ/PR/RS ====\n")
dd <- d[d$cod_ibge %in% UF3 & d$exercicio >= 2023, ]
print(reshape(transform(dd, p = round(100 * parcela_rpps, 1))[, c("cod_ibge", "exercicio", "periodo", "p")], idvar = c("cod_ibge", "exercicio"), timevar = "periodo", direction = "wide"), row.names = FALSE)

cat("\n==== yoy do pessoal (%), RJ/PR/RS, 2024-2026: RREO sem | RREO com | RGF ====\n")
a <- merge(res$sem$yy[, c("cod_ibge", "exercicio", "periodo", "rreo_yoy", "rgf_yoy")], res$com$yy[, c("cod_ibge", "exercicio", "periodo", "rreo_yoy")],
           by = c("cod_ibge", "exercicio", "periodo"), suffixes = c("_sem", "_com"))
a <- a[a$cod_ibge %in% UF3 & a$exercicio >= 2024, ]
print(transform(a, rreo_sem = round(100 * rreo_yoy_sem), rreo_com = round(100 * rreo_yoy_com), rgf = round(100 * rgf_yoy))[, c("cod_ibge", "exercicio", "periodo", "rreo_sem", "rreo_com", "rgf")], row.names = FALSE)

cat("\n==== Sensibilidade (grade): inicio de RJ/PR/RS, sem RPPS ====\n")
print(reshape(res$sem$grade[res$sem$grade$persist == 2L, c("x", "pp", "cod_ibge", "inicio")], idvar = c("x", "pp"), timevar = "cod_ibge", direction = "wide"), row.names = FALSE)
cat("\n==== Sensibilidade (grade): inicio de RJ/PR/RS, com RPPS ====\n")
print(reshape(res$com$grade[res$com$grade$persist == 2L, c("x", "pp", "cod_ibge", "inicio")], idvar = c("x", "pp"), timevar = "cod_ibge", direction = "wide"), row.names = FALSE)
