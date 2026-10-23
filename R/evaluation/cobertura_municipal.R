# Curva de cobertura dos municípios (E2.0): quantos municípios, por UF, explicam 70/80/90% da receita,
# quanto do resultado primário esses mesmos municípios capturam, estabilidade do ranking entre anos
# e tamanho da imputação (municípios sem dados, em população).
# Valores em R$ correntes; ausência é ausência (NA), nunca zero.

# Contas por ano (o layout do Anexo 6 mudou em 2018). Receita: Anexo 1, "Até o Bimestre (c)".
CONTAS_COBERTURA <- list(
  `2019` = list(receita = c("ReceitasExcetoIntraOrcamentarias", "Bimestre \\(c\\)$"),
                primario = c("RREO6ResultadoPrimarioEstadosMunicipios", "VALOR INCORRIDO")),
  `2025` = list(receita = c("ReceitasExcetoIntraOrcamentarias", "Bimestre \\(c\\)$"),
                primario = c("ResultadoPrimarioSemRPPSAcimaDaLinha", "^VALOR$"))
)

valor_conta <- function(d, cod_conta, coluna_regex) {
  x <- d[d$cod_conta == cod_conta & grepl(coluna_regex, d$coluna), "valor"]
  if (length(x) == 0) NA_real_ else x[1]
}

#' Receita e resultado primário de um município no bimestre (lê o RREO e, se não houver, o Simplificado).
#' Retorna data.frame(cod_ibge, tipo, receita, primario); tipo NA = sem dados.
extrair_municipio <- function(id, ano, periodo = 6, pasta = "data/raw/rreo", contas = CONTAS_COBERTURA[[as.character(ano)]]) {
  for (tipo in TIPOS_RREO) {
    a1 <- caminho_rreo(pasta, "M", id, ano, periodo, ANEXOS_RREO[["anexo01"]], tipo)
    a6 <- caminho_rreo(pasta, "M", id, ano, periodo, ANEXOS_RREO[["anexo06"]], tipo)
    if (isTRUE(linhas_rreo(a1) > 0)) {
      rec <- valor_conta(ler_rreo(a1), contas$receita[1], contas$receita[2])
      pri <- if (isTRUE(linhas_rreo(a6) > 0)) valor_conta(ler_rreo(a6), contas$primario[1], contas$primario[2]) else NA_real_
      return(data.frame(cod_ibge = id, tipo = tipo, receita = rec, primario = pri))
    }
  }
  data.frame(cod_ibge = id, tipo = NA_character_, receita = NA_real_, primario = NA_real_)
}

#' Junta o cadastro (entes: cod_ibge, uf, populacao) aos valores extraídos.
montar_base_municipal <- function(entes_m, ano, periodo = 6, pasta = "data/raw/rreo") {
  v <- do.call(rbind, lapply(entes_m$cod_ibge, extrair_municipio, ano = ano, periodo = periodo, pasta = pasta))
  merge(entes_m[, c("cod_ibge", "uf", "populacao")], v, by = "cod_ibge")
}

#' Por UF: menor N de municípios (ordenados por receita) que explica cada limiar da receita,
#' e quanto do resultado primário (líquido e em valor absoluto) esses N capturam.
curva_cobertura <- function(base, limiares = c(0.7, 0.8, 0.9)) {
  b <- base[!is.na(base$receita), ]
  out <- lapply(split(b, b$uf), function(d) {
    d <- d[order(-d$receita), ]
    acum <- cumsum(d$receita) / sum(d$receita)
    do.call(rbind, lapply(limiares, function(l) {
      n <- which(acum >= l - 1e-12)[1]
      top <- d[seq_len(n), ]
      data.frame(uf = d$uf[1], limiar = l, n = n, n_municipios = nrow(d),
                 share_primario_liquido = sum(top$primario, na.rm = TRUE) / sum(d$primario, na.rm = TRUE),
                 share_primario_abs = sum(abs(top$primario), na.rm = TRUE) / sum(abs(d$primario), na.rm = TRUE))
    }))
  })
  do.call(rbind, out)
}

#' Mesma ideia com ranking nacional único (N maiores do país).
curva_cobertura_brasil <- function(base, limiares = c(0.7, 0.8, 0.9)) {
  d <- base[!is.na(base$receita), ]
  d <- d[order(-d$receita), ]
  acum <- cumsum(d$receita) / sum(d$receita)
  do.call(rbind, lapply(limiares, function(l) {
    n <- which(acum >= l - 1e-12)[1]
    top <- d[seq_len(n), ]
    data.frame(limiar = l, n = n, n_municipios = nrow(d),
               share_primario_liquido = sum(top$primario, na.rm = TRUE) / sum(d$primario, na.rm = TRUE),
               share_primario_abs = sum(abs(top$primario), na.rm = TRUE) / sum(abs(d$primario), na.rm = TRUE))
  }))
}

#' Estabilidade do ranking: dos N maiores (por receita, dentro da UF) do ano A, que fração também está
#' entre os N maiores do ano B (mesmo N por UF). Só municípios com dados nos dois anos.
sobreposicao_topn <- function(base_a, base_b, n_por_uf) {
  ids <- intersect(base_a$cod_ibge[!is.na(base_a$receita)], base_b$cod_ibge[!is.na(base_b$receita)])
  a <- base_a[base_a$cod_ibge %in% ids, ]; b <- base_b[base_b$cod_ibge %in% ids, ]
  do.call(rbind, lapply(names(n_por_uf), function(uf) {
    n <- n_por_uf[[uf]]
    ta <- head(a[a$uf == uf, ][order(-a[a$uf == uf, "receita"]), "cod_ibge"], n)
    tb <- head(b[b$uf == uf, ][order(-b[b$uf == uf, "receita"]), "cod_ibge"], n)
    data.frame(uf = uf, n = length(ta), em_comum = length(intersect(ta, tb)))
  }))
}

#' Municípios sem dados e sua participação na população (tamanho da imputação).
sem_dados <- function(base) {
  s <- base[is.na(base$receita), ]
  total <- sum(base$populacao, na.rm = TRUE)
  list(n = nrow(s), n_total = nrow(base), pop_share = sum(s$populacao, na.rm = TRUE) / total,
       por_uf = do.call(rbind, lapply(split(base, base$uf), function(d)
         data.frame(uf = d$uf[1], n_sem_dados = sum(is.na(d$receita)), n = nrow(d),
                    pop_share = sum(d$populacao[is.na(d$receita)], na.rm = TRUE) / sum(d$populacao, na.rm = TRUE)))),
       municipios = s[order(-s$populacao), c("cod_ibge", "uf", "populacao")])
}

#' Peso do grupo "RREO Simplificado" (ausência estrutural nos bimestres 1, 2, 4 e 5) por UF e no Brasil:
#' número de municípios e participação na receita, no resultado primário (líquido e em valor absoluto)
#' e na população. Municípios sem dados ficam fora dos dois grupos (têm imputação própria).
participacao_simplificado <- function(base) {
  calc <- function(d) {
    s <- !is.na(d$tipo) & d$tipo == "RREO Simplificado"
    com <- !is.na(d$tipo)
    data.frame(n_municipios = nrow(d), n_simplificado = sum(s),
               pop_share = sum(d$populacao[s], na.rm = TRUE) / sum(d$populacao, na.rm = TRUE),
               receita_share = sum(d$receita[s], na.rm = TRUE) / sum(d$receita[com], na.rm = TRUE),
               primario_liquido_share = sum(d$primario[s], na.rm = TRUE) / sum(d$primario[com], na.rm = TRUE),
               primario_abs_share = sum(abs(d$primario[s]), na.rm = TRUE) / sum(abs(d$primario[com]), na.rm = TRUE))
  }
  por_uf <- do.call(rbind, lapply(split(base, base$uf), function(d) cbind(uf = d$uf[1], calc(d))))
  rbind(por_uf, cbind(uf = "BR", calc(base)))
}
