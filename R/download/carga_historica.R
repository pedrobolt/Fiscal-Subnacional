# Carga histórica do RREO por faixas (E2.4b). Ordem aprovada em 24/10/2026:
#   0) estados (extrato + retificações; já têm 2015–2026)
#   1) municípios: 6º bimestre de todos os anos (mais recente primeiro)
#   2) municípios: bimestres 1–5 de 2023 em diante (2026 b1–b4, 2025, 2024, 2023)
# Pendência condicionada (não executada): bimestres 1–5 de 2015–2022, só se o bottom-up mostrar potencial no E4.
# Sempre 2 processos (fatia 1 e 2, as 2 conexões autorizadas); retomável: rodar de novo continua de onde parou.

faixas_carga <- function() {
  list(
    list(nome = "0-estados", esfera = "E", anos = 2026:2015, periodos = 1:6),
    list(nome = "1-municipios-6o-bimestre", esfera = "M", anos = 2025:2015, periodos = 6),
    list(nome = "2-municipios-b1-a-b5-de-2023", esfera = "M", anos = 2026:2023, periodos = 1:5)
  )
}

#' Ids da esfera a partir do cadastro de entes. Municípios excluem o DF (5300108), tratado como estado.
ids_da_esfera <- function(entes, esfera) {
  if (esfera == "E") return(listar_estados(entes)$cod_ibge)
  sort(setdiff(entes$cod_ibge[entes$esfera == "M"], 5300108))
}

#' Impede duas execuções da mesma fatia: o trabalhador atualiza `lockfile` a cada ente x ano.
trava_ocupada <- function(lockfile, tolerancia_s = 120) {
  file.exists(lockfile) && as.numeric(difftime(Sys.time(), file.mtime(lockfile), units = "secs")) < tolerancia_s
}

executar_carga <- function(fatia, de = 2, pasta = "data/raw/rreo", faixas = faixas_carga(), hoje = Sys.Date()) {
  if (de != 2) stop("A carga usa exatamente 2 processos (2 conexões); não aumentar sem autorização do Pedro.", call. = FALSE)
  lock <- file.path(pasta, sprintf("_carga_fatia%d.lock", fatia))
  if (trava_ocupada(lock)) stop("A fatia ", fatia, " parece já estar em execução (", lock, " atualizado há menos de 2 min).", call. = FALSE)
  on.exit(unlink(lock))
  entes <- ler_entes(baixar_entes(pasta, hoje))
  batimento <- function(id, ano) writeLines(format(Sys.time()), lock)
  for (f in faixas) {
    ids <- ids_da_esfera(entes, f$esfera)
    for (ano in f$anos) {
      r <- atualizar_rreo(ids, ano, f$periodos, f$esfera, pasta, fatia, de, tag = paste0("_carga", fatia), hoje = hoje, ao_avancar = batimento)
      cat(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), f$nome, "ano", ano, "fatia", fatia, "| novos:", r$jobs[1],
          "retificados:", r$jobs[2], "vazios com entrega:", r$jobs[3], "| falhas:", attr(r, "falhas"), "\n")
    }
  }
  invisible(TRUE)
}

#' Progresso: por faixa, ente x ano com extrato baixado, jobs pendentes (com os extratos locais) e
#' estimativa de chamadas restantes e do tempo, a partir do ritmo observado na última hora nos logs de carga.
progresso_carga <- function(pasta = "data/raw/rreo", faixas = faixas_carga(), hoje = Sys.Date()) {
  entes <- ler_entes(baixar_entes(pasta, hoje))
  linhas <- list()
  for (f in faixas) {
    ids <- ids_da_esfera(entes, f$esfera)
    for (ano in f$anos) {
      tem <- 0; pend <- 0
      for (id in ids) {
        v <- extrato_vigente(pasta, id, ano)
        if (nrow(v) == 0) next
        tem <- tem + 1
        e <- ler_extrato(v$arquivo)
        e <- e[e$periodo %in% f$periodos & vapply(e$periodo, function(b) bimestre_disponivel(ano, b, hoje), logical(1)), ]
        pend <- pend + nrow(planejar_jobs(e, pasta, f$esfera, periodos = f$periodos))
      }
      nper <- sum(vapply(f$periodos, function(b) bimestre_disponivel(ano, b, hoje), logical(1)))
      linhas[[length(linhas) + 1]] <- data.frame(faixa = f$nome, ano = ano, entes = length(ids), com_extrato = tem,
                                                 jobs_pendentes = pend, jobs_por_ente_ano_sem_extrato = 1 + 2 * nper)
    }
  }
  p <- do.call(rbind, linhas)
  logs <- list.files(pasta, pattern = "^_log_.*_carga[0-9]\\.csv$", full.names = TRUE)
  mom <- as.POSIXct(unlist(lapply(logs, function(l) momento_log_numerico(utils::read.csv(l, colClasses = "character")$momento))), origin = "1970-01-01", tz = "UTC")
  taxa <- if (length(mom)) sum(mom > Sys.time() - 3600) / 3600 else NA_real_
  # Ente x ano sem extrato ainda custa 1 chamada de extrato + 2 anexos x bimestres da faixa
  p$chamadas_restantes <- p$jobs_pendentes + (p$entes - p$com_extrato) * p$jobs_por_ente_ano_sem_extrato
  attr(p, "resumo") <- list(chamadas_restantes = sum(p$chamadas_restantes), chamadas_por_s_ultima_hora = taxa,
                            horas_restantes = if (is.finite(taxa) && taxa > 0) sum(p$chamadas_restantes) / taxa / 3600 else NA_real_)
  p
}
