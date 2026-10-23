# Verificações de consistência das séries do SGS (E1.6).

#' Confere que estaduais + municipais = regionais (mesmo conceito do BCB), mês a mês.
#' Tolerância em R$ milhões: as séries têm 2 casas decimais, então 0,05 cobre arredondamento.
#' Falha (stop) se as datas diferirem ou se alguma diferença passar da tolerância.
checar_soma_regional <- function(estaduais, municipais, regionais, tolerancia = 0.05) {
  # 4642 começa antes (1991) de 4643/4644 (1998): compara só as datas em comum,
  # mas 4643 e 4644 precisam ter exatamente as mesmas datas e estar contidas em 4642.
  if (!identical(estaduais$data, municipais$data) || !all(estaduais$data %in% regionais$data)) {
    stop("Séries SGS 4643, 4644 e 4642 com datas diferentes.", call. = FALSE)
  }
  reg <- regionais[match(estaduais$data, regionais$data), ]
  dif <- estaduais$valor + municipais$valor - reg$valor
  if (any(abs(dif) > tolerancia)) {
    ruins <- reg$data[abs(dif) > tolerancia]
    stop("Estaduais + municipais diferem de regionais (tolerância ", tolerancia, ") em: ",
         paste(format(ruins), collapse = ", "), call. = FALSE)
  }
  invisible(max(abs(dif)))
}
