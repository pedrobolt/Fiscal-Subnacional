# Gate pré-E4 (24/10/2026): (a) passeio aleatório sazonal no BCB; (b) o primário RREO acumulado dos
# estados melhora a previsão do total anual do BCB frente ao passeio aleatório sazonal?
# Tudo em R$ bi, superávit positivo. Teste simples, só para medir ganho; não é o torneio formal.

#' Passeio aleatório sazonal: acumulado até o corte + o que se realizou de corte+1..dez no ano anterior.
prever_srw <- function(serie, ano_t, mes_corte) prever_acumulado(serie, ano_t, mes_corte, janela = 1)

#' Primário dos estados no RREO (cumulativo até o bimestre), somando as 27 UFs; R$ bi.
#' 2018–2022: RREO6ResultadoPrimarioEstadosMunicipios (VALOR INCORRIDO ou VALOR); 2023+: ...SemRPPSAcimaDaLinha (VALOR).
#' 2015–2017 não entra: o Anexo 6 só traz empenhado/liquidado, outro conceito (ver STATUS).
#' Retorna data.frame(ano, bimestre, ufs, valor_bi); `valor_bi` é NA se faltar alguma UF.
rreo_primario_estados <- function(rreo) {
  a6 <- rreo[grepl("Anexo 06", rreo$anexo), ]
  ok <- (a6$cod_conta == "RREO6ResultadoPrimarioEstadosMunicipios" & a6$coluna %in% c("VALOR INCORRIDO", "VALOR")) |
        (a6$cod_conta == "ResultadoPrimarioSemRPPSAcimaDaLinha" & a6$coluna == "VALOR")
  d <- a6[ok, c("exercicio", "periodo", "cod_ibge", "valor")]
  d <- d[!duplicated(d[c("exercicio", "periodo", "cod_ibge")]), ]
  # Reserva: UF x bimestre sem a linha "acima da linha" usa a "abaixo da linha" (mesmo valor nos casos conferidos)
  ab <- a6[a6$cod_conta == "ResultadoPrimarioAbaixoDaLinha" & grepl("^At. o Bimestre / ", a6$coluna) &
           a6$coluna == paste0(substring(a6$coluna, 1, nchar(a6$coluna) - 4), a6$exercicio), c("exercicio", "periodo", "cod_ibge", "valor")]
  ab <- ab[!duplicated(ab[c("exercicio", "periodo", "cod_ibge")]), ]
  falta <- ab[!paste(ab$exercicio, ab$periodo, ab$cod_ibge) %in% paste(d$exercicio, d$periodo, d$cod_ibge), ]
  attr_reserva <- nrow(falta)
  d <- rbind(d, falta)
  agg <- stats::aggregate(cbind(valor = valor, ufs = 1) ~ exercicio + periodo, data = d, FUN = sum)
  data.frame(ano = agg$exercicio, bimestre = agg$periodo, ufs = agg$ufs,
             valor_bi = ifelse(agg$ufs == 27, agg$valor / 1e9, NA_real_), usos_reserva = attr_reserva)
}

x_rreo <- function(x, ano, b) {
  v <- x$valor_bi[x$ano == ano & x$bimestre == b]
  if (length(v) == 1) v else NA_real_
}

#' Bimestres do RREO disponíveis no corte m do BCB. Regra conservadora: o bimestre b (fecha no mês 2b,
#' prazo legal até o fim de 2b+1) só entra com o BCB do mês 2b+1, isto é, b = floor((m-1)/2).
bimestres_no_corte <- function(m) (m - 1) %/% 2

#' Momento: SRW + g * (variação interanual do acumulado), com a variação medida no BCB (mesma fonte) ...
prever_momento_bcb <- function(serie, ano_t, m, g) {
  s <- info_disponivel(serie, ano_t, m)
  prever_srw(serie, ano_t, m) + g * (soma_meses(s, ano_t, 1:m) - soma_meses(s, ano_t - 1, 1:m))
}
#' ... ou no RREO dos estados (outra fonte): é este contraste que mede o ganho do RREO.
prever_momento_rreo <- function(serie, x, ano_t, m, g) {
  b <- bimestres_no_corte(m)
  if (b < 1) return(NA_real_)
  prever_srw(serie, ano_t, m) + g * (x_rreo(x, ano_t, b) - x_rreo(x, ano_t - 1, b))
}
#' Ponte: previsão do total anual do RREO (acumulado + restante do ano anterior) mais a diferença BCB-RREO do ano anterior.
prever_ponte_rreo <- function(serie_estados, x, ano_t, m, extra = 0) {
  b <- bimestres_no_corte(m)
  if (b < 1) return(NA_real_)
  rreo_hat <- x_rreo(x, ano_t, b) + (x_rreo(x, ano_t - 1, 6) - x_rreo(x, ano_t - 1, b))
  gap <- soma_meses(serie_estados, ano_t - 1, 1:12) - x_rreo(x, ano_t - 1, 6)
  rreo_hat + gap + extra
}

#' Candidatos do teste (b) para um alvo: "estaduais" ou "regionais". Em "regionais" só a parcela estadual
#' é ajustada pelo RREO; a municipal segue o SRW (não há RREO municipal histórico completo).
modelos_gate <- function(alvo, est, mun, x) {
  reg <- data.frame(data = est$data, valor_bi = est$valor_bi + mun$valor_bi[match(est$data, mun$data)])
  if (alvo == "estaduais") {
    s <- est
    list(srw = function(t, m) prever_srw(s, t, m),
         mom_bcb_g1 = function(t, m) prever_momento_bcb(s, t, m, 1),
         mom_rreo_g1 = function(t, m) prever_momento_rreo(s, x, t, m, 1),
         mom_bcb_g05 = function(t, m) prever_momento_bcb(s, t, m, 0.5),
         mom_rreo_g05 = function(t, m) prever_momento_rreo(s, x, t, m, 0.5),
         ponte_rreo = function(t, m) prever_ponte_rreo(s, x, t, m))
  } else {
    s <- reg
    list(srw = function(t, m) prever_srw(s, t, m),
         mom_bcb_g1 = function(t, m) prever_momento_bcb(est, t, m, 1) - prever_srw(est, t, m) + prever_srw(s, t, m),
         mom_rreo_g1 = function(t, m) prever_momento_rreo(est, x, t, m, 1) - prever_srw(est, t, m) + prever_srw(s, t, m),
         mom_bcb_g05 = function(t, m) prever_momento_bcb(est, t, m, 0.5) - prever_srw(est, t, m) + prever_srw(s, t, m),
         mom_rreo_g05 = function(t, m) prever_momento_rreo(est, x, t, m, 0.5) - prever_srw(est, t, m) + prever_srw(s, t, m),
         ponte_rreo = function(t, m) prever_ponte_rreo(est, x, t, m, extra = prever_srw(mun, t, m)))
  }
}

#' Backtest de uma lista de funções (ano, corte) -> previsão contra o total anual de `serie_real`.
backtest_modelos <- function(modelos, serie_real, anos, cortes = 1:11) {
  linhas <- list()
  for (ano in anos) {
    real <- total_anual(serie_real, ano)
    if (is.na(real)) next
    for (m in cortes) for (nome in names(modelos)) {
      prev <- modelos[[nome]](ano, m)
      linhas[[length(linhas) + 1]] <- data.frame(ano = ano, corte = m, modelo = nome, previsao = prev, realizado = real, erro = prev - real)
    }
  }
  do.call(rbind, linhas)
}

#' Resumo por modelo e corte, com RMSE relativo ao SRW e nº de anos em que o modelo erra menos que o SRW.
resumo_vs_srw <- function(bt) {
  # Comparação pareada: só ano x corte em que TODOS os modelos têm previsão
  bt <- bt[!is.na(bt$previsao) | FALSE, ]
  chave <- paste(bt$ano, bt$corte)
  completos <- names(which(table(chave) == length(unique(bt$modelo))))
  bt <- bt[chave %in% completos, ]
  base <- bt[bt$modelo == "srw", c("ano", "corte", "erro")]; names(base)[3] <- "erro_srw"
  bt <- merge(bt, base, by = c("ano", "corte"))
  bt <- bt[!is.na(bt$erro) & !is.na(bt$erro_srw), ]
  res <- resumir_erros(bt)
  g <- split(bt, list(bt$modelo, bt$corte), drop = TRUE)
  extra <- do.call(rbind, lapply(g, function(d) data.frame(modelo = d$modelo[1], corte = d$corte[1],
            rmse_srw = sqrt(mean(d$erro_srw^2)), anos_melhor = sum(abs(d$erro) < abs(d$erro_srw)))))
  out <- merge(res, extra, by = c("modelo", "corte"))
  out$rmse_rel_srw <- out$RMSE / out$rmse_srw
  out[order(out$modelo, out$corte), ]
}
