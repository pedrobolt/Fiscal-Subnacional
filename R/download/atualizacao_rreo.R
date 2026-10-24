# Atualização incremental do RREO guiada pelo extrato_entregas (E2.4).
# Para cada ente x ano: lê o extrato (renovado se estiver velho), compara `data_status` com a data da
# versão local e baixa só o que falta ou mudou. Retificação = snapshot novo; nada é sobrescrito.

#' Jobs de download de um ente x ano a partir das entregas do extrato (RREO apenas).
#' motivo: "novo" (sem arquivo local), "retificado" (entrega posterior à versão local) ou
#' "vazio_com_entrega" (arquivo local vazio e entrega posterior a ele: entrega atrasada).
#' Arquivo vazio com entrega anterior à consulta não é refeito (o Anexo simplesmente não existe).
planejar_jobs <- function(entregas, pasta, esfera, anexos = ANEXOS_RREO, periodos = 1:6) {
  jobs <- list()
  momentos <- momentos_originais(pasta)
  entregas <- entregas[entregas$periodo %in% periodos, ]
  for (k in seq_len(nrow(entregas))) {
    e <- entregas[k, ]
    for (anx in anexos) {
      base <- caminho_rreo(pasta, esfera, e$cod_ibge, e$exercicio, e$periodo, anx, e$tipo)
      vig <- arquivo_vigente(base)
      motivo <- NA_character_
      if (is.na(vig)) {
        motivo <- "novo"
      } else if (!is.na(e$data_status) && e$data_status > baixado_em_vigente(base, momentos)) {
        motivo <- if (isTRUE(linhas_rreo(vig) == 0)) "vazio_com_entrega" else "retificado"
      }
      if (!is.na(motivo)) {
        jobs[[length(jobs) + 1]] <- data.frame(cod_ibge = e$cod_ibge, ano = e$exercicio, periodo = e$periodo,
                                               anexo = anx, tipo = e$tipo, motivo = motivo, stringsAsFactors = FALSE)
      }
    }
  }
  if (length(jobs) == 0) return(data.frame(cod_ibge = integer(0), ano = integer(0), periodo = integer(0),
                                           anexo = character(0), tipo = character(0), motivo = character(0)))
  do.call(rbind, jobs)
}

#' Extrato do ente x ano: reaproveita o mais recente se tiver até `idade_max_dias`; senão baixa de novo.
extrato_atualizado <- function(pasta, id_ente, ano, idade_max_dias = 7, agora = Sys.time(), log = "_log_extrato.csv") {
  v <- extrato_vigente(pasta, id_ente, ano)
  if (nrow(v) == 1 && as.numeric(difftime(agora, v$baixado_em, units = "days")) <= idade_max_dias) return(v$arquivo)
  baixar_extrato(id_ente, ano, pasta, log = log)
}

#' Atualiza o RREO de `ids` (esfera "E" ou "M") nos `anos` e `periodos` dados, nessa ordem de anos.
#' Retorna data.frame com a contagem de jobs por motivo. `fatia`/`de` repartem os entes entre processos.
atualizar_rreo <- function(ids, anos, periodos = 1:6, esfera = "M", pasta = "data/raw/rreo", fatia = 1, de = 1,
                           idade_max_extrato_dias = 7, tag = "", hoje = Sys.Date(), ao_avancar = NULL) {
  ids <- ids[(seq_along(ids) - 1) %% de == fatia - 1]
  log <- sprintf("_log_%s%s.csv", esfera, tag)
  contagem <- character(0)
  falhas <- 0
  for (ano in anos) for (id in ids) {
    if (!is.null(ao_avancar)) ao_avancar(id, ano)
    # Uma falha de rede num ente x ano não derruba a rodada: fica registrada e a próxima rodada tenta de novo.
    res <- tryCatch({
      ext <- ler_extrato(extrato_atualizado(pasta, id, ano, idade_max_extrato_dias, log = sprintf("_log_extrato%s.csv", tag)))
      ext <- ext[ext$periodo %in% periodos & vapply(ext$periodo, function(b) bimestre_disponivel(ano, b, hoje), logical(1)), ]
      jobs <- planejar_jobs(ext, pasta, esfera, periodos = periodos)
      for (j in seq_len(nrow(jobs))) {
        with(jobs[j, ], baixar_rreo(cod_ibge, ano, periodo, anexo, esfera = esfera, pasta = pasta, tipo = tipo,
                                    log = log, hoje = hoje, snapshot = motivo != "novo"))
      }
      jobs$motivo
    }, error = function(e) {
      falhas <<- falhas + 1
      registrar_chamada(pasta, data.frame(momento = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), id_ente = id, ano = ano,
                                          erro = substr(conditionMessage(e), 1, 200)), sprintf("_erros%s.csv", tag))
      character(0)
    })
    contagem <- c(contagem, res)
  }
  out <- as.data.frame(table(motivo = factor(contagem, levels = c("novo", "retificado", "vazio_com_entrega"))), responseName = "jobs")
  attr(out, "falhas") <- falhas
  out
}
