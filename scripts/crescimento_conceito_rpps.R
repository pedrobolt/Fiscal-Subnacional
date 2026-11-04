# Tamanho da diferenca de conceito (COM x SEM RPPS): crescimento real de receita e despesa primarias dos estados, 2025 e acumulado 2026 (b1-b4).
# Deflator: IPCA mensal (SGS 433), indice medio dos dois meses do bimestre (periodo a periodo). Saida: outputs/crescimento_conceito_rpps.csv (git-ignored)
# Uso: LC_ALL=C.UTF-8 Rscript scripts/crescimento_conceito_rpps.R   (precisa do bruto local RREO estados; acesso ao SGS)
source("R/utils_io.R", encoding = "UTF-8")
for (f in c("R/download/snapshots.R", "R/download/siconfi_rreo.R", "R/transform/rreo.R", "R/transform/dicionario_contas.R", "R/quality/alertas.R")) carregar_r(f)
dic <- ler_dicionario("data/dicionario_contas_estados.csv"); dc <- ler_dicionario("data/dicionario_colunas_estados.csv")
rreo <- ler_rreo_pasta(dados("data/raw/rreo"), "E")
dic_sem <- dic; dic_sem$papel[dic_sem$anexo == "RREO-Anexo 06" & dic_sem$rpps %in% "incluido"] <- "memo_rpps"
ip <- jsonlite::fromJSON("https://api.bcb.gov.br/dados/serie/bcdata.sgs.433/dados?formato=json&dataInicial=01/01/2024&dataFinal=31/12/2026")
ip$mes <- as.Date(ip$data, "%d/%m/%Y"); ip$v <- as.numeric(ip$valor) / 100; ip <- ip[order(ip$mes), ]; ip$ind <- cumprod(1 + ip$v)
ind_bim <- function(ex, b) mean(ip$ind[ip$mes %in% as.Date(sprintf("%d-%02d-01", ex, (2 * b - 1):(2 * b)))])
UF3 <- c(33L, 41L, 43L); linhas <- list()
for (v in c("com", "sem")) {
  fl <- fluxos_a6_categorias(rreo, if (v == "sem") dic_sem else dic, dc)
  fl$lado <- ifelse(grepl("^rec:", fl$serie), "receita", ifelse(grepl("^desp:", fl$serie), "despesa", NA)); fl <- fl[!is.na(fl$lado), ]
  fl <- fl[fl$exercicio %in% 2024:2026, ]
  fl$real <- fl$valor / mapply(ind_bim, fl$exercicio, fl$periodo)
  a <- aggregate(real ~ cod_ibge + lado + exercicio + periodo, fl, sum)
  cmp <- function(jan, ex0, ex1, bmax, ufs, rotulo) {
    x <- a[a$periodo <= bmax & a$cod_ibge %in% ufs, ]
    ok <- aggregate(periodo ~ cod_ibge + lado + exercicio, x, length); ok <- ok[ok$periodo == bmax, ]
    k <- Reduce(intersect, list(unique(ok$cod_ibge[ok$exercicio == ex0 & ok$lado == "receita"]), unique(ok$cod_ibge[ok$exercicio == ex1 & ok$lado == "receita"]),
                                unique(ok$cod_ibge[ok$exercicio == ex0 & ok$lado == "despesa"]), unique(ok$cod_ibge[ok$exercicio == ex1 & ok$lado == "despesa"])))
    s <- aggregate(real ~ lado + exercicio, x[x$cod_ibge %in% k, ], sum)
    do.call(rbind, lapply(c("receita", "despesa"), function(l) data.frame(versao = v, janela = jan, grupo = rotulo, lado = l, n_uf = length(k),
      base_real_bi = s$real[s$lado == l & s$exercicio == ex0] / 1e9, atual_real_bi = s$real[s$lado == l & s$exercicio == ex1] / 1e9,
      cresc_real_pct = 100 * (s$real[s$lado == l & s$exercicio == ex1] / s$real[s$lado == l & s$exercicio == ex0] - 1))))
  }
  todas <- sort(unique(a$cod_ibge))
  for (g in list(list("todas", todas), list("sem RJ/PR/RS", setdiff(todas, UF3)), list("RJ", 33L), list("PR", 41L), list("RS", 43L))) {
    linhas[[length(linhas) + 1]] <- cmp("2025 vs 2024 (b1-b6)", 2024L, 2025L, 6L, g[[2]], g[[1]])
    linhas[[length(linhas) + 1]] <- cmp("2026 vs 2025 (b1-b4)", 2025L, 2026L, 4L, g[[2]], g[[1]])
  }
}
r <- do.call(rbind, linhas); gravar_csv(r, dados("outputs/crescimento_conceito_rpps.csv"))
print(transform(r, base_real_bi = round(base_real_bi, 1), atual_real_bi = round(atual_real_bi, 1), cresc_real_pct = round(cresc_real_pct, 1)), row.names = FALSE)
