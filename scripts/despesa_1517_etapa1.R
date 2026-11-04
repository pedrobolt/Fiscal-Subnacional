# Despesa 2015-17, etapa 1 (sem download; criterio fixado em docs/proposta_e62_e5_fase2.md, 2.3, e na decisao de 04/11/2026):
# compara as despesas PAGAS dos grupos primarios do Anexo 1 com a PAGA do Anexo 6 (total da despesa primaria), 2018-2025, UF-ano no b6.
# Referencias: (i) paga do A6 (mesma base: diferenca de consistencia entre anexos); (ii) caixa do A6 = paga + RP processados pagos + RPNP pagos
# (o que a reconstrucao precisa acrescentar com os RP pagos; mostra o tamanho do que o Anexo 7 teria de cobrir).
# Variante A (fixada antes de rodar): Pessoal + Outras despesas correntes + Investimentos + Inversoes financeiras, mais as contas intraorcamentarias
# correspondentes; sem juros e sem amortizacao. Variante B (sensibilidade): A sem inversoes financeiras.
# Variante C (DECLARADA APOS VER O RESULTADO DE A e B, nao fixada antes): como A, mas sem as contas intraorcamentarias ate 2022 (o A6 de 2018-22 nao as inclui;
# a variante A concorda com o A6 so de 2023 em diante). Reportada ao lado de A, sem substitui-la.
# Criterio: diferenca <= 1% do caixa do A6 em >= 90% dos UF-anos. Saidas: outputs/despesa1517_etapa1_{ufano,resumo}.csv (git-ignored).
# Uso: LC_ALL=C.UTF-8 Rscript scripts/despesa_1517_etapa1.R   (precisa do bruto local do RREO estados)
source("R/utils_io.R", encoding = "UTF-8")
carregar_r(c("R/download/snapshots.R", "R/download/siconfi_rreo.R", "R/transform/rreo.R"))
rreo <- ler_rreo_pasta(dados("data/raw/rreo"), "E")
rreo <- rreo[rreo$periodo == 6 & rreo$exercicio %in% 2018:2025, ]
col <- gsub("\\s+", " ", rreo$coluna)
a1 <- rreo[rreo$anexo == "RREO-Anexo 01" & grepl("^DESPESAS PAGAS AT", col), ]
grp_a <- c("PessoalEEncargosSociais", "OutrasDespesasCorrentes", "Investimentos", "InversoesFinanceiras")
grp_b <- setdiff(grp_a, "InversoesFinanceiras")
soma <- function(g, intra = "sempre") { x <- a1[a1$cod_conta %in% c(g, paste0(g, "Intra")), ]; x <- x[!duplicated(x[, c("cod_ibge", "exercicio", "cod_conta")]), ]
  if (intra == "desde2023") x <- x[!grepl("Intra$", x$cod_conta) | x$exercicio >= 2023L, ]
  r <- aggregate(valor ~ cod_ibge + exercicio, x, sum); r }
C <- soma(grp_a, "desde2023"); names(C)[3] <- "a1_C"
A <- soma(grp_a); names(A)[3] <- "a1_A"; B <- soma(grp_b); names(B)[3] <- "a1_B"
a6 <- rreo[rreo$anexo == "RREO-Anexo 06" & rreo$cod_conta == "RREO6TotalDespesaPrimaria", ]
c6 <- gsub("\\s+", " ", a6$coluna)
pega <- function(pad) { x <- a6[grepl(pad, c6), ]; x <- x[!duplicated(x[, c("cod_ibge", "exercicio", "coluna")]), ]; r <- aggregate(valor ~ cod_ibge + exercicio, x, sum); r }
P <- pega("^DESPESAS PAGAS \\(a\\)$"); names(P)[3] <- "a6_paga"
RP <- pega("PROCESSADOS PAGOS \\(b\\)$"); names(RP)[3] <- "a6_rp_proc"
RN <- pega("^PAGOS \\(c\\)$"); names(RN)[3] <- "a6_rpnp"
m <- Reduce(function(x, y) merge(x, y, by = c("cod_ibge", "exercicio"), all.x = TRUE), list(P, RP, RN, A, B, C))
m$a6_caixa <- m$a6_paga + ifelse(is.na(m$a6_rp_proc), 0, m$a6_rp_proc) + ifelse(is.na(m$a6_rpnp), 0, m$a6_rpnp)
m$dif_paga_A <- (m$a1_A - m$a6_paga) / m$a6_caixa; m$dif_paga_B <- (m$a1_B - m$a6_paga) / m$a6_caixa
m$dif_paga_C <- (m$a1_C - m$a6_paga) / m$a6_caixa
m$dif_caixa_A <- (m$a1_A - m$a6_caixa) / m$a6_caixa
gravar_csv(m, dados("outputs/despesa1517_etapa1_ufano.csv"))
r1 <- function(v, tol = 0.01) c(n = sum(!is.na(v)), pct_dentro = round(100 * mean(abs(v) <= tol, na.rm = TRUE), 1), mediana = round(100 * median(v, na.rm = TRUE), 2),
                                p05 = round(100 * quantile(v, .05, na.rm = TRUE), 2), p95 = round(100 * quantile(v, .95, na.rm = TRUE), 2))
res <- rbind(data.frame(medida = "A1 (A) - paga A6", t(r1(m$dif_paga_A))), data.frame(medida = "A1 (B, sem inversoes) - paga A6", t(r1(m$dif_paga_B))),
             data.frame(medida = "A1 (C, pos-resultado) - paga A6", t(r1(m$dif_paga_C))), data.frame(medida = "A1 (A) - caixa A6 (sem RP pagos)", t(r1(m$dif_caixa_A))))
gravar_csv(res, dados("outputs/despesa1517_etapa1_resumo.csv"))
cat("Criterio: |dif| <= 1% do caixa do A6, UF-anos no b6, 2018-2025 (dif em % do caixa)\n"); print(res, row.names = FALSE)
po <- data.frame(exercicio = sort(unique(m$exercicio)), A_pct_dentro = round(100 * tapply(abs(m$dif_paga_A) <= 0.01, m$exercicio, mean, na.rm = TRUE), 1),
                 C_pct_dentro = round(100 * tapply(abs(m$dif_paga_C) <= 0.01, m$exercicio, mean, na.rm = TRUE), 1),
                 rp_pagos_pct_caixa_mediana = round(100 * tapply((m$a6_caixa - m$a6_paga) / m$a6_caixa, m$exercicio, median, na.rm = TRUE), 2))
gravar_csv(po, dados("outputs/despesa1517_etapa1_ano.csv")); cat("\nPor ano: % de UF-anos dentro de 1% (A, C) e RP pagos em % do caixa (mediana)\n"); print(po, row.names = FALSE)
cat("\nPiores UF-anos (variante A vs paga A6):\n"); print(head(m[order(-abs(m$dif_paga_A)), c("cod_ibge", "exercicio", "dif_paga_A", "dif_paga_B")], 12), row.names = FALSE)
