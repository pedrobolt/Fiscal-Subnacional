# Gap P1 x P2 dos estados (E3.6). Regra congelada em docs/contrato.md ("Regra de narrativa do gap P1 x P2", 30/10/2026).
# g(t) = P2(t) - P1(t), fluxo do bimestre, R$ bi, superavit positivo; r(t) = g / receita primaria agregada. A classe governa so a narrativa.

GAP_K_MAD <- 4          # multiplos do MAD bruto
GAP_PISO <- 0.01        # piso: 1% da receita agregada
GAP_ANOS_REF <- 3L      # mesmo bimestre dos 3 anos anteriores
GAP_MIN_REF <- 2L       # minimo de observacoes na referencia
GAP_JANELA <- 6L        # bimestres consecutivos para a regra de instabilidade
GAP_FRONTEIRA <- 2023L  # a partir de 2023 b1 o Anexo 6 exclui o RPPS: a referencia nao atravessa
GAP_INICIO_RECLASS <- c(2025L, 1L)

#' P2 dos estados por bimestre: soma do resultado primario do Anexo 6 e da receita primaria. `x`: cod_ibge, exercicio, periodo, rec_total,
#' primario_a6 (fluxo do bimestre; `conceito_unico_bimestral`). Bimestre sem as `n_ufs` UFs completas fica NA.
p2_estados_bim <- function(x, n_ufs = 27L) {
  k <- paste(x$exercicio, x$periodo)
  ok <- !is.na(x$primario_a6) & !is.na(x$rec_total)
  d <- do.call(rbind, lapply(split(seq_len(nrow(x)), k), function(i) {
    n <- sum(ok[i])
    data.frame(exercicio = x$exercicio[i[1]], periodo = x$periodo[i[1]], n_ufs = n,
               p2 = if (n == n_ufs) sum(x$primario_a6[i]) / 1e9 else NA_real_, rec = if (n == n_ufs) sum(x$rec_total[i]) / 1e9 else NA_real_)
  }))
  d[order(d$exercicio, d$periodo), ]
}

#' P1 dos estados por bimestre: SGS 4643 (R$ milhoes, deficit positivo, fluxo mensal) -> R$ bi, superavit positivo, somado nos dois meses.
p1_estados_bim <- function(sgs) {
  a <- as.integer(format(sgs$data, "%Y")); m <- as.integer(format(sgs$data, "%m")); p <- (m + 1L) %/% 2L
  d <- stats::aggregate(list(v = -sgs$valor / 1000, n = 1L), list(exercicio = a, periodo = p), sum)
  d$p1 <- ifelse(d$n == 2L, d$v, NA_real_)
  d[order(d$exercicio, d$periodo), c("exercicio", "periodo", "p1")]
}

#' Gap bruto e sem reclassificacao. `excedente`: exercicio, periodo, excedente (R$, soma RJ/PR/RS; ausente = 0).
gap_bimestral <- function(p2, p1, excedente = NULL) {
  d <- merge(p2, p1, by = c("exercicio", "periodo"))
  d <- d[order(d$exercicio, d$periodo), ]
  d$exc <- 0
  if (!is.null(excedente)) { k <- match(paste(d$exercicio, d$periodo), paste(excedente$exercicio, excedente$periodo)); d$exc <- ifelse(is.na(k), 0, excedente$excedente[k] / 1e9) }
  d$g <- d$p2 - d$p1; d$r <- d$g / d$rec
  d$g_sem <- d$g + d$exc; d$r_sem <- d$g_sem / d$rec
  d$apos_reclass <- d$exercicio > GAP_INICIO_RECLASS[1] | (d$exercicio == GAP_INICIO_RECLASS[1] & d$periodo >= GAP_INICIO_RECLASS[2])
  d
}

#' Classifica uma serie r (data.frame com exercicio, periodo, r em ordem temporal). Devolve classe, med_ref, mad_ref, n_ref.
#' Classes: consistente, atipico, instavel, sem_referencia, excluido (anos em `excluir_anos`: nao sao referencia nem classificados).
classificar_gap <- function(d, col = "r", excluir_anos = integer(0), k = GAP_K_MAD, piso = GAP_PISO, anos_ref = GAP_ANOS_REF,
                            min_ref = GAP_MIN_REF, janela = GAP_JANELA, fronteira = GAP_FRONTEIRA) {
  r <- d[[col]]; n <- nrow(d)
  seg <- as.integer(d$exercicio >= fronteira)
  r_ok <- ifelse(d$exercicio %in% excluir_anos, NA_real_, r)
  med <- mad <- rep(NA_real_, n); nref <- integer(n)
  for (i in seq_len(n)) {
    j <- which(d$periodo == d$periodo[i] & d$exercicio < d$exercicio[i] & d$exercicio >= d$exercicio[i] - anos_ref & seg == seg[i] & !is.na(r_ok))
    nref[i] <- length(j)
    if (length(j) >= min_ref) { med[i] <- stats::median(r[j]); mad[i] <- stats::median(abs(r[j] - med[i])) }
  }
  classe <- rep("sem_referencia", n)
  classe[d$exercicio %in% excluir_anos] <- "excluido"
  cl <- !(classe %in% c("excluido")) & !is.na(med) & !is.na(r)
  atip <- cl & abs(r - med) > pmax(k * mad, piso)
  classe[cl] <- ifelse(atip[cl], "atipico", "consistente")
  # instabilidade: janela de `janela` bimestres consecutivos, todos classificaveis
  t_idx <- d$exercicio * 6L + d$periodo
  for (i in seq_len(n)) {
    if (!cl[i] || i < janela) next
    w <- (i - janela + 1L):i
    if (!all(cl[w]) || any(diff(t_idx[w]) != 1L)) next
    ent <- sum(atip[w]) >= 3L
    mr <- stats::median(r[w]); mm <- stats::median(med[w])
    sinal <- abs(mr) > piso && sign(mr) != sign(mm) && sign(mm) != 0
    if (ent || sinal) classe[i] <- "instavel"
  }
  data.frame(classe = classe, med_ref = med, mad_ref = mad, n_ref = nref, stringsAsFactors = FALSE)
}

#' Resumo por classe: contagem e % entre os classificaveis (consistente + atipico + instavel + quebra_conhecida); sem_referencia e excluido a parte.
resumo_classes <- function(classe) {
  t <- table(factor(classe, levels = c("consistente", "atipico", "instavel", "quebra_conhecida", "sem_referencia", "excluido")))
  clas <- c("consistente", "atipico", "instavel", "quebra_conhecida")
  data.frame(classe = names(t), n = as.integer(t), pct_classificaveis = ifelse(names(t) %in% clas, 100 * as.integer(t) / sum(t[clas]), NA_real_), stringsAsFactors = FALSE)
}
