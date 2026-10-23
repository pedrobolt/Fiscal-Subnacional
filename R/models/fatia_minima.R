# Modelos da fatia mínima (E1.5): total anual do primário regional (R$ bi, superávit positivo)
# a partir de uma série mensal data.frame(data, valor_bi).

#' Só o que estaria publicado no cutoff: meses até `mes_corte` do ano `ano_t`.
#' Toda previsão passa por aqui, para não usar informação futura.
info_disponivel <- function(serie, ano_t, mes_corte) {
  limite <- as.Date(sprintf("%d-%02d-01", ano_t, mes_corte))
  serie[serie$data <= limite, ]
}

soma_meses <- function(serie, ano, meses) {
  d <- serie[as.integer(format(serie$data, "%Y")) == ano &
               as.integer(format(serie$data, "%m")) %in% meses, ]
  if (nrow(d) < length(meses)) return(NA_real_)
  sum(d$valor_bi)
}

#' Naïve: o total do ano anterior.
prever_naive <- function(serie, ano_t, mes_corte) {
  soma_meses(info_disponivel(serie, ano_t, mes_corte), ano_t - 1, 1:12)
}

#' Extrapolação do acumulado: acumulado de jan..corte do ano t mais a média, nos últimos
#' `janela` anos, do que foi realizado de corte+1..dez. Forma aditiva: a razão acumulado/participação
#' explode quando o total anual fica perto de zero (comum no primário regional).
prever_acumulado <- function(serie, ano_t, mes_corte, janela = 5) {
  s <- info_disponivel(serie, ano_t, mes_corte)
  acum <- soma_meses(s, ano_t, seq_len(mes_corte))
  restos <- vapply((ano_t - janela):(ano_t - 1),
                   function(y) soma_meses(s, y, (mes_corte + 1):12), numeric(1))
  if (is.na(acum) || anyNA(restos)) return(NA_real_)
  acum + mean(restos)
}

MODELOS_FATIA <- list(naive = prever_naive, acumulado = prever_acumulado)
