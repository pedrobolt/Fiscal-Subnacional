# Receita mensal bruta e líquida por UF x imposto: perfil mensal do RREO Anexo 3 calibrado ao nível anual da DCA.
# Fator (UF x ano x imposto) = receita bruta realizada da DCA / total de 12 meses do Anexo 3 no 6º bimestre; marca de origem
# "a3_direto" (fator dentro da tolerância de 1) ou "a3_calibrado_dca". Deduções (FUNDEB, cota-parte, outras) entram pela proporção
# do bruto na DCA do mesmo ano do fator. Regime de cota-parte observado na DCA: "liquido_cota_parte" se há dedução de
# transferências constitucionais, "bruto_cota_parte" se não há (ICMS e IPVA).
# Tempo real: o fator do ano t só vale a partir de `disponivel_em` (DCA: 31/05 do ano t+1, premissa); antes disso usa-se o último
# fator disponível.

#' Tipo da coluna da DCA I-C, por padrão ASCII (independe do locale do R): bruto, fundeb, transf, outras.
tipo_coluna_dca <- function(coluna) {
  ifelse(grepl("^Receitas Brutas", coluna), "bruto", ifelse(grepl("FUNDEB", coluna), "fundeb",
  ifelse(grepl("Transfer.ncias Constitucionais", coluna), "transf", ifelse(grepl("^Outras Dedu", coluna), "outras", NA_character_))))
}

#' Tabela de fatores por UF x ano x imposto. `dca`: ler_dca_impostos(); `a3`: ler_a3_estados().
fatores_dca <- function(dca, a3, disponivel_mes_dia = "05-31") {
  dca$tipo <- tipo_coluna_dca(dca$coluna)
  dca <- dca[!is.na(dca$tipo) & !duplicated(dca[, c("cod_ibge", "exercicio", "categoria", "tipo")]), ]
  w <- stats::reshape(dca[, c("cod_ibge", "uf", "exercicio", "categoria", "tipo", "valor")],
                      idvar = c("cod_ibge", "uf", "exercicio", "categoria"), timevar = "tipo", direction = "wide")
  names(w) <- sub("^valor\\.", "", names(w))
  for (n in c("bruto", "fundeb", "transf", "outras")) { if (!n %in% names(w)) w[[n]] <- 0; w[[n]][is.na(w[[n]])] <- 0 }
  t12 <- a3[a3$tipo == "total12m" & a3$periodo == 6 & a3$categoria %in% unique(w$categoria), c("cod_ibge", "exercicio", "categoria", "valor")]
  t12 <- t12[!duplicated(t12[, c("cod_ibge", "exercicio", "categoria")]), ]
  names(t12)[4] <- "a3_12m"
  f <- merge(w, t12, by = c("cod_ibge", "exercicio", "categoria"))
  f$fator <- ifelse(f$a3_12m > 0 & f$bruto > 0, f$bruto / f$a3_12m, NA_real_)
  f$origem <- ifelse(is.na(f$fator), "a3_sem_dca", ifelse(abs(f$fator - 1) <= 0.005, "a3_direto", "a3_calibrado_dca"))
  f$regime <- ifelse(f$categoria %in% c("ICMS", "IPVA"), ifelse(f$transf != 0, "liquido_cota_parte", "bruto_cota_parte"), NA_character_)
  # DF (cod_ibge 53): não tem municípios, logo não há cota-parte. Até 2021 o Anexo 3 do DF já vem líquido do FUNDEB (igual ao
  # Anexo 6); a partir de 2022 vem bruto. A quebra de 2022 é esperada e o fator (bruto/A3) a absorve; regime próprio.
  f$regime[f$cod_ibge == 53 & f$categoria %in% c("ICMS", "IPVA")] <- "sem_cota_parte"
  f$sh_fundeb <- f$fundeb / f$bruto; f$sh_transf <- f$transf / f$bruto; f$sh_outras <- f$outras / f$bruto
  f$disponivel_em <- as.Date(sprintf("%d-%s", f$exercicio + 1L, disponivel_mes_dia))
  f <- f[order(f$cod_ibge, f$categoria, f$exercicio), ]
  f$quebra <- marcar_quebras(f, LIMITE_QUEBRA_FATOR)
  f
}

# Limite definido em 28/10/2026 (antes de ver os fatores completos): variação anual do fator acima de 2% ou troca de regime
# de cota-parte = quebra. Alerta, não bloqueia a projeção.
LIMITE_QUEBRA_FATOR <- 0.02

#' Marca, por linha de `f` (ordenada por UF x imposto x exercício), se o fator quebrou em relação ao ano anterior.
marcar_quebras <- function(f, lim = LIMITE_QUEBRA_FATOR) {
  ch <- paste(f$cod_ibge, f$categoria)
  ant <- c(NA, seq_len(nrow(f) - 1L)); ant[c(TRUE, ch[-1] != ch[-nrow(f)])] <- NA
  dv <- abs(f$fator / f$fator[ant] - 1)
  rg <- f$regime != f$regime[ant]
  (!is.na(dv) & dv > lim) | (!is.na(rg) & rg)
}

#' Data em que o bimestre que traz o mês fica disponível no Siconfi (premissa: fim do bimestre + 30 dias).
data_publicacao_mes <- function(mes) {
  m <- as.integer(format(mes, "%m")); fim <- 2L * ((m + 1L) %/% 2L)
  ano <- as.integer(format(mes, "%Y"))
  ini_seg <- as.Date(sprintf("%04d-%02d-01", ano + (fim == 12L), ifelse(fim == 12L, 1L, fim + 1L)))
  ini_seg + 30L
}

#' Fator disponível na data de referência: o do último exercício <= `ano` cujo `disponivel_em` <= data_ref.
#' Retorna linha da tabela de fatores (NA se não houver).
fator_disponivel <- function(fatores_uf_cat, ano, data_ref) {
  ok <- fatores_uf_cat[fatores_uf_cat$exercicio <= ano & fatores_uf_cat$disponivel_em <= data_ref & !is.na(fatores_uf_cat$fator), ]
  if (!NROW(ok)) return(NULL)
  ok[which.max(ok$exercicio), ]
}

#' Receita mensal bruta e líquida. `mensal`: receita_mensal_a3(); `fatores`: fatores_dca().
#' Devolve uma linha por UF x imposto x mês, com fator ex-post (mesmo ano) e fator em tempo real.
receita_bruta_liquida <- function(mensal, fatores) {
  m <- mensal[mensal$categoria %in% unique(fatores$categoria), ]
  m$ano <- as.integer(format(m$mes, "%Y")); m$ref <- data_publicacao_mes(m$mes)
  chave_f <- split(fatores, paste(fatores$cod_ibge, fatores$categoria))
  linhas <- lapply(seq_len(nrow(m)), function(i) {
    fu <- chave_f[[paste(m$cod_ibge[i], m$categoria[i])]]
    ex <- if (is.null(fu)) NULL else fu[fu$exercicio == m$ano[i] & !is.na(fu$fator), ]
    tr <- if (is.null(fu)) NULL else fator_disponivel(fu, m$ano[i], m$ref[i])
    data.frame(
      fator_ex_post = if (NROW(ex)) ex$fator else NA_real_, origem_ex_post = if (NROW(ex)) ex$origem else "a3_sem_dca",
      fator_tr = if (NROW(tr)) tr$fator else NA_real_, ano_fator_tr = if (NROW(tr)) tr$exercicio else NA_integer_,
      origem_tr = if (NROW(tr)) tr$origem else "a3_sem_dca",
      regime_tr = if (NROW(tr)) tr$regime else NA_character_,
      quebra_tr = if (NROW(tr)) tr$quebra else NA,
      ded_sh_tr = if (NROW(tr)) tr$sh_fundeb + tr$sh_transf + tr$sh_outras else NA_real_,
      ded_sh_ex = if (NROW(ex)) ex$sh_fundeb + ex$sh_transf + ex$sh_outras else NA_real_,
      stringsAsFactors = FALSE)
  })
  m <- cbind(m, do.call(rbind, linhas))
  # Alertas (não bloqueiam): fator usado veio de um ano com quebra; fator defasado (mais de 1 ano); sem fator
  m$flag_quebra_fator <- !is.na(m$quebra_tr) & m$quebra_tr
  m$flag_fator_defasado <- !is.na(m$ano_fator_tr) & m$ano_fator_tr < m$ano - 1L
  m$flag_sem_fator <- is.na(m$fator_tr)
  m$bruto_ex_post <- m$valor * m$fator_ex_post; m$liquido_ex_post <- m$bruto_ex_post * (1 - m$ded_sh_ex)
  m$bruto_tr <- m$valor * m$fator_tr; m$liquido_tr <- m$bruto_tr * (1 - m$ded_sh_tr)
  m
}

#' Estabilidade do fator por UF x imposto: quebra = troca de regime de cota-parte ou variação anual do fator acima de `lim`.
estabilidade_fatores <- function(fatores, lim = 0.02) {
  out <- lapply(split(fatores, paste(fatores$cod_ibge, fatores$categoria)), function(z) {
    z <- z[order(z$exercicio) & !is.na(z$fator), ]
    if (!NROW(z)) return(NULL)
    dv <- c(NA, abs(z$fator[-1] / z$fator[-NROW(z)] - 1))
    rg <- c(NA, z$regime[-1] != z$regime[-NROW(z)])
    q <- (!is.na(dv) & dv > lim) | (!is.na(rg) & rg)
    ult <- max(z$exercicio)
    data.frame(cod_ibge = z$cod_ibge[1], uf = z$uf[1], categoria = z$categoria[1], n_anos = NROW(z), ultimo_ano = ult,
               fator_min = min(z$fator), fator_max = max(z$fator), dp_fator = stats::sd(z$fator),
               n_quebras = sum(q), anos_quebra = paste(z$exercicio[q], collapse = ","),
               corrente_menos_confiavel = any(q & z$exercicio >= ult - 1L), stringsAsFactors = FALSE)
  })
  do.call(rbind, out)
}
