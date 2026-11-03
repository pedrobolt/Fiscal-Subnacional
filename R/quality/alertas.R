# Alertas automáticos da rodada mensal (E2.8). Não bloqueiam a projeção; vão para outputs/alertas_rodada.csv e para a aba de alertas do
# Excel do E6. Regras e limites declarados em docs/contrato.md (29/10/2026), antes de executar.
# Formato único: tipo (a/b/c/d), subtipo, cod_ibge, serie, exercicio, periodo, valor, limite, detalhe.

ALERTA_K_MAD <- 4            # (b) múltiplos do MAD
ALERTA_PISO_RECEITA <- 0.01  # (b) piso: 1% da receita total da UF no bimestre
ALERTA_PISO_SERIE <- c("rec:demais receitas" = 0.10)  # (b) piso maior para séries muito voláteis (ajuste de uso, 30/10/2026)
ALERTA_MIN_HIST <- 3L        # (b) mínimo de variações históricas para calcular o MAD
ALERTA_PRAZO_DIAS <- 30L     # (d) prazo legal após o fim do bimestre
ALERTA_RGF_PP <- 0.20        # (b) RREO acima do RGF em mais de 20 p.p. = suspeita de reclassificação

COLUNAS_ALERTA <- c("tipo", "subtipo", "cod_ibge", "serie", "exercicio", "periodo", "valor", "limite", "detalhe")

alertas_vazio <- function() {
  data.frame(tipo = character(0), subtipo = character(0), cod_ibge = integer(0), serie = character(0), exercicio = integer(0),
             periodo = integer(0), valor = numeric(0), limite = numeric(0), detalhe = character(0), stringsAsFactors = FALSE)
}

mk_alerta <- function(tipo, subtipo, cod_ibge = NA_integer_, serie = NA_character_, exercicio = NA_integer_, periodo = NA_integer_,
                      valor = NA_real_, limite = NA_real_, detalhe = NA_character_) {
  comp <- c(length(subtipo), length(cod_ibge), length(serie), length(exercicio), length(periodo), length(valor), length(detalhe))
  if (any(comp == 0L)) return(alertas_vazio())      # algum vetor de chaves vazio: nenhum alerta
  n <- max(comp)
  r <- function(v, tipo_) rep_len(as(v, tipo_), n)
  data.frame(tipo = rep_len(tipo, n), subtipo = rep_len(subtipo, n), cod_ibge = r(cod_ibge, "integer"), serie = r(serie, "character"),
             exercicio = r(exercicio, "integer"), periodo = r(periodo, "integer"), valor = r(valor, "numeric"), limite = r(limite, "numeric"),
             detalhe = r(detalhe, "character"), stringsAsFactors = FALSE)
}

# ---- (a) conta ou coluna sem correspondência no dicionário ---------------------------------------------------------------

#' Anexos 1 e 6 do RREO: usa `cobertura_dicionario()`. Cada combinação sem entrada vira um alerta.
alerta_dicionario_rreo <- function(rreo, dic_contas, dic_colunas) {
  cob <- cobertura_dicionario(rreo, dic_contas, dic_colunas)
  rbind(mk_alerta("a", "conta_sem_dicionario", serie = paste(cob$contas$anexo, cob$contas$cod_conta, sep = "/"), detalhe = paste("layout", cob$contas$layout)),
        mk_alerta("a", "coluna_sem_dicionario", serie = paste(cob$colunas$anexo, cob$colunas$padrao, sep = "/"), detalhe = paste("layout", cob$colunas$layout)))
}

#' Contas observadas (Anexo 3 do RREO ou Anexo 1 do RGF) que não estão no conjunto conhecido (`conhecidas`: vetor de cod_conta,
#' gerado do histórico em `data/`). Além disso, categoria acompanhada ausente em um arquivo onde era esperada.
alerta_contas_conhecidas <- function(observadas, conhecidas, anexo) {
  novas <- setdiff(unique(observadas), conhecidas)
  mk_alerta("a", "conta_nova", serie = if (length(novas)) paste(anexo, novas, sep = "/") else character(0), detalhe = "conta fora do histórico conhecido")
}

# ---- (b) salto de categoria contra o mesmo bimestre do ano anterior --------------------------------------------------------

#' `fluxos`: cod_ibge, serie (categoria), exercicio, periodo, valor (fluxo do bimestre); `receita_total`: cod_ibge, exercicio, periodo, rec_total.
#' Alerta se |Δ − mediana(Δ_hist)| > k × MAD(Δ_hist) e > piso × receita total da UF no bimestre; Δ = valor − valor do mesmo bimestre
#' do ano anterior; histórico = Δ da própria UF x série x bimestre em anos anteriores (mínimo `min_hist`).
alerta_salto <- function(fluxos, receita_total, k = ALERTA_K_MAD, piso = ALERTA_PISO_RECEITA, min_hist = ALERTA_MIN_HIST,
                         piso_serie = ALERTA_PISO_SERIE) {
  f <- merge(fluxos, receita_total, by = c("cod_ibge", "exercicio", "periodo"), all.x = TRUE)
  f <- f[order(f$cod_ibge, f$serie, f$periodo, f$exercicio), ]
  ch <- paste(f$cod_ibge, f$serie, f$periodo)
  f$delta <- NA_real_; f$mediana_h <- NA_real_; f$mad_h <- NA_real_; f$n_hist <- 0L
  for (idx in split(seq_len(nrow(f)), ch)) {
    z <- f[idx, ]; n <- nrow(z)
    d <- ifelse(c(FALSE, diff(z$exercicio) == 1L), c(NA, diff(z$valor)), NA_real_)
    f$delta[idx] <- d
    for (i in seq_len(n)) {
      h <- d[seq_len(i - 1L)]; h <- h[!is.na(h)]
      f$n_hist[idx[i]] <- length(h)
      if (length(h) >= min_hist) { f$mediana_h[idx[i]] <- stats::median(h); f$mad_h[idx[i]] <- stats::median(abs(h - stats::median(h))) }
    }
  }
  desvio <- abs(f$delta - f$mediana_h)
  piso_i <- ifelse(f$serie %in% names(piso_serie), piso_serie[f$serie], piso)     # piso próprio por série (ex.: demais receitas)
  alerta <- !is.na(desvio) & !is.na(f$rec_total) & desvio > k * f$mad_h & desvio > piso_i * f$rec_total
  f$historico_curto <- is.na(f$delta) | f$n_hist < min_hist
  out <- f[alerta, ]
  if (!nrow(out)) return(alertas_vazio())
  mk_alerta("b", "salto_vs_ano_anterior", out$cod_ibge, out$serie, out$exercicio, out$periodo, out$delta,
            pmax(k * out$mad_h, piso_i[alerta] * out$rec_total), sprintf("desvio %.0f; mediana hist. %.0f; MAD %.0f; n hist %d", desvio[alerta], out$mediana_h, out$mad_h, out$n_hist))
}

#' Marca, nos alertas (b) de pessoal, se a variação anual do RREO supera a do RGF em mais de `pp`. `yoy`: cod_ibge, exercicio, periodo,
#' rreo_yoy, rgf_yoy (variações relativas).
marcar_reclassificacao <- function(yoy, pp = ALERTA_RGF_PP) {
  yoy$suspeita_reclassificacao <- !is.na(yoy$rreo_yoy) & !is.na(yoy$rgf_yoy) & (yoy$rreo_yoy - yoy$rgf_yoy) > pp
  yoy
}

# ---- (c) flags do conceito único e da calibração ----------------------------------------------------------------------------

#' `x`: bimestral do conceito único (cod_ibge, exercicio, periodo, conceito_original, flag_custeio_nao_positivo, flag_quebra_troca);
#' `rb`: receita mensal bruta/líquida (cod_ibge, categoria, mes, flag_quebra_fator, flag_fator_defasado, flag_sem_fator).
alerta_flags <- function(x = NULL, rb = NULL) {
  out <- alertas_vazio()
  um <- function(d, col, subtipo) {
    s <- d[!is.na(d[[col]]) & d[[col]], ]
    if (!nrow(s)) return(alertas_vazio())
    mk_alerta("c", subtipo, s$cod_ibge, if ("categoria" %in% names(s)) s$categoria else "A6", s$exercicio, s$periodo, detalhe = col)
  }
  if (!is.null(x)) out <- rbind(out, um(x, "conceito_original", "conceito_original"), um(x, "flag_custeio_nao_positivo", "custeio_nao_positivo"),
                                um(x, "flag_quebra_troca", "quebra_na_troca_de_conceito"))
  if (!is.null(rb)) {
    rb$exercicio <- as.integer(format(rb$mes, "%Y")); rb$periodo <- (as.integer(format(rb$mes, "%m")) + 1L) %/% 2L
    rb <- unique(rb[, c("cod_ibge", "categoria", "exercicio", "periodo", "flag_quebra_fator", "flag_fator_defasado", "flag_sem_fator")])
    out <- rbind(out, um(rb, "flag_quebra_fator", "fator_instavel"), um(rb, "flag_sem_fator", "sem_fator"))
  }
  out
}

#' `fator_defasado` deixou de ser alerta (29/10/2026, ajuste de uso): é estado estrutural até a DCA sair. Vira coluna de status por
#' UF x categoria x bimestre. `rb`: receita mensal bruta/líquida (cod_ibge, categoria, mes, flag_fator_defasado).
status_fatores <- function(rb) {
  rb$exercicio <- as.integer(format(rb$mes, "%Y")); rb$periodo <- (as.integer(format(rb$mes, "%m")) + 1L) %/% 2L
  s <- unique(rb[, c("cod_ibge", "categoria", "exercicio", "periodo", "flag_fator_defasado")])
  names(s)[5] <- "fator_defasado"; s
}

# ---- (d) entrega atrasada, ausente ou retificada ----------------------------------------------------------------------------

#' `extrato`: saída de `ler_extrato()` (cod_ibge, exercicio, periodo, tipo, status, data_status) para os entes e anos da rodada;
#' `esperados`: cod_ibge, exercicio, periodo dos bimestres que deveriam ter sido entregues. Prazo = fim do bimestre + `prazo` dias.
alerta_entrega <- function(extrato, esperados, hoje = Sys.Date(), prazo = ALERTA_PRAZO_DIAS) {
  fim <- function(ex, p) { m <- 2L * p; as.Date(sprintf("%04d-%02d-01", ex + (m == 12L), ifelse(m == 12L, 1L, m + 1L))) - 1L }
  e <- esperados; e$prazo_em <- fim(e$exercicio, e$periodo) + prazo
  e <- e[e$prazo_em < hoje, ]
  m <- merge(e, extrato[, c("cod_ibge", "exercicio", "periodo", "status", "data_status")], by = c("cod_ibge", "exercicio", "periodo"), all.x = TRUE)
  ausente <- m[is.na(m$data_status), ]
  tem <- m[!is.na(m$data_status), ]
  retif <- tem[tem$status %in% "RE", ]
  atraso <- tem[!(tem$status %in% "RE") & as.Date(tem$data_status) > tem$prazo_em, ]
  rbind(mk_alerta("d", "entrega_ausente", ausente$cod_ibge, "RREO", ausente$exercicio, ausente$periodo, limite = as.numeric(ausente$prazo_em), detalhe = "sem entrega no extrato após o prazo"),
        mk_alerta("d", "entrega_atrasada", atraso$cod_ibge, "RREO", atraso$exercicio, atraso$periodo, as.numeric(as.Date(atraso$data_status) - atraso$prazo_em), 0, "dias após o prazo"),
        mk_alerta("d", "retificacao", retif$cod_ibge, "RREO", retif$exercicio, retif$periodo, detalhe = paste("retificado em", format(retif$data_status, "%Y-%m-%d"))))
}

# ---- Fluxos bimestrais do Anexo 6 por categoria do P2 (insumo do alerta (b)) ----------------------------------------------

#' Soma das folhas do Anexo 6 por categoria_p2 (receita realizada e despesa em caixa, 2018+; despesa 2015-17 não tem caixa e fica de fora),
#' convertida de acumulado para fluxo do bimestre. Categorias do conceito original do Anexo 6 (sem o ajuste do conceito único).
fluxos_a6_categorias <- function(rreo, dic_contas, dic_colunas) {
  d <- aplicar_dicionario(rreo[rreo$anexo == "RREO-Anexo 06", ], dic_contas, dic_colunas)
  d <- d[!is.na(d$papel_conta), ]
  d$chave <- paste(d$cod_ibge, d$exercicio, d$periodo)
  corrente <- d$ano_rel %in% c("corrente", "nao_se_aplica")
  rec <- d[d$papel_coluna %in% "receita_p2" & corrente & d$papel_conta == "rec_folha", ]
  rec <- rec[!duplicated(rec[, c("chave", "cod_conta", "coluna")]), ]; rec$serie <- paste0("rec:", rec$categoria_p2)
  dsp <- d[d$papel_coluna %in% "despesa_caixa_p2" & d$papel_conta == "desp_folha", ]
  dsp <- dsp[!duplicated(dsp[, c("chave", "cod_conta", "estagio", "coluna")]), ]; dsp$serie <- paste0("desp:", dsp$categoria_p2)
  x <- rbind(rec[, c("cod_ibge", "exercicio", "periodo", "serie", "valor")], dsp[, c("cod_ibge", "exercicio", "periodo", "serie", "valor")])
  x <- aggregate(valor ~ cod_ibge + exercicio + periodo + serie, x, sum)
  x <- acumulado_para_fluxo(x, serie = c("cod_ibge", "serie"), valor = "valor")
  x$valor <- ifelse(x$acum_anterior_ausente, NA_real_, x$fluxo)
  x[!is.na(x$valor), c("cod_ibge", "serie", "exercicio", "periodo", "valor")]
}

# ---- RPPS: totais com e sem RPPS (quebra de 2023) ---------------------------------------------------------------------------

#' Receita e despesa primárias totais do 6º bimestre com e sem RPPS, por UF x ano. Até 2022 o RPPS está dentro das contas e não se
#' separa (com = sem, mas inclui RPPS); de 2023 em diante o Anexo 6 publica os dois totais.
totais_rpps <- function(rreo, dic_contas, dic_colunas) {
  d <- aplicar_dicionario(rreo[rreo$anexo == "RREO-Anexo 06" & rreo$periodo == 6, ], dic_contas, dic_colunas)
  d <- d[!is.na(d$papel_conta) & d$ano_rel %in% c("corrente", "nao_se_aplica"), ]
  rec <- d[d$papel_coluna %in% "receita_p2" & d$papel_conta == "rec_total", ]
  dsp <- d[d$papel_coluna %in% "despesa_caixa_p2" & d$papel_conta == "desp_total", ]
  agr <- function(x, nome) {
    x <- x[!duplicated(x[, c("cod_ibge", "exercicio", "cod_conta", "estagio", "coluna")]), ]
    s <- aggregate(valor ~ cod_ibge + exercicio + rpps, x, sum); names(s)[4] <- nome; s
  }
  r <- agr(rec, "rec"); dp <- agr(dsp, "desp")
  m <- merge(r, dp, by = c("cod_ibge", "exercicio", "rpps"), all = TRUE)
  com <- m[m$rpps %in% c("inclui_rpps", "incluido_nao_separavel"), ]; sem <- m[m$rpps %in% c("referencia_ldo"), ]
  out <- merge(com, sem, by = c("cod_ibge", "exercicio"), all.x = TRUE, suffixes = c("_com", "_sem"))
  out[, !names(out) %in% c("rpps_com", "rpps_sem")]
}

# ---- RGF: despesa de pessoal mensal (Executivo) e comparação com o RREO ---------------------------------------------------

#' Lê o RGF Anexo 01 dos estados (data/raw/rgf/E) e devolve a despesa bruta com pessoal mensal do Poder Executivo:
#' cod_ibge, mes (1o dia), valor. O mês vem da coluna "<MR-k>" (MR = último mês do quadrimestre = 4 x q); o mesmo mês aparece em até 3
#' arquivos (revisões): vale o do arquivo mais recente.
pessoal_rgf_mensal <- function(pasta = "data/raw/rgf") {
  arqs <- list.files(file.path(pasta, "E"), "^[0-9]+_q[1-3]_a01\\.json\\.gz$", recursive = TRUE, full.names = TRUE)
  out <- lapply(arqs, function(a) {
    x <- ler_json_utf8(a)$items
    if (NROW(x) == 0) return(NULL)
    x <- x[x$cod_conta == "DespesaComPessoalBruta" & grepl("^<MR", x$coluna), ]
    if (!nrow(x)) return(NULL)
    k <- ifelse(x$coluna == "<MR>", 0L, as.integer(sub("^<MR-([0-9]+)>$", "\\1", x$coluna)))
    m <- 4L * x$periodo - k
    ano <- x$exercicio + (m - 1L) %/% 12L; mes <- (m - 1L) %% 12L + 1L
    data.frame(cod_ibge = x$cod_ibge, mes = as.Date(sprintf("%04d-%02d-01", ano, mes)), pub = x$exercicio * 10L + x$periodo, valor = x$valor)
  })
  d <- do.call(rbind, out)
  d <- d[order(d$cod_ibge, d$mes, d$pub), ]
  d[!duplicated(paste(d$cod_ibge, d$mes), fromLast = TRUE), c("cod_ibge", "mes", "valor")]
}

#' Variação anual do pessoal por UF x bimestre no RREO (categoria "desp:pessoal", fluxo do bimestre) e no RGF (soma dos 2 meses do
#' bimestre). Devolve cod_ibge, exercicio, periodo, rreo_yoy, rgf_yoy, dif (pontos) e a marca de suspeita de reclassificação.
yoy_pessoal_rreo_rgf <- function(fluxos_cat, rgf_mensal, pp = ALERTA_RGF_PP) {
  r <- fluxos_cat[fluxos_cat$serie == "desp:pessoal", c("cod_ibge", "exercicio", "periodo", "valor")]
  g <- rgf_mensal; g$exercicio <- as.integer(format(g$mes, "%Y")); g$periodo <- (as.integer(format(g$mes, "%m")) + 1L) %/% 2L
  n_m <- tapply(g$valor, paste(g$cod_ibge, g$exercicio, g$periodo), length)
  g <- aggregate(valor ~ cod_ibge + exercicio + periodo, g, sum)
  g <- g[n_m[paste(g$cod_ibge, g$exercicio, g$periodo)] == 2L, ]              # só bimestres com os 2 meses
  yoy <- function(d) {
    d <- d[order(d$cod_ibge, d$periodo, d$exercicio), ]
    ch <- paste(d$cod_ibge, d$periodo); ant <- c(NA, seq_len(nrow(d) - 1L)); ant[c(TRUE, ch[-1] != ch[-nrow(d)])] <- NA
    ok <- !is.na(ant) & d$exercicio - d$exercicio[ant] == 1L
    d$y <- ifelse(ok, d$valor / d$valor[ant] - 1, NA_real_); d
  }
  r <- yoy(r); g <- yoy(g)
  m <- merge(r[, c("cod_ibge", "exercicio", "periodo", "y")], g[, c("cod_ibge", "exercicio", "periodo", "y")], by = c("cod_ibge", "exercicio", "periodo"), suffixes = c("_rreo", "_rgf"))
  names(m)[4:5] <- c("rreo_yoy", "rgf_yoy"); m$dif <- m$rreo_yoy - m$rgf_yoy
  marcar_reclassificacao(m, pp)
}

#' Alerta de suspeita de reclassificação de pessoal: salto de pessoal pelo alerta (b) E variação anual do RREO acima da do RGF em mais
#' de `pp` (a coluna `suspeita_reclassificacao` sozinha é informativa e dispararia em ~10% dos UF-bimestres). `ab`: saída de alerta_salto().
alerta_reclassificacao_pessoal <- function(ab, yoy) {
  b <- ab[ab$serie == "desp:pessoal", c("cod_ibge", "exercicio", "periodo")]
  m <- merge(b, yoy[yoy$suspeita_reclassificacao, ], by = c("cod_ibge", "exercicio", "periodo"))
  if (!nrow(m)) return(alertas_vazio())
  mk_alerta("b", "pessoal_suspeita_reclassificacao", m$cod_ibge, "desp:pessoal", m$exercicio, m$periodo, m$dif, ALERTA_RGF_PP,
            sprintf("RREO %+.0f%% vs RGF %+.0f%% (variação anual)", 100 * m$rreo_yoy, 100 * m$rgf_yoy))
}

#' Pessoal harmonizado (sensibilidade) para UFs que reclassificaram despesa no RREO sem mudança no RGF. Do primeiro bimestre afetado
#' (`inicio`: cod_ibge, exercicio, periodo) em diante, o pessoal esperado é o do mesmo bimestre do ano anterior (já harmonizado) vezes a
#' variação anual do RGF; o excedente (RREO − esperado) é o efeito da reclassificação. Não mexe no total da despesa nem no primário:
#' o excedente fica numa linha própria. `pessoal`: cod_ibge, exercicio, periodo, valor (fluxo do bimestre); `yoy`: yoy_pessoal_rreo_rgf().
pessoal_harmonizado <- function(pessoal, yoy, inicio) {
  p <- merge(pessoal, yoy[, c("cod_ibge", "exercicio", "periodo", "rgf_yoy")], by = c("cod_ibge", "exercicio", "periodo"), all.x = TRUE)
  p <- p[order(p$cod_ibge, p$exercicio, p$periodo), ]
  p$bruto <- p$valor; p$harmonizado <- p$valor; p$excedente <- 0
  for (u in unique(inicio$cod_ibge)) {
    ini <- inicio[inicio$cod_ibge == u, ]; t0 <- min(ini$exercicio * 10L + ini$periodo)
    for (i in which(p$cod_ibge == u & p$exercicio * 10L + p$periodo >= t0)) {
      ant <- which(p$cod_ibge == u & p$exercicio == p$exercicio[i] - 1L & p$periodo == p$periodo[i])
      if (length(ant) != 1 || is.na(p$rgf_yoy[i])) next
      esperado <- p$harmonizado[ant] * (1 + p$rgf_yoy[i])
      p$harmonizado[i] <- esperado; p$excedente[i] <- p$bruto[i] - esperado
    }
  }
  p[, c("cod_ibge", "exercicio", "periodo", "bruto", "harmonizado", "excedente")]
}

# ---- Priorização: quebras inventariadas (E2.8) viram "conhecida"; os demais ordenados por materialidade ------------------------

#' Início das reclassificações de pessoal inventariadas (docs/nota_quebras.md): cod_ibge, exercicio, periodo.
INICIO_RECLASSIFICACAO <- data.frame(cod_ibge = c(33L, 41L, 43L), exercicio = 2025L, periodo = c(1L, 6L, 5L))
#' Último bimestre coberto pelo inventário da E2.8 (exercicio, periodo); alertas posteriores nunca são "conhecidos".
INVENTARIO_ATE <- c(2026L, 4L)

#' Marca cada alerta com `status` ("conhecida" ou "nova") e `quebra` (rótulo do inventário). Regras:
#' RPPS 2023 (b em pessoal e demais receitas); reclassificação RJ/PR/RS (b em pessoal, Δ > 0, a partir do início de cada UF: reversão
#' não é conhecida); RS 2018 b1-b5 (qualquer tipo); flags inventariados do conceito único; quebras anuais do fator até 2025.
marcar_conhecidas <- function(al, inicio = INICIO_RECLASSIFICACAO, ate = INVENTARIO_ATE) {
  if (!nrow(al)) { al$status <- character(0); al$quebra <- character(0); return(al) }
  quebra <- rep(NA_character_, nrow(al))
  dentro <- !is.na(al$exercicio) & (al$exercicio < ate[1] | (al$exercicio == ate[1] & (is.na(al$periodo) | al$periodo <= ate[2])))
  b <- al$tipo == "b"
  quebra[dentro & b & al$exercicio %in% 2023L & al$serie %in% c("desp:pessoal", "rec:demais receitas")] <- "RPPS 2023"
  ini <- inicio[match(al$cod_ibge, inicio$cod_ibge), ]
  apos <- !is.na(ini$exercicio) & (al$exercicio > ini$exercicio | (al$exercicio == ini$exercicio & al$periodo >= ini$periodo))
  quebra[dentro & b & al$serie %in% "desp:pessoal" & apos & !is.na(al$valor) & al$valor > 0] <- "reclassificacao de pessoal RJ/PR/RS"
  quebra[dentro & al$cod_ibge %in% 43L & al$exercicio %in% 2018L & al$periodo %in% 1:5 & al$tipo != "b"] <- "RS 2018 A6 vazio"
  quebra[dentro & al$tipo == "c" & al$subtipo %in% c("conceito_original", "custeio_nao_positivo", "quebra_na_troca_de_conceito")] <- "flag do conceito unico"
  quebra[dentro & al$tipo == "c" & al$subtipo == "fator_instavel" & al$exercicio <= 2025L] <- "quebra anual do fator"
  al$quebra <- quebra
  al$status <- ifelse(is.na(quebra), "nova", "conhecida")
  al
}

#' Materialidade = |Δ| / receita total da UF no bimestre (só para o alerta (b)); `receita_total`: cod_ibge, exercicio, periodo, rec_total.
#' Ordena: novas primeiro, por materialidade decrescente (alertas sem valor em R$ depois), e devolve também o resumo (total ao lado).
priorizar_alertas <- function(al, receita_total) {
  al <- marcar_conhecidas(al)
  k <- match(paste(al$cod_ibge, al$exercicio, al$periodo), paste(receita_total$cod_ibge, receita_total$exercicio, receita_total$periodo))
  al$materialidade <- ifelse(al$tipo == "b", abs(al$valor) / receita_total$rec_total[k], NA_real_)
  al <- al[order(al$status != "nova", -ifelse(is.na(al$materialidade), -1, al$materialidade), al$tipo, al$cod_ibge, al$exercicio, al$periodo), ]
  rownames(al) <- NULL
  resumo <- as.data.frame(table(tipo = al$tipo, subtipo = al$subtipo, status = al$status), stringsAsFactors = FALSE)
  resumo <- resumo[resumo$Freq > 0, ]; names(resumo)[4] <- "n"
  list(alertas = al, resumo = resumo)
}

#' Alertas novos por rodada (exercicio, periodo), para dimensionar a revisão; `desde` = primeiro exercicio considerado.
alertas_novos_por_rodada <- function(al_prior, desde = 2022L) {
  n <- al_prior[al_prior$status == "nova" & !is.na(al_prior$exercicio) & al_prior$exercicio >= desde, ]
  if (!nrow(n)) return(data.frame(exercicio = integer(0), periodo = integer(0), subtipo = character(0), n = integer(0)))
  t <- as.data.frame(table(exercicio = n$exercicio, periodo = n$periodo, subtipo = n$subtipo), stringsAsFactors = FALSE)
  t <- t[t$Freq > 0, ]; names(t)[4] <- "n"; t$exercicio <- as.integer(t$exercicio); t$periodo <- as.integer(t$periodo); t
}

ALERTA_CORTE_ABA <- 0.05     # aba do Excel: só alertas (b) acima de 5% da receita da UF; o resto vira contagem por tipo

#' Aba de alertas do Excel do E6: `lista` = alertas novos (b) com materialidade > `corte`; `contagem` = demais novos por tipo/subtipo
#' (inclui os alertas sem valor em R$, (c) e (d), que não têm materialidade). `p`: saída de `priorizar_alertas()`.
aba_alertas <- function(p, corte = ALERTA_CORTE_ABA) {
  n <- p$alertas[p$alertas$status == "nova", ]
  na_lista <- n$tipo == "b" & !is.na(n$materialidade) & n$materialidade > corte
  cont <- n[!na_lista, ]
  contagem <- if (nrow(cont)) { t <- as.data.frame(table(tipo = cont$tipo, subtipo = cont$subtipo), stringsAsFactors = FALSE); t[t$Freq > 0, ] } else
    data.frame(tipo = character(0), subtipo = character(0), Freq = integer(0))
  names(contagem)[3] <- "n"
  list(lista = n[na_lista, ], contagem = contagem)
}
