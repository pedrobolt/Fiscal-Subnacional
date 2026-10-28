# E2.10/E3.5: meta de resultado primário da LDO nos RREO dos estados (Anexo 06) já baixados. Não chama a API.
# Saída: outputs/ldo_meta_estados.csv (UF x ano x bimestre) e outputs/ldo_meta_resumo.csv (agregado por ano).
source("R/utils_io.R", encoding = "UTF-8")
invisible(lapply(list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE), source))
arqs <- list.files("data/raw/rreo/E", pattern = "_b[1-6]_a06\\.json\\.gz$", recursive = TRUE, full.names = TRUE)
linhas <- lapply(arqs, function(f) {
  d <- ler_rreo(f); d <- d[grepl("^RREO6MetaDeResultadoPrimario", d$cod_conta), ]
  if (!nrow(d)) return(NULL)
  d <- d[1, ]; data.frame(ano = d$exercicio, bimestre = d$periodo, uf = d$uf, valor = d$valor)
})
m <- do.call(rbind, linhas); m <- m[order(m$ano, m$uf, m$bimestre), ]
dir.create("outputs", showWarnings = FALSE); gravar_csv(m, "outputs/ldo_meta_estados.csv")
res <- do.call(rbind, lapply(split(m, m$ano), function(d) {
  b <- function(k) d[d$bimestre == k, ]
  w <- merge(b(1)[c("uf", "valor")], b(6)[c("uf", "valor")], by = "uf", suffixes = c("_b1", "_b6"))
  data.frame(ano = d$ano[1], ufs = length(unique(d$uf)), meta_b1_bi = sum(b(1)$valor, na.rm = TRUE) / 1e9,
             meta_b6_bi = sum(b(6)$valor, na.rm = TRUE) / 1e9, ufs_meta_alterada = sum(abs(w$valor_b1 - w$valor_b6) > 1, na.rm = TRUE))
}))
gravar_csv(res, "outputs/ldo_meta_resumo.csv"); print(res, digits = 3)
