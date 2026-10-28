# Leitor das transferências da STN (FPE por UF, FPM por município), E2.3/E4.1b. Os arquivos brutos são imutáveis:
# toda correção acontece aqui, com regra explícita, e fica registrada em `serie$tratamento`.
# Regras (27/10/2026): (i) meses normalizados para inteiro (há "1", "8" sem zero à esquerda); (ii) linhas repetidas entre
# arquivos sobrepostos são removidas só se os valores forem idênticos (valores diferentes = erro); (iii) mês ausente = NA,
# sem imputação; (iv) erro de escala (×100) só é corrigido se passar nos critérios de `corrigir_escala_stn`, senão NA.

#' Lê um CSV da STN e devolve as linhas de FPE (estados) ou FPM (municípios), uma por ente x ano x mês (soma dos decêndios).
ler_stn_arquivo <- function(arq, esfera = c("estados", "municipios")) {
  esfera <- match.arg(esfera)
  x <- data.table::fread(arq, sep = ";", encoding = "Latin-1", colClasses = "character", header = TRUE, fill = TRUE)
  p <- if (esfera == "estados") 0L else 1L          # municípios têm a coluna extra "Município" na frente
  col <- function(i) x[[i + p]]
  # Municípios: a partir de jul/2025 as parcelas extras de 1% do FPM (jul, set, dez; EC 55/2007, EC 84/2014 e EC 112/2021)
  # vêm em linhas próprias, com item e transferência "FPM 1%"; antes estavam dentro do "FPM". Somam-se ao FPM.
  itens <- if (esfera == "estados") "FPE" else c("FPM", "FPM 1%")
  if (ncol(x) < 8 + p) stop("Layout inesperado em ", arq, call. = FALSE)
  # Layout sem a coluna "Transferência" preenchida (ex.: mai/2018) não permite separar o FPE do que vai ao FUNDEB: sem linhas.
  k <- which(col(7) %in% itens & col(8) == col(7) & grepl("^[0-9]+$", col(2)))
  if (!length(k)) return(data.frame())
  num <- function(v) suppressWarnings(as.numeric(v[k]))
  d1 <- num(col(4)); d2 <- num(col(5)); d3 <- num(col(6))
  data.frame(ente = if (esfera == "estados") col(1)[k] else paste(x[[1]][k], col(1)[k], sep = "/"),
             ano = as.integer(col(2)[k]), mes = as.integer(col(3)[k]),
             item = col(7)[k], valor = d1 + d2 + d3, arquivo = basename(arq), stringsAsFactors = FALSE)
}

#' Todas as linhas de uma pasta (`data/raw/stn/estados` ou `.../municipios`), sem deduplicar.
ler_stn_pasta <- function(pasta, esfera = c("estados", "municipios")) {
  esfera <- match.arg(esfera)
  arqs <- sort(list.files(pasta, pattern = "\\.csv$", full.names = TRUE))
  if (!length(arqs)) stop("Nenhum CSV da STN em ", pasta, call. = FALSE)
  do.call(rbind, lapply(arqs, ler_stn_arquivo, esfera = esfera))
}

#' Remove linhas repetidas (ente x ano x mês) vindas de arquivos sobrepostos. Falha se os valores repetidos diferirem.
deduplicar_stn <- function(x) {
  chave <- paste(x$ente, x$item, x$ano, x$mes)
  dup <- duplicated(chave) | duplicated(chave, fromLast = TRUE)
  if (any(dup)) {
    v <- tapply(x$valor[dup], chave[dup], function(z) length(unique(round(z, 2))))
    if (any(v > 1)) stop("Linhas repetidas da STN com valores diferentes: ", paste(utils::head(names(v)[v > 1], 5), collapse = "; "), call. = FALSE)
  }
  attr_n <- sum(duplicated(chave))
  out <- x[!duplicated(chave), , drop = FALSE]; attr(out, "repetidas_removidas") <- attr_n
  out
}

#' Série nacional mensal a partir das linhas de FPE e FPM: valor_fpe, valor_fpm (R$ bi), nº de entes; mês sem linhas = NA.
serie_stn_mensal <- function(fpe, fpm, ate = NULL) {
  agg <- function(x, nome) {
    a <- stats::aggregate(cbind(valor = x$valor, n = 1) ~ ano + mes, data = x, FUN = sum)
    names(a)[3:4] <- c(paste0("valor_", nome), paste0("n_", nome)); a
  }
  a <- agg(fpe, "fpe"); b <- agg(fpm, "fpm")
  fim <- if (is.null(ate)) max(c(a$ano * 12 + a$mes - 1, b$ano * 12 + b$mes - 1)) else ate$ano * 12 + ate$mes - 1
  ini <- min(c(a$ano * 12 + a$mes - 1, b$ano * 12 + b$mes - 1))
  g <- data.frame(ano = (ini:fim) %/% 12, mes = (ini:fim) %% 12 + 1L)
  g <- merge(merge(g, a, all.x = TRUE), b, all.x = TRUE)
  g <- g[order(g$ano, g$mes), ]
  g$valor_fpe <- g$valor_fpe / 1e9; g$valor_fpm <- g$valor_fpm / 1e9
  g$tratamento <- ifelse(is.na(g$valor_fpe) | is.na(g$valor_fpm), "ausente", "original")
  rownames(g) <- NULL; g
}

#' Corrige erro de escala (×100). Gatilho: valor > 20x a mediana dos 12 meses vizinhos. Só corrige se, nos DOIS fluxos
#' (FPE e FPM) ao mesmo tempo: (a) o valor ÷100 fica entre 0,5x e 2x a mediana dos meses vizinhos (±6) e entre 0,5x e
#' 2x a mediana do mesmo mês nos anos adjacentes (±1); (b) a razão FPM/FPE do mês (inalterada pela escala comum) fica
#' no envelope das razões dos meses vizinhos (±12). Caso contrário o mês vira NA. `tratamento`: original, escala_100,
#' ausente, descartado_escala.
corrigir_escala_stn <- function(s, fator = 100, gatilho = 20) {
  s <- s[order(s$ano, s$mes), ]; n <- nrow(s)
  viz <- function(i, k) setdiff(max(1, i - k):min(n, i + k), i)
  mes_adj <- function(i) which(s$mes == s$mes[i] & abs(s$ano - s$ano[i]) == 1)
  med <- function(z) if (all(is.na(z))) NA_real_ else stats::median(z, na.rm = TRUE)
  disparo <- rep(FALSE, n)
  for (nm in c("valor_fpe", "valor_fpm")) for (i in seq_len(n)) {
    m <- med(s[[nm]][viz(i, 6)])
    if (!is.na(s[[nm]][i]) && !is.na(m) && s[[nm]][i] > gatilho * m) disparo[i] <- TRUE
  }
  razao <- s$valor_fpm / s$valor_fpe
  for (i in which(disparo)) {
    vz <- setdiff(viz(i, 6), which(disparo)); ma <- setdiff(mes_adj(i), which(disparo))
    ok <- TRUE
    for (nm in c("valor_fpe", "valor_fpm")) {
      v <- s[[nm]][i] / fator; mv <- med(s[[nm]][vz]); mj <- med(s[[nm]][ma])
      ok <- ok && !is.na(v) && !is.na(mv) && !is.na(mj) && v >= 0.5 * mv && v <= 2 * mv && v >= 0.5 * mj && v <= 2 * mj
    }
    rz <- razao[setdiff(viz(i, 12), which(disparo))]
    ok <- ok && !is.na(razao[i]) && any(!is.na(rz)) && razao[i] >= min(rz, na.rm = TRUE) && razao[i] <= max(rz, na.rm = TRUE)
    if (ok) {
      s$valor_fpe[i] <- s$valor_fpe[i] / fator; s$valor_fpm[i] <- s$valor_fpm[i] / fator; s$tratamento[i] <- "escala_100"
    } else {
      s$valor_fpe[i] <- NA_real_; s$valor_fpm[i] <- NA_real_; s$tratamento[i] <- "descartado_escala"
    }
  }
  s
}

#' `available_at` da STN (provisório): o mês de referência m entra no último dia útil de m+1 (+ `defasagem_extra` meses),
#' a mesma data de corte do mês m. Sem vintages históricas, é uma hipótese; a sensibilidade usa defasagem_extra = 1.
available_at_stn <- function(ano, mes, defasagem_extra = 0L, calendario = NULL) {
  mm <- mes + defasagem_extra; aa <- ano + (mm - 1) %/% 12; mm <- (mm - 1) %% 12 + 1
  as.Date(mapply(function(a, m) as.character(data_divulgacao_bcb(a, m, calendario)), aa, mm))
}

#' Fonte `stn` para montar_info(): ano, mes, valor_fpe, valor_fpm (R$ bi; NA se ausente/descartado), tratamento, available_at.
carregar_stn <- function(pasta = "data/raw/stn", defasagem_extra = 0L, ate = NULL) {
  fpe <- deduplicar_stn(ler_stn_pasta(file.path(pasta, "estados"), "estados"))
  fpm <- deduplicar_stn(ler_stn_pasta(file.path(pasta, "municipios"), "municipios"))
  s <- corrigir_escala_stn(serie_stn_mensal(fpe, fpm, ate))
  s$available_at <- available_at_stn(s$ano, s$mes, defasagem_extra)
  attr(s, "repetidas_removidas") <- c(estados = attr(fpe, "repetidas_removidas"), municipios = attr(fpm, "repetidas_removidas"))
  s
}
