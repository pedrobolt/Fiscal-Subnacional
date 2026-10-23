# Cobertura do download do RREO (E2.1): quantos entes têm dados por ano x bimestre x anexo.
# Ausência é ausência: arquivo inexistente ou vazio conta como "sem dados", nunca como zero.

cobertura_rreo <- function(ids, anos, periodos = 1:6, anexos = ANEXOS_RREO, esfera = "E", pasta = "data/raw/rreo",
                           hoje = Sys.Date()) {
  g <- expand.grid(ano = anos, periodo = periodos, anexo = unname(anexos), stringsAsFactors = FALSE)
  g <- g[mapply(bimestre_disponivel, g$ano, g$periodo, MoreArgs = list(hoje = hoje)), ]  # só bimestres já publicados
  contagem <- function(i) {
    n <- vapply(ids, function(id) linhas_rreo(caminho_rreo(pasta, esfera, id, g$ano[i], g$periodo[i], g$anexo[i])), integer(1))
    c(esperados = length(ids), com_dados = sum(n > 0, na.rm = TRUE), vazios = sum(n == 0, na.rm = TRUE), sem_arquivo = sum(is.na(n)))
  }
  cbind(g, t(vapply(seq_len(nrow(g)), contagem, numeric(4))))
}
