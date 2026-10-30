# E2.9 (reduzida): planilha de conferencia minima. 3 UFs (SP, RJ, MG), bimestre mais recente com os tres, totais do Anexo 6 (acumulado no ano).
# O valor oficial e lido por humano no RREO publicado no site da SEFAZ do proprio estado. Saida: outputs/e29_planilha.csv (git-ignored).
# Uso: LC_ALL=C.UTF-8 Rscript scripts/e29_planilha.R
source("R/utils_io.R", encoding = "UTF-8")
for (f in c("R/download/snapshots.R", "R/download/siconfi_rreo.R", "R/transform/rreo.R")) source(f, encoding = "UTF-8")
r <- ler_rreo_pasta("data/raw/rreo", "E")
a6 <- r[r$anexo == "RREO-Anexo 06" & r$cod_ibge %in% c(31, 33, 35), ]
ex <- max(a6$exercicio); pe <- min(tapply(a6$periodo[a6$exercicio == ex], a6$cod_ibge[a6$exercicio == ex], max))
x <- a6[a6$exercicio == ex & a6$periodo == pe, ]
pega <- function(conta, col) { s <- x[x$cod_conta == conta & x$coluna == col, ]; s <- s[order(s$cod_ibge, s$baixado_em), ]; s <- s[!duplicated(s$cod_ibge, fromLast = TRUE), ]; setNames(s$valor, s$uf) }
rec <- pega("ReceitaPrimariaTotalExcetoFontesRPPS", "RECEITAS REALIZADAS (a)")
pg <- pega("DespesaPrimariaTotalExcetoFontesRPPS", "DESPESAS PAGAS (a)"); rpp <- pega("DespesaPrimariaTotalExcetoFontesRPPS", "RESTOS A PAGAR PROCESSADOS PAGOS (b)")
rpn <- pega("DespesaPrimariaTotalExcetoFontesRPPS", "PAGOS (c)"); res <- pega("ResultadoPrimarioSemRPPSAcimaDaLinha", "VALOR")
ufs <- c("SP", "RJ", "MG")
d <- data.frame(uf = ufs, exercicio = ex, bimestre = pe, receita_primaria = rec[ufs], despesa_paga_a = pg[ufs], rp_processados_pagos_b = rpp[ufs], rp_nao_processados_pagos_c = rpn[ufs])
d$despesa_caixa_a_b_c <- d$despesa_paga_a + d$rp_processados_pagos_b + d$rp_nao_processados_pagos_c
d$resultado_publicado <- res[ufs]; d$receita_menos_despesa <- d$receita_primaria - d$despesa_caixa_a_b_c
d$fecha_pipeline <- abs(d$receita_menos_despesa - d$resultado_publicado) <= 1000
for (c in c("receita_primaria", "despesa_paga_a", "rp_processados_pagos_b", "rp_nao_processados_pagos_c", "despesa_caixa_a_b_c", "resultado_publicado"))
  d[[paste0(c, "_site")]] <- NA_real_                 # a preencher por quem le o PDF
d$obs <- ""
dir.create("outputs", showWarnings = FALSE); gravar_csv(d, "outputs/e29_planilha.csv")
print(t(d[, 1:10]))
