# Verificações de consistência das séries do SGS (E1.6).

#' Confere que estaduais + municipais = regionais (mesmo conceito do BCB), mês a mês.
#' Tolerância em R$ milhões: as séries têm 2 casas decimais, então 0,05 cobre arredondamento.
#' Falha (stop) se as datas diferirem ou se alguma diferença passar da tolerância.
checar_soma_regional <- function(estaduais, municipais, regionais, tolerancia = 0.05) {
  if (!identical(estaduais$data, regionais$data) || !identical(municipais$data, regionais$data)) {
    stop("Séries SGS 4643, 4644 e 4642 com datas diferentes.", call. = FALSE)
  }
  dif <- estaduais$valor + municipais$valor - regionais$valor
  if (any(abs(dif) > tolerancia)) {
    ruins <- regionais$data[abs(dif) > tolerancia]
    stop("Estaduais + municipais diferem de regionais (tolerância ", tolerancia, ") em: ",
         paste(format(ruins), collapse = ", "), call. = FALSE)
  }
  invisible(max(abs(dif)))
}
