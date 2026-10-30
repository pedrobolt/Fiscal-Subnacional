# E6.1: rodada mensal automática. Funções puras e testáveis; a fiação com o Siconfi, o BCB e os scripts fica em scripts/rodada_mensal.R.
# Escopo aprovado em 30/10/2026: P1 (SRW) com intervalo e por esfera, P2 realizado dos estados por categoria (com RPPS oficial; sem RPPS como
# referência da LDO), gap P1 x P2, alertas, arquivo de previsões emitidas (com o m3 como modelo-sombra) e resumo com status.

SICONFI_MAX_CONEXOES <- 2L        # limite de conexões simultâneas ao Siconfi; a rodada é sequencial (1 conexão por vez)
RODADA_COD_DEGRADADA <- 2L        # código de saída da rodada degradada (0 = OK; 1 = erro fatal)
FAIXAS_CORTE <- c("1-4", "5-8", "9-11")

# ---- Etapas com falha isolada -----------------------------------------------------------------------------------------------

#' Roda `fun(ctx)` isolando erro e aviso fatal. Retorna uma linha: etapa, estado ("ok" | "falhou"), msg, segundos.
#' `ctx` é um ambiente compartilhado: a etapa guarda ali o que as seguintes usam. Uma etapa que falha não derruba as outras.
rodar_etapa <- function(nome, fun, ctx) {
  t0 <- Sys.time()
  r <- tryCatch({ fun(ctx); list(estado = "ok", msg = "") },
                error = function(e) list(estado = "falhou", msg = substr(gsub("[\r\n]+", " ", conditionMessage(e)), 1, 300)))
  data.frame(etapa = nome, estado = r$estado, msg = r$msg, segundos = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1),
             stringsAsFactors = FALSE)
}

#' Etapa pulada por opção (ex.: `--sem-download`): conta como incompleta, não como OK.
etapa_pulada <- function(nome, motivo) data.frame(etapa = nome, estado = "pulada", msg = motivo, segundos = 0, stringsAsFactors = FALSE)

#' Status da rodada: "OK" só se todas as etapas rodaram; senão "DEGRADADA", com a lista do que falhou ou foi pulado.
status_rodada <- function(etapas, avisos = character(0)) {
  ruim <- etapas[etapas$estado != "ok", ]
  list(status = if (nrow(ruim) == 0 && length(avisos) == 0) "OK" else "DEGRADADA",
       problemas = c(if (nrow(ruim)) sprintf("%s %s%s", ruim$etapa, ruim$estado, ifelse(nzchar(ruim$msg), paste0(": ", ruim$msg), "")), avisos))
}

#' Código de saída do processo: 0 se OK; `RODADA_COD_DEGRADADA` se degradada (um agendamento futuro não passa em silêncio).
codigo_saida <- function(status) if (identical(status, "OK")) 0L else RODADA_COD_DEGRADADA

# ---- Corte efetivo e P1 ---------------------------------------------------------------------------------------------------

#' Corte efetivo = o do DADO, não o da data da rodada: último mês publicado da série. Se o BCB não baixou, vale o último arquivo local
#' e o corte é o desse arquivo. `serie`: data.frame(data, valor_bi). Ano completo (m = 12): o ano é realizado, sem previsão.
corte_efetivo <- function(serie) {
  u <- max(serie$data)
  list(ultimo = u, ano_alvo = as.integer(format(u, "%Y")), m = as.integer(format(u, "%m")), completo = as.integer(format(u, "%m")) == 12L)
}

#' SRW em R$ por esfera no mesmo corte. `series`: lista nomeada (regional, estaduais, municipais), cada uma data.frame(data, valor_bi).
#' Acrescenta a linha "soma das esferas" (estaduais + municipais), que pela linearidade do SRW iguala o SRW regional, e a diferença.
p1_srw_esferas <- function(series, ano_alvo, m) {
  um <- function(nome, s) {
    acum <- soma_meses(s, ano_alvo, seq_len(m))
    rest <- if (m >= 12) 0 else soma_meses(s, ano_alvo - 1L, (m + 1):12)
    data.frame(esfera = nome, ano_alvo = ano_alvo, corte_m = m, acumulado_bi = acum, restante_ano_anterior_bi = rest,
               previsao_bi = if (m >= 12) acum else prever_srw(s, ano_alvo, m), stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, lapply(names(series), function(n) um(n, series[[n]])))
  soma <- out$previsao_bi[out$esfera == "estaduais"] + out$previsao_bi[out$esfera == "municipais"]
  reg <- out$previsao_bi[out$esfera == "regional"]
  out$dif_regional_vs_soma_bi <- NA_real_
  if (length(soma) == 1 && length(reg) == 1) out$dif_regional_vs_soma_bi[out$esfera == "regional"] <- reg - soma
  out
}

#' Intervalo do P1 regional no protocolo vigente (E4.2b, contrato de 28/10/2026): σ do erro do SRW em % do PIB (rolante, só anos < alvo,
#' suavizado e não crescente em m) × PIB do ano-alvo (premissa), previsão ± 1,2816 σ. `pib`: data.frame(ano, pib_bi) com o PIB do ano-alvo.
#' Devolve sigma, inf, sup (NA se faltar histórico ou PIB). Não é um intervalo de 80%: ver `texto_cobertura()`.
intervalo_p1_regional <- function(reg, pib, ano_alvo, m, previsao) {
  vazio <- list(sigma_bi = NA_real_, inf = NA_real_, sup = NA_real_, pib_bi = NA_real_)
  P <- pib$pib_bi[pib$ano == ano_alvo]
  if (m >= 12 || !length(P) || is.na(previsao)) return(vazio)
  bt <- backtest_p1(CANDIDATOS_P1["srw_brl"], list(bcb = reg, pib = pib[pib$ano < ano_alvo, c("ano", "pib_bi")]), 2000:(ano_alvo - 1L))
  bt$erro <- bt$erro / bt$pib
  s <- sigma_publicado(bt, ano_alvo)[m]
  if (is.na(s)) return(vazio)
  iv <- intervalo_80(previsao, s * P)
  list(sigma_bi = s * P, inf = iv$inf, sup = iv$sup, pib_bi = P)
}

#' Faixa de corte (1-4, 5-8, 9-11) do mês m; NA fora de 1..11.
faixa_corte <- function(m) ifelse(m %in% 1:4, "1-4", ifelse(m %in% 5:8, "5-8", ifelse(m %in% 9:11, "9-11", NA_character_)))

#' Texto de divulgação da faixa do corte, na linguagem do protocolo ("contém o resultado em X% dos anos-alvo"), nunca "intervalo de 80%".
#' `cob`: cobertura empírica (outputs/e42b_cobertura.csv), linhas do intervalo publicado; usa `texto_divulgacao()`.
texto_cobertura <- function(cob, m) {
  f <- faixa_corte(m)
  if (is.na(f)) return(NA_character_)
  d <- texto_divulgacao(cob)
  t <- d$texto[d$faixa == f]
  if (length(t) == 1) t else NA_character_
}

# ---- P2 realizado por categoria ---------------------------------------------------------------------------------------------

#' Soma dos 27 estados por categoria, ano e bimestre, a partir de `fluxos_a6_categorias()` (conceito original do Anexo 6, com RPPS),
#' com o mesmo bimestre do ano anterior e a variação. Linha só vale com as `n_ufs` UFs; senão `valor_bi` é NA (e n_ufs mostra quantas).
p2_categorias_bim <- function(fluxos, anos, n_ufs = 27L) {
  f <- fluxos[fluxos$exercicio %in% c(anos, anos - 1L), ]
  if (!nrow(f)) return(data.frame(exercicio = integer(0), periodo = integer(0), serie = character(0), valor_bi = numeric(0), n_ufs = integer(0),
                                  mesmo_bim_ano_ant_bi = numeric(0), var_pct = numeric(0)))
  n <- aggregate(cod_ibge ~ exercicio + periodo + serie, f, function(z) length(unique(z)))
  v <- aggregate(valor ~ exercicio + periodo + serie, f, sum)
  d <- merge(n, v, by = c("exercicio", "periodo", "serie")); names(d)[names(d) == "cod_ibge"] <- "n_ufs"
  d$valor_bi <- ifelse(d$n_ufs == n_ufs, d$valor / 1e9, NA_real_); d$valor <- NULL
  k <- match(paste(d$exercicio - 1L, d$periodo, d$serie), paste(d$exercicio, d$periodo, d$serie))
  d$mesmo_bim_ano_ant_bi <- d$valor_bi[k]
  d$var_pct <- ifelse(is.finite(d$mesmo_bim_ano_ant_bi) & d$mesmo_bim_ano_ant_bi != 0, 100 * (d$valor_bi / d$mesmo_bim_ano_ant_bi - 1), NA_real_)
  d <- d[d$exercicio %in% anos, ]
  d[order(d$exercicio, d$periodo, d$serie), c("exercicio", "periodo", "serie", "valor_bi", "n_ufs", "mesmo_bim_ano_ant_bi", "var_pct")]
}

# ---- Arquivo de previsões emitidas (E6.3) ----------------------------------------------------------------------------------------

ARQUIVO_COLUNAS <- c("data_rodada", "modelo", "esfera", "ano_alvo", "corte_m", "ultimo_dado", "vintage_bcb", "pib_ano_alvo_bi",
                     "previsao_bi", "intervalo_inf_bi", "intervalo_sup_bi", "oficial", "commit", "status_rodada")

#' Acrescenta ao arquivo as linhas da rodada. Uma linha por rodada x modelo x esfera x ano-alvo. Idempotente: refazer a rodada do mesmo dia
#' substitui as linhas daquele dia (não duplica); rodadas de dias anteriores nunca são alteradas. Ordem estável. Retorna o arquivo atualizado.
arquivar_previsoes <- function(arquivo, novas) {
  stopifnot(all(ARQUIVO_COLUNAS %in% names(novas)))
  novas <- novas[, ARQUIVO_COLUNAS]
  ant <- if (file.exists(arquivo)) ler_csv(arquivo, colClasses = c(data_rodada = "character", vintage_bcb = "character", ultimo_dado = "character", commit = "character")) else novas[0, ]
  ant$data_rodada <- as.character(ant$data_rodada); novas$data_rodada <- as.character(novas$data_rodada)
  ant <- ant[!(ant$data_rodada %in% unique(novas$data_rodada)), ARQUIVO_COLUNAS]
  out <- rbind(ant, novas)
  out <- out[order(out$data_rodada, out$modelo, out$esfera, out$ano_alvo), ]
  dir.create(dirname(arquivo), showWarnings = FALSE, recursive = TRUE)
  gravar_csv(out, arquivo)
  invisible(out)
}

# ---- Resumo ---------------------------------------------------------------------------------------------------------------------

#' Resumo da rodada em texto (markdown). Abre com o status e a lista do que falhou. Sem carimbo de horário: duas rodadas no mesmo dia, sem
#' dado novo, geram o mesmo arquivo (o horário vai em arquivo à parte).
resumo_rodada <- function(data_rodada, st, etapas, p1 = NULL, iv = NULL, texto_cob = NA_character_, gap = NULL, alertas = NULL, p2_tot = NULL) {
  L <- c(sprintf("# Rodada mensal de %s", data_rodada), "", sprintf("**Status: %s**", st$status))
  if (length(st$problemas)) L <- c(L, "", "Itens a resolver:", paste0("- ", st$problemas))
  L <- c(L, "", "Etapas: ", paste0("- ", etapas$etapa, ": ", etapas$estado))
  if (!is.null(p1) && nrow(p1)) {
    r <- p1[p1$esfera == "regional", ]
    L <- c(L, "", sprintf("## P1 (SRW em R$), ano-alvo %d, corte m = %d (último dado do BCB: mês %d)", r$ano_alvo, r$corte_m, r$corte_m), "",
           paste0("- ", p1$esfera, ": ", sprintf("%.1f", p1$previsao_bi), " bi"))
    if (!is.null(iv) && is.finite(iv$inf)) L <- c(L, "", sprintf("Faixa do regional: [%.1f; %.1f] bi (σ = %.1f bi, PIB do ano %.0f bi). %s.", iv$inf, iv$sup, iv$sigma_bi, iv$pib_bi, texto_cob))
    else L <- c(L, "", "Faixa do regional: indisponível nesta rodada.")
    dif <- r$dif_regional_vs_soma_bi
    if (is.finite(dif)) L <- c(L, sprintf("Linearidade: SRW regional − (estaduais + municipais) = %.3f bi.", dif))
  }
  if (!is.null(gap) && nrow(gap)) {
    g <- utils::tail(gap, 4)
    L <- c(L, "", "## Gap P1 x P2 (estados, últimos bimestres)", "",
           sprintf("- %d b%d: P2 %.1f | P1 %.1f | gap %.1f bi (%.1f%% da receita) | classe %s", g$exercicio, g$periodo, g$p2, g$p1, g$g, 100 * g$r, g$classe_informe))
  }
  if (!is.null(p2_tot) && nrow(p2_tot)) L <- c(L, "", "## P2 realizado, resultado primário (R$ bi, com RPPS; sem RPPS = referência da LDO, 2023+)", "",
           sprintf("- %d b%d: com RPPS %.1f | sem RPPS (LDO) %s", p2_tot$exercicio, p2_tot$periodo, p2_tot$p2_com, ifelse(is.na(p2_tot$p2_sem), "n.d.", sprintf("%.1f", p2_tot$p2_sem))))
  if (!is.null(alertas)) L <- c(L, "", sprintf("## Alertas novos dos exercícios t e t−1: %d na lista da aba (> 5%% da receita da UF); %d demais, contados por tipo.", alertas$lista, alertas$contagem))
  paste0(paste(L, collapse = "\n"), "\n")
}
