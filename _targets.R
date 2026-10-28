# Pipeline do projeto. Rodar com: Rscript -e "targets::tar_make()"
library(targets)

# Carrega todas as funções de R/ (subpastas incluídas)
for (arquivo in list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE)) {
  source(arquivo, encoding = "UTF-8")
}

ano_t <- 2026  # ano-alvo; em jan/fev de t+1 trocar para fechar o ano anterior

list(
  tar_target(ambiente, checar_ambiente()),

  # E1.5: fatia mínima. Primário regional do BCB (SGS 4642) -> naïve e acumulado -> backtest -> número de ano_t
  tar_target(arquivo_bcb,
             baixar_sgs(SGS_PRIMARIO[["regionais"]], SGS_INICIO_DOWNLOAD, Sys.Date()),
             format = "file", cue = tar_cue(mode = "always")),
  tar_target(arquivo_bcb_estaduais,
             baixar_sgs(SGS_PRIMARIO[["estaduais"]], SGS_INICIO_DOWNLOAD, Sys.Date()),
             format = "file", cue = tar_cue(mode = "always")),
  tar_target(arquivo_bcb_municipais,
             baixar_sgs(SGS_PRIMARIO[["municipais"]], SGS_INICIO_DOWNLOAD, Sys.Date()),
             format = "file", cue = tar_cue(mode = "always")),
  # Estaduais + municipais = regionais (falha o pipeline se divergir)
  tar_target(consistencia_sgs,
             checar_soma_regional(ler_sgs(arquivo_bcb_estaduais), ler_sgs(arquivo_bcb_municipais), ler_sgs(arquivo_bcb))),
  tar_target(serie_regional, {consistencia_sgs; sgs <- ler_sgs(arquivo_bcb); primario_bi(sgs[sgs$data >= SGS_INICIO_ANALISE, ])}),
  tar_target(premissas, ler_premissas("premissas.yml", ano_t = ano_t)),
  tar_target(backtest, rodar_backtest(serie_regional)),
  tar_target(resumo, resumir_erros(backtest)),
  tar_target(previsao, com_pct_pib(prever_ano_corrente(serie_regional, ano_t), premissas)),
  tar_target(saidas, gravar_saidas_fatia(backtest, resumo, previsao), format = "file"),

  # E2.1: RREO dos estados. O download (horas) é feito fora do pipeline:
  #   Rscript -e 'source("_targets.R"); baixar_rreo_estados()'
  # Aqui só se lê o que já está em data/raw/rreo e se mede a cobertura.
  tar_target(ids_estados, ids_estados_local(), cue = tar_cue(mode = "always")),
  tar_target(rreo_estados, ler_rreo_pasta("data/raw/rreo", "E"), cue = tar_cue(mode = "always")),
  tar_target(cobertura_estados, cobertura_rreo(ids_estados, 2015:2026), cue = tar_cue(mode = "always"))
)
