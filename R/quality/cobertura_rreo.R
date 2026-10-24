# Cobertura do download do RREO (E2.1/E2.4): quantos entes têm dados por ano x bimestre x anexo.
# Ausência é ausência: nunca vira zero. Reconhece os dois tipos (RREO e RREO Simplificado) e a versão vigente.
#   com_dados    : alguma versão vigente (em qualquer tipo) com linhas
#   vazios       : há arquivo vigente, mas todos vazios
#   nao_tentado  : Anexo 6 sem arquivo porque o Anexo 1 do mesmo ente x bimestre está vazio ou ausente
#   sem_arquivo  : sem arquivo e deveria ter (Anexo 1, ou Anexo 6 com Anexo 1 com dados)

estado_demonstrativo <- function(pasta, esfera, id, ano, periodo, anexo) {
  n <- vapply(TIPOS_RREO, function(t) linhas_rreo(vigente_rreo(pasta, esfera, id, ano, periodo, anexo, t)), integer(1))
  if (any(n > 0, na.rm = TRUE)) "com_dados" else if (any(!is.na(n))) "vazio" else "ausente"
}

cobertura_rreo <- function(ids, anos, periodos = 1:6, anexos = ANEXOS_RREO, esfera = "E", pasta = "data/raw/rreo",
                           hoje = Sys.Date()) {
  g <- expand.grid(ano = anos, periodo = periodos, anexo = unname(anexos), stringsAsFactors = FALSE)
  g <- g[mapply(bimestre_disponivel, g$ano, g$periodo, MoreArgs = list(hoje = hoje)), ]  # só bimestres já publicados
  a1 <- ANEXOS_RREO[["anexo01"]]
  contagem <- function(i) {
    est <- vapply(ids, function(id) {
      e <- estado_demonstrativo(pasta, esfera, id, g$ano[i], g$periodo[i], g$anexo[i])
      if (e == "ausente" && g$anexo[i] != a1 &&
          estado_demonstrativo(pasta, esfera, id, g$ano[i], g$periodo[i], a1) != "com_dados") "nao_tentado" else e
    }, character(1))
    c(esperados = length(ids), com_dados = sum(est == "com_dados"), vazios = sum(est == "vazio"),
      nao_tentado = sum(est == "nao_tentado"), sem_arquivo = sum(est == "ausente"))
  }
  cbind(g, t(vapply(seq_len(nrow(g)), contagem, numeric(5))))
}
