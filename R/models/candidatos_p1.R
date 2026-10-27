# Adaptadores dos candidatos do P1 à interface comum `function(info, ano_t, m)` -> total anual previsto (R$ bi),
# onde `info` vem de montar_info() (E3.7). Implementados: base (SRW em R$), desafiantes só-BCB, E4.1 e combinação.
# FPE/FPM e LDO entram aqui quando existirem. Anos a excluir do treino (ex.: 2020–22) vêm em `info$excluir`.

excluir_de <- function(info) if (is.null(info$excluir)) integer(0) else info$excluir

#' Total previsto por um modelo do restante em % do PIB, montando o ano-alvo só com a informação do corte.
#' `serie`: série do BCB do alvo (regional por padrão; componentes no E4.1).
prever_total_restante <- function(info, ano_t, m, espec, serie = info$bcb, g = NULL) {
  s <- serie; pib <- info$pib
  p <- painel_restante(s, pib, cortes = m)           # só anos completos (o ano-alvo ainda está incompleto em `s`)
  if (!is.null(g)) p$g <- vapply(p$ano, g, numeric(1))   # regressor extra por ano (função ano -> valor)
  P <- pib$pib_bi[pib$ano == ano_t]; Pl <- pib$pib_bi[pib$ano == ano_t - 1]
  A <- soma_meses(s, ano_t, 1:m); Rl <- soma_meses(s, ano_t - 1, (m + 1):12)
  if (!length(P) || !length(Pl) || is.na(A) || is.na(Rl)) return(NA_real_)
  alvo <- data.frame(ano = ano_t, corte = m, A = A, R = NA_real_, Y = NA_real_, pib = P, a = A / P, r = NA_real_,
                     r_lag = Rl / Pl, E = as.integer(ano_t %% 4 == 2), Emun = as.integer(ano_t %% 4 == 0), tend = ano_t - 2000)
  if (!is.null(g)) alvo$g <- g(ano_t)
  pm <- rbind(p[p$ano < ano_t, ], alvo)
  rhat <- prever_restante(pm, ano_t, espec, excluir_de(info))
  A + rhat * P
}

#' m3 da definição do E4.1: restante ~ acumulado + restante(t-1) + eleição do próprio componente (em % do PIB).
ESPEC_M3_ESTADOS    <- list(formula = r ~ a + r_lag + E)                                     # dummy de eleição estadual (E)
ESPEC_M3_MUNICIPIOS <- list(formula = r ~ a + r_lag + Emun)                  # dummy de eleição municipal (Emun)

#' E4.1 (definição registrada em 27/10/2026): soma de duas previsões, m3 no componente estadual (SGS 4643) e m3 no
#' componente municipal (SGS 4644), cada um com a dummy de eleição do próprio componente.
prever_e41 <- function(info, ano_t, m) {
  prever_total_restante(info, ano_t, m, ESPEC_M3_ESTADOS, serie = info$bcb_est) +
    prever_total_restante(info, ano_t, m, ESPEC_M3_MUNICIPIOS, serie = info$bcb_mun)
}

#' Diagnósticos do E4.1 (fora da lista fechada): m3 só em um componente, SRW no outro.
prever_diag_e41_est <- function(info, ano_t, m)
  prever_total_restante(info, ano_t, m, ESPEC_M3_ESTADOS, serie = info$bcb_est) + prever_srw(info$bcb_mun, ano_t, m)
prever_diag_e41_mun <- function(info, ano_t, m)
  prever_srw(info$bcb_est, ano_t, m) + prever_total_restante(info, ano_t, m, ESPEC_M3_MUNICIPIOS, serie = info$bcb_mun)

CANDIDATOS_P1_BASE <- list(
  srw_brl      = function(info, ano_t, m) prever_srw(info$bcb, ano_t, m),
  srw_pib      = function(info, ano_t, m) prever_total_restante(info, ano_t, m, ESPEC_RESTANTE$srw_pib),
  acumulado_j5 = function(info, ano_t, m) prever_acumulado(info$bcb, ano_t, m, 5),
  m2           = function(info, ano_t, m) prever_total_restante(info, ano_t, m, ESPEC_RESTANTE$m2),
  m3           = function(info, ano_t, m) prever_total_restante(info, ano_t, m, ESPEC_RESTANTE$m3),
  e41          = prever_e41
)

#' Combinação: média simples, com pesos iguais e não estimados, de todos os candidatos da lista disponíveis no corte
#' (base inclusa; os que não têm previsão no corte ficam de fora da média). NA se nenhum estiver disponível.
prever_combinacao <- function(info, ano_t, m, candidatos = CANDIDATOS_P1_BASE) {
  p <- vapply(candidatos, function(f) f(info, ano_t, m), numeric(1))
  if (all(is.na(p))) NA_real_ else mean(p, na.rm = TRUE)
}

# Conjunto do PR #25 (E4.1 + combinação sobre 6 modelos), mantido para a conferência de reprodutibilidade (regra 7).
CANDIDATOS_P1_25 <- c(CANDIDATOS_P1_BASE, list(combinacao = prever_combinacao))

#' Backtest dos candidatos sobre as fontes (sempre via montar_info). `excluir`: anos fora do treino e do teste.
#' Retorna uma linha por ano × corte × modelo, com erro em R$ bi e em p.p. do PIB do ano-alvo.
backtest_p1 <- function(candidatos, fontes, anos, cortes = 1:11, excluir = integer(0), calendario = NULL) {
  linhas <- list()
  for (a in setdiff(anos, excluir)) {
    real <- total_anual(fontes$bcb, a); P <- fontes$pib$pib_bi[fontes$pib$ano == a]
    if (is.na(real) || !length(P)) next
    for (m in cortes) {
      info <- montar_info(fontes, a, m, calendario); info$excluir <- excluir
      for (nome in names(candidatos)) {
        prev <- candidatos[[nome]](info, a, m)
        linhas[[length(linhas) + 1]] <- data.frame(ano = a, corte = m, modelo = nome, previsao = prev, realizado = real,
                                                   erro = prev - real, erro_pp = (prev - real) / P * 100, pib = P)
      }
    }
  }
  do.call(rbind, linhas)
}

#' FPE/FPM (E4.1b): g(t, m) = (FPE+FPM acumulados jan..m de t)/PIB_t - (idem no ano t-1)/PIB_{t-1}, em fração do PIB.
#' NA se faltar qualquer mês jan..m em t ou t-1 na fonte `stn` já filtrada por available_at (sem imputação).
g_stn <- function(info, ano, m, lag = 0L) {
  mm <- m - lag                                  # `lag`: nº de meses finais ainda não divulgados (sensibilidade de available_at)
  if (mm < 1) return(NA_real_)
  acum <- function(a) {
    z <- info$stn[info$stn$ano == a & info$stn$mes %in% 1:mm, ]
    if (nrow(z) < mm || anyNA(z$valor_fpe) || anyNA(z$valor_fpm)) return(NA_real_)
    sum(z$valor_fpe + z$valor_fpm)
  }
  P <- info$pib$pib_bi[info$pib$ano == ano]; Pl <- info$pib$pib_bi[info$pib$ano == ano - 1]
  if (!length(P) || !length(Pl)) return(NA_real_)
  acum(ano) / P - acum(ano - 1) / Pl
}

ESPEC_FPE_FPM <- list(formula = r ~ a + r_lag + E + g)

#' Sensibilidade (diagnóstico): STN com um mês a mais de defasagem; g usa jan..m-1.
prever_fpe_fpm_lag1 <- function(info, ano_t, m) prever_fpe_fpm(info, ano_t, m, lag = 1L)

#' Candidato fpe_fpm: m3 regional + g. Se `info$stn` não existir, falha de forma explícita (nunca cai em m3 em silêncio).
prever_fpe_fpm <- function(info, ano_t, m, lag = 0L) {
  if (is.null(info$stn)) stop("Fonte 'stn' ausente em info: o candidato fpe_fpm exige as transferências da STN.", call. = FALSE)
  prever_total_restante(info, ano_t, m, ESPEC_FPE_FPM, g = function(a) g_stn(info, a, m, lag))
}

# Lista corrente do P1: base + desafiantes disponíveis (fpe_fpm entra aqui; ldo foi descartado em 27/10/2026).
# A combinação é a média simples dos candidatos da lista disponíveis no corte, agora incluindo fpe_fpm.
CANDIDATOS_P1_COM_FPE <- c(CANDIDATOS_P1_BASE, list(fpe_fpm = prever_fpe_fpm))
CANDIDATOS_P1 <- c(CANDIDATOS_P1_COM_FPE,
                   list(combinacao = function(info, ano_t, m) prever_combinacao(info, ano_t, m, candidatos = CANDIDATOS_P1_COM_FPE)))
CANDIDATOS_DIAGNOSTICO <- list(diag_e41_est_m3 = prever_diag_e41_est, diag_e41_mun_m3 = prever_diag_e41_mun,
                               diag_combinacao_sem_fpe = prever_combinacao)
