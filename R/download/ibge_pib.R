# PIB nominal anual do IBGE (E2.3), para o denominador do % do PIB no backtest (contrato: não usar o PIB
# acumulado em 12 meses do BCB). Fonte: SIDRA tabela 6784 (Contas Nacionais anuais, v9808 = PIB a preços correntes,
# R$ milhões) e, para os anos ainda ausentes dela, a soma dos quatro trimestres da tabela 1846 (v585, PIB a preços de mercado).

SIDRA_URL <- "https://apisidra.ibge.gov.br/values"
SIDRA_PIB_ANUAL <- "t/6784/n1/all/v/9808/p/all"
SIDRA_PIB_TRIM  <- "t/1846/n1/all/v/585/p/all/c11255/90707"

#' Baixa os dois recortes do SIDRA e guarda o JSON bruto em `pasta` (um arquivo por tabela e data de consulta).
#' Retorna c(anual = <arquivo>, trimestral = <arquivo>).
baixar_pib_ibge <- function(pasta = "data/raw", hoje = Sys.Date(), tentativas = 4) {
  dir.create(pasta, showWarnings = FALSE, recursive = TRUE)
  um <- function(caminho, nome) {
    destino <- file.path(pasta, sprintf("ibge_pib_%s_%s.json", nome, format(hoje, "%Y%m%d")))
    if (file.exists(destino)) return(destino)
    tmp <- tempfile(fileext = ".json")
    for (i in seq_len(tentativas)) {
      ok <- tryCatch({
        utils::download.file(paste(SIDRA_URL, caminho, sep = "/"), tmp, quiet = TRUE, method = "libcurl")
        x <- jsonlite::fromJSON(tmp)
        is.data.frame(x) && nrow(x) > 1
      }, error = function(e) FALSE, warning = function(w) FALSE)
      if (isTRUE(ok)) { file.copy(tmp, destino); return(destino) }
      Sys.sleep(2 * i)
    }
    stop("Falha ao baixar do SIDRA: ", caminho, call. = FALSE)
  }
  c(anual = um(SIDRA_PIB_ANUAL, "6784"), trimestral = um(SIDRA_PIB_TRIM, "1846"))
}

#' PIB nominal anual (R$ bi) a partir dos dois JSON do SIDRA. Anos da tabela 6784 usam-na; anos posteriores usam a soma de
#' quatro trimestres completos. Retorna data.frame(ano, pib_bi, fonte ["6784" ou "1846"]).
pib_ibge_anual <- function(arq_anual, arq_trim) {
  a <- jsonlite::fromJSON(arq_anual); a <- a[-1, ]
  a <- a[a$D2C == "9808", ]
  anual <- data.frame(ano = as.integer(a$D3C), pib_bi = as.numeric(a$V) / 1000, fonte = "6784")
  t <- jsonlite::fromJSON(arq_trim); t <- t[-1, ]
  t$ano <- as.integer(substr(t$D3C, 1, 4)); t$v <- as.numeric(t$V)
  n <- tapply(t$v, t$ano, length); soma <- tapply(t$v, t$ano, sum)
  anos_ok <- as.integer(names(n)[n == 4])
  trim <- data.frame(ano = anos_ok, pib_bi = as.numeric(soma[as.character(anos_ok)]) / 1000, fonte = "1846")
  trim <- trim[!(trim$ano %in% anual$ano), ]
  out <- rbind(anual, trim); out[order(out$ano), ]
}

#' PIB acumulado nos últimos quatro trimestres publicados (R$ bi), só como aproximação ilustrativa do ano corrente
#' quando `premissas.yml` não está disponível. Retorna c(pib_bi, ultimo_trimestre).
pib_ultimos_4_trimestres <- function(arq_trim) {
  t <- jsonlite::fromJSON(arq_trim); t <- t[-1, ]; t <- t[order(t$D3C), ]
  u <- utils::tail(t, 4)
  list(pib_bi = sum(as.numeric(u$V)) / 1000, ultimo_trimestre = u$D3N[4])
}
