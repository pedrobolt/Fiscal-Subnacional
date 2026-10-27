# Adaptadores dos candidatos do P1 à interface comum `function(info, ano_t, m)` -> total anual previsto (R$ bi),
# onde `info` vem de montar_info() (E3.7). Implementados: base (SRW em R$) e desafiantes só-BCB. Os demais da lista
# fechada (E4.1, FPE/FPM, LDO, combinação) entram aqui quando forem implementados.

#' Total previsto por um modelo do restante em % do PIB, montando o ano-alvo só com a informação do corte.
prever_total_restante <- function(info, ano_t, m, espec, excluir = integer(0)) {
  s <- info$bcb; pib <- info$pib
  p <- painel_restante(s, pib, cortes = m)           # só anos completos (o ano-alvo ainda está incompleto em `s`)
  P <- pib$pib_bi[pib$ano == ano_t]; Pl <- pib$pib_bi[pib$ano == ano_t - 1]
  A <- soma_meses(s, ano_t, 1:m); Rl <- soma_meses(s, ano_t - 1, (m + 1):12)
  if (!length(P) || !length(Pl) || is.na(A) || is.na(Rl)) return(NA_real_)
  alvo <- data.frame(ano = ano_t, corte = m, A = A, R = NA_real_, Y = NA_real_, pib = P, a = A / P, r = NA_real_,
                     r_lag = Rl / Pl, E = as.integer(ano_t %% 4 == 2), Emun = as.integer(ano_t %% 4 == 0), tend = ano_t - 2000)
  pm <- rbind(p[p$ano < ano_t, ], alvo)
  rhat <- prever_restante(pm, ano_t, espec, excluir)
  A + rhat * P
}

CANDIDATOS_P1 <- list(
  srw_brl      = function(info, ano_t, m) prever_srw(info$bcb, ano_t, m),
  srw_pib      = function(info, ano_t, m) prever_total_restante(info, ano_t, m, ESPEC_RESTANTE$srw_pib),
  acumulado_j5 = function(info, ano_t, m) prever_acumulado(info$bcb, ano_t, m, 5),
  m2           = function(info, ano_t, m) prever_total_restante(info, ano_t, m, ESPEC_RESTANTE$m2),
  m3           = function(info, ano_t, m) prever_total_restante(info, ano_t, m, ESPEC_RESTANTE$m3)
)
