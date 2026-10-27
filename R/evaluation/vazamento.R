# E3.7: data de corte, disponibilidade da informação e teste automático de vazamento.
# Convenção (27/10/2026): o corte do mês m do ano t é a data de divulgação do BCB do mês m. O BCB entra como
# "dados até o mês m"; RREO, STN e LDO entram só com `available_at` <= data de corte.
# Limitação declarada: o PIB do ano t é o realizado (não conhecido no corte); em produção vem de premissas.yml.

#' Data de divulgação do BCB (NFSP regional) do mês de referência (ano, mes). Usa `calendario`
#' (data.frame com ano, mes, data) se tiver a linha; senão, aproximação documentada: último dia útil (seg–sex, sem
#' feriados) do mês seguinte. Feriados podem deslocar a data real em até 1–2 dias.
data_divulgacao_bcb <- function(ano, mes, calendario = NULL) {
  if (!is.null(calendario)) {
    k <- which(calendario$ano == ano & calendario$mes == mes)
    if (length(k) == 1) return(as.Date(calendario$data[k]))
  }
  prox <- as.Date(sprintf("%d-%02d-01", ano + (mes + 1 > 12), (mes %% 12) + 1))
  d <- seq(prox, by = "month", length.out = 2)[2] - 1   # último dia do mês seguinte
  while (as.integer(format(d, "%u")) >= 6) d <- d - 1
  d
}

#' `available_at` provisório do RREO (E2.7 ainda não mediu a defasagem completa). Entrada: extrato (cod_ibge, uf,
#' exercicio, periodo, status HO/RE, data_status). HO: data_status. RE: prazo legal (fim do bimestre + 30 dias) +
#' mediana do atraso dos HO da mesma UF × período (reserva: mediana nacional do período). Falha de forma explícita se
#' faltar o extrato ou se não houver HO no período.
available_at_rreo <- function(ext) {
  if (is.null(ext) || nrow(ext) == 0) stop("Extrato ausente: o available_at do RREO exige o extrato_entregas (rode atualizar_rreo()).", call. = FALSE)
  obrig <- c("uf", "exercicio", "periodo", "status", "data_status")
  if (length(faltam <- setdiff(obrig, names(ext)))) stop("Extrato sem as colunas: ", paste(faltam, collapse = ", "), call. = FALSE)
  fim_bim <- vapply(seq_len(nrow(ext)), function(i)
    as.numeric(seq(as.Date(sprintf("%d-%02d-01", ext$exercicio[i], 2 * ext$periodo[i])), by = "month", length.out = 2)[2] - 1), numeric(1))
  prazo <- as.Date(fim_bim, origin = "1970-01-01") + 30
  ds <- as.Date(ext$data_status)
  atraso <- as.numeric(ds - prazo)
  ho <- ext$status == "HO"
  if (!any(ho)) stop("Sem demonstrativos homologados para estimar o atraso dos retificados.", call. = FALSE)
  med_uf <- tapply(atraso[ho], paste(ext$uf[ho], ext$periodo[ho]), stats::median)
  med_nac <- tapply(atraso[ho], ext$periodo[ho], stats::median)
  avail <- ds; fonte <- rep("data_status", nrow(ext))
  for (i in which(!ho)) {
    m <- unname(med_uf[paste(ext$uf[i], ext$periodo[i])])
    if (is.na(m)) {
      m <- unname(med_nac[as.character(ext$periodo[i])])
      if (is.na(m)) stop("Sem homologados no período ", ext$periodo[i], " nem na mediana nacional.", call. = FALSE)
      fonte[i] <- "mediana_nacional_periodo"
    } else fonte[i] <- "mediana_uf_periodo"
    avail[i] <- prazo[i] + round(m)
  }
  ext$available_at <- avail; ext$fonte_available_at <- fonte
  ext
}

#' Só o que existe na data de corte: BCB até o mês m do ano t; PIB até o ano t; RREO/STN/LDO com available_at <= corte.
montar_info <- function(fontes, ano_t, m, calendario = NULL) {
  corte <- data_divulgacao_bcb(ano_t, m, calendario)
  info <- list(ano_t = ano_t, corte_mes = m, data_corte = corte,
               bcb = fontes$bcb[fontes$bcb$data <= as.Date(sprintf("%d-%02d-01", ano_t, m)), ],
               pib = fontes$pib[fontes$pib$ano <= ano_t, ])
  for (nome in intersect(c("rreo", "stn", "ldo"), names(fontes))) {
    f <- fontes[[nome]]
    if (!("available_at" %in% names(f))) stop("Fonte '", nome, "' sem coluna available_at.", call. = FALSE)
    info[[nome]] <- f[as.Date(f$available_at) <= corte, , drop = FALSE]
  }
  info
}

#' Versão com vazamento (só para provar que o teste o detecta): não filtra nada.
montar_info_vazado <- function(fontes, ano_t, m, calendario = NULL) {
  c(list(ano_t = ano_t, corte_mes = m, data_corte = data_divulgacao_bcb(ano_t, m, calendario)), fontes)
}

#' Perturba tudo o que é futuro em relação ao corte (BCB depois do mês m; PIB de anos > t; RREO/STN/LDO com
#' available_at depois da data de corte). O PIB do ano t NÃO é perturbado (limitação declarada).
perturbar_fontes <- function(fontes, ano_t, m, calendario = NULL, semente = 1) {
  set.seed(semente)
  corte <- data_divulgacao_bcb(ano_t, m, calendario)
  fut <- fontes$bcb$data > as.Date(sprintf("%d-%02d-01", ano_t, m))
  fontes$bcb$valor_bi[fut] <- fontes$bcb$valor_bi[fut] + stats::rnorm(sum(fut), 0, 500)
  fontes$pib$pib_bi[fontes$pib$ano > ano_t] <- fontes$pib$pib_bi[fontes$pib$ano > ano_t] * 3
  for (nome in intersect(c("rreo", "stn", "ldo"), names(fontes))) {
    f <- fontes[[nome]]; fut <- as.Date(f$available_at) > corte
    for (col in grep("^valor", names(f), value = TRUE)) f[[col]][fut] <- f[[col]][fut] + stats::rnorm(sum(fut), 0, 500)
    fontes[[nome]] <- f
  }
  fontes
}

#' Roda cada candidato `function(info, ano_t, m)` com as fontes originais e perturbadas; sinaliza mudança na previsão.
#' Retorna data.frame(candidato, ano, corte, mudou).
testar_vazamento <- function(candidatos, fontes, anos, cortes, montar = montar_info, calendario = NULL) {
  linhas <- list()
  for (a in anos) for (m in cortes) {
    f1 <- fontes; f2 <- perturbar_fontes(fontes, a, m, calendario)
    for (nome in names(candidatos)) {
      p1 <- candidatos[[nome]](montar(f1, a, m, calendario), a, m)
      p2 <- candidatos[[nome]](montar(f2, a, m, calendario), a, m)
      mudou <- !((is.na(p1) && is.na(p2)) || isTRUE(all.equal(p1, p2, tolerance = 1e-9)))
      linhas[[length(linhas) + 1]] <- data.frame(candidato = nome, ano = a, corte = m, mudou = mudou)
    }
  }
  do.call(rbind, linhas)
}
