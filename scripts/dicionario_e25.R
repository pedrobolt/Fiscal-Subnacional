# E2.5: gera data/dicionario_contas_estados.csv e data/dicionario_colunas_estados.csv a partir do bruto local (RREO estadual)
# e roda o fechamento do Anexo 6 e a conferência acumulado -> fluxo. Resultados em outputs/e25_*.csv (git-ignored).
# Uso: Rscript scripts/dicionario_e25.R   (precisa de data/raw/rreo/E)
source("R/utils_io.R", encoding = "UTF-8")
for (f in c("R/download/snapshots.R", "R/download/siconfi_rreo.R", "R/transform/rreo.R", "R/transform/dicionario_contas.R"))
  source(f, encoding = "UTF-8")
rreo <- ler_rreo_pasta("data/raw/rreo", "E")
cat("linhas do bruto:", nrow(rreo), "\n")
cols <- tabela_colunas(rreo)
contas <- dicionario_contas_estados(rreo)
gravar_dicionario(cols, "data/dicionario_colunas_estados.csv")
gravar_dicionario(contas, "data/dicionario_contas_estados.csv")
cob <- cobertura_dicionario(rreo, ler_dicionario("data/dicionario_contas_estados.csv"), ler_dicionario("data/dicionario_colunas_estados.csv"))
cat("sem conta no dicionário:", nrow(cob$contas), "| sem coluna no dicionário:", nrow(cob$colunas), "\n")
cat("contas nao curadas (memo_nao_curado):", sum(contas$papel == "memo_nao_curado"), "\n")
dir.create("outputs", showWarnings = FALSE)
f <- fechar_anexo6(rreo, ler_dicionario("data/dicionario_contas_estados.csv"), ler_dicionario("data/dicionario_colunas_estados.csv"))
gravar_csv(f, "outputs/e25_fechamento.csv")
resumo <- do.call(rbind, lapply(split(f, f$layout), function(z) data.frame(layout = z$layout[1], arquivos = nrow(z),
  rec_ok = sum(z$rec_ok, na.rm = TRUE), rec_n = sum(!is.na(z$rec_ok)), desp_ok = sum(z$desp_ok, na.rm = TRUE), desp_n = sum(!is.na(z$desp_ok)),
  res_ok = sum(z$resultado_ok, na.rm = TRUE), res_n = sum(!is.na(z$resultado_ok)))))
print(resumo, row.names = FALSE)

# ---- Reserva de contingência com valor pago? ----
res <- sinalizar_reserva_paga(rreo)
cat("\nReserva de contingência com valor pago:", nrow(res), "linha(s)\n"); if (nrow(res)) print(res[, c("cod_ibge", "exercicio", "periodo", "coluna", "valor")])

# ---- Exceções do fechamento (arquivos que não fecham) ----
exc <- f[is.na(f$desp_ok) | !f$desp_ok | is.na(f$resultado_ok) | !f$resultado_ok | !f$rec_ok, ]
gravar_csv(exc, "outputs/e25_fechamento_excecoes.csv")
cat("\nExceções do fechamento:", nrow(exc), "\n"); print(exc[, c("cod_ibge", "exercicio", "periodo", "layout", "desp_total", "resultado_publicado", "desp_ok", "resultado_ok")], row.names = FALSE)

# ---- E2.6: acumulado -> fluxo contra a coluna "No Bimestre (b)" do Anexo 1 (receitas) ----
dc <- ler_dicionario("data/dicionario_colunas_estados.csv")
a1 <- aplicar_dicionario(rreo[rreo$anexo == "RREO-Anexo 01", ], ler_dicionario("data/dicionario_contas_estados.csv"), dc)
ac <- a1[a1$estagio == "receita_realizada" & !grepl("Intra", a1$cod_conta), c("cod_ibge", "exercicio", "periodo", "cod_conta", "estagio", "valor")]
ac <- ac[!duplicated(ac[, c("cod_ibge", "exercicio", "periodo", "cod_conta")]), ]
nb <- a1[a1$estagio == "receita_realizada_no_bimestre", c("cod_ibge", "exercicio", "periodo", "cod_conta", "valor")]
nb <- nb[!duplicated(nb[, c("cod_ibge", "exercicio", "periodo", "cod_conta")]), ]
fl <- acumulado_para_fluxo(ac)
m <- merge(fl, nb, by = c("cod_ibge", "exercicio", "periodo", "cod_conta"), suffixes = c("", "_publicado"))
m <- m[!is.na(m$fluxo), ]
m$dif <- m$fluxo - m$valor_publicado
cat(sprintf("\nAcumulado -> fluxo vs 'No Bimestre (b)' (Anexo 1, receitas): %d linhas comparadas; |dif| <= 1: %d (%.2f%%); maior |dif|: %.2f\n",
            nrow(m), sum(abs(m$dif) <= 1), 100 * mean(abs(m$dif) <= 1), max(abs(m$dif))))
gravar_csv(m[abs(m$dif) > 1, ], "outputs/e25_fluxo_divergencias.csv")
cat("com bimestre anterior ausente (fluxo NA):", sum(fl$acum_anterior_ausente), "de", nrow(fl), "\n")
