# Pipeline do projeto. Rodar com: Rscript -e "targets::tar_make()"
library(targets)

# Carrega todas as funções de R/ (subpastas incluídas)
for (arquivo in list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE)) {
  source(arquivo)
}

ano_t <- 2026  # ano-alvo; em jan/fev de t+1 trocar para fechar o ano anterior

list(
  tar_target(ambiente, checar_ambiente()),

  # E1.5: fatia mínima. Primário regional do BCB (SGS 4642) -> naïve e acumulado -> backtest -> número de ano_t
  tar_target(arquivo_bcb,
             baixar_sgs(SGS_PRIMARIO[["regionais"]], as.Date("2005-01-01"), Sys.Date()),
             format = "file", cue = tar_cue(mode = "always")),
  tar_target(arquivo_bcb_estaduais,
             baixar_sgs(SGS_PRIMARIO[["estaduais"]], as.Date("2005-01-01"), Sys.Date()),
             format = "file", cue = tar_cue(mode = "always")),
  tar_target(arquivo_bcb_municipais,
             baixar_sgs(SGS_PRIMARIO[["municipais"]], as.Date("2005-01-01"), Sys.Date()),
             format = "file", cue = tar_cue(mode = "always")),
  # Estaduais + municipais = regionais (falha o pipeline se divergir)
  tar_target(consistencia_sgs,
             checar_soma_regional(ler_sgs(arquivo_bcb_estaduais), ler_sgs(arquivo_bcb_municipais), ler_sgs(arquivo_bcb))),
  tar_target(serie_regional, {consistencia_sgs; primario_bi(ler_sgs(arquivo_bcb))}),
  tar_target(premissas, ler_premissas("premissas.yml", ano_t = ano_t)),
  tar_target(backtest, rodar_backtest(serie_regional)),
  tar_target(resumo, resumir_erros(backtest)),
  tar_target(previsao, com_pct_pib(prever_ano_corrente(serie_regional, ano_t), premissas)),
  tar_target(saidas, gravar_saidas_fatia(backtest, resumo, previsao), format = "file")
)
