# E2.8b: regra explicita de inicio da reclassificacao de pessoal no RREO (docs/nota_quebras.md, secao 6).
# Parametros FIXADOS em 04/11/2026, antes de computar: nenhum deles muda depois de ver o resultado.
# Uma "mudanca pos-resultado" so entra registrada como tal (STATUS).

RECLASS_X <- 0.25            # variacao anual do pessoal no RREO (mesmo bimestre do ano anterior) de pelo menos 25%
RECLASS_PP <- 0.20           # e acima da variacao anual do RGF (Executivo) em pelo menos 20 p.p. (sem salto correspondente no RGF)
RECLASS_PERSIST <- 2L        # por pelo menos 2 bimestres consecutivos (a corrida atravessa a virada de ano)
RECLASS_JANELA <- c(2024L, 1L)   # corridas que comecam daqui em diante sao candidatas a "reclassificacao de 2025"; as anteriores so informativas
RECLASS_GRADE <- list(x = c(0.15, 0.25, 0.40), pp = c(0.10, 0.20, 0.30), persist = c(2L, 3L))   # sensibilidade declarada, nao muda a regra

#' Indice cronologico do bimestre (6 por ano), para detectar bimestres consecutivos.
indice_bim <- function(exercicio, periodo) as.integer(exercicio) * 6L + as.integer(periodo) - 1L

#' Corridas de bimestres sinalizados por UF. `yy`: cod_ibge, exercicio, periodo, rreo_yoy, rgf_yoy (variacoes relativas).
#' Sinal do bimestre: rreo_yoy >= x e (rreo_yoy - rgf_yoy) >= pp; bimestre sem RGF ou sem yoy nao sinaliza (e quebra a corrida).
#' Devolve uma linha por corrida de pelo menos `persist` bimestres consecutivos.
runs_reclassificacao <- function(yy, x = RECLASS_X, pp = RECLASS_PP, persist = RECLASS_PERSIST) {
  vazio <- data.frame(cod_ibge = integer(0), ini_exercicio = integer(0), ini_periodo = integer(0), fim_exercicio = integer(0),
                      fim_periodo = integer(0), n_bim = integer(0), rreo_yoy_medio = numeric(0), rgf_yoy_medio = numeric(0))
  if (!nrow(yy)) return(vazio)
  yy <- yy[order(yy$cod_ibge, yy$exercicio, yy$periodo), ]
  yy$i <- indice_bim(yy$exercicio, yy$periodo)
  yy$flag <- !is.na(yy$rreo_yoy) & !is.na(yy$rgf_yoy) & yy$rreo_yoy >= x & (yy$rreo_yoy - yy$rgf_yoy) >= pp
  out <- list()
  for (u in unique(yy$cod_ibge)) {
    d <- yy[yy$cod_ibge == u & yy$flag, ]
    if (!nrow(d)) next
    g <- cumsum(c(TRUE, diff(d$i) != 1L))
    for (k in unique(g)) {
      s <- d[g == k, ]
      if (nrow(s) < persist) next
      n <- nrow(s)
      out[[length(out) + 1L]] <- data.frame(cod_ibge = u, ini_exercicio = s$exercicio[1], ini_periodo = s$periodo[1],
                                            fim_exercicio = s$exercicio[n], fim_periodo = s$periodo[n], n_bim = n,
                                            rreo_yoy_medio = mean(s$rreo_yoy), rgf_yoy_medio = mean(s$rgf_yoy))
    }
  }
  if (!length(out)) return(vazio)
  do.call(rbind, out)
}

#' Marca as corridas que comecam na janela de interesse (candidatas a reclassificacao de 2025 em diante).
marcar_janela <- function(runs, janela = RECLASS_JANELA) {
  runs$na_janela <- indice_bim(runs$ini_exercicio, runs$ini_periodo) >= indice_bim(janela[1], janela[2])
  runs
}

#' Excedente de pessoal de cada corrida: pessoal do RREO menos o esperado pela variacao do RGF sobre o mesmo bimestre do ano anterior,
#' somado nos bimestres da corrida, e a razao ao total da despesa dos mesmos bimestres. `pessoal`: cod_ibge, exercicio, periodo, valor
#' (fluxo do bimestre); `desp_total`: idem para a despesa primaria total; `yy` como acima.
excedente_runs <- function(runs, pessoal, desp_total, yy) {
  if (!nrow(runs)) { runs$excedente <- numeric(0); runs$desp_total <- numeric(0); runs$excedente_sobre_despesa <- numeric(0); return(runs) }
  p <- merge(pessoal, yy[, c("cod_ibge", "exercicio", "periodo", "rreo_yoy", "rgf_yoy")], by = c("cod_ibge", "exercicio", "periodo"))
  p <- merge(p, setNames(desp_total, c("cod_ibge", "exercicio", "periodo", "desp")), by = c("cod_ibge", "exercicio", "periodo"), all.x = TRUE)
  p$i <- indice_bim(p$exercicio, p$periodo)
  p$exc <- p$valor - p$valor / (1 + p$rreo_yoy) * (1 + p$rgf_yoy)
  runs$excedente <- NA_real_; runs$desp_total <- NA_real_
  for (j in seq_len(nrow(runs))) {
    a <- indice_bim(runs$ini_exercicio[j], runs$ini_periodo[j]); b <- indice_bim(runs$fim_exercicio[j], runs$fim_periodo[j])
    s <- p[p$cod_ibge == runs$cod_ibge[j] & p$i >= a & p$i <= b, ]
    runs$excedente[j] <- sum(s$exc, na.rm = TRUE); runs$desp_total[j] <- sum(s$desp, na.rm = TRUE)
  }
  runs$excedente_sobre_despesa <- ifelse(runs$desp_total > 0, runs$excedente / runs$desp_total, NA_real_)
  runs
}

#' Sensibilidade declarada da regra: primeira corrida na janela de cada UF para cada combinacao da grade.
grade_inicio <- function(yy, ufs, grade = RECLASS_GRADE, janela = RECLASS_JANELA) {
  g <- expand.grid(x = grade$x, pp = grade$pp, persist = grade$persist)
  out <- lapply(seq_len(nrow(g)), function(k) {
    r <- marcar_janela(runs_reclassificacao(yy, g$x[k], g$pp[k], g$persist[k]), janela)
    r <- r[r$na_janela & r$cod_ibge %in% ufs, ]
    do.call(rbind, lapply(ufs, function(u) {
      s <- r[r$cod_ibge == u, ]
      data.frame(x = g$x[k], pp = g$pp[k], persist = g$persist[k], cod_ibge = u,
                 inicio = if (nrow(s)) sprintf("%d b%d", s$ini_exercicio[1], s$ini_periodo[1]) else NA_character_,
                 n_bim = if (nrow(s)) s$n_bim[1] else NA_integer_)
    }))
  })
  do.call(rbind, out)
}
