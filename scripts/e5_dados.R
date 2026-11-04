# E5 estados: monta os insumos (painel, base dos modelos, A6 totais) a partir do cache do RREO e dos fluxos harmonizados. Funcao `e5_montar()`.
# Uso (de outro script): carregar_r("scripts/e5_dados.R"); D <- e5_montar()
source("R/utils_io.R", encoding = "UTF-8")
carregar_r(c("R/download/snapshots.R", "R/download/bcb_sgs.R", "R/download/siconfi_rreo.R", "R/transform/rreo.R", "R/transform/dicionario_contas.R",
             "R/quality/alertas.R", "R/transform/intra.R", "R/models/e5.R"))
e5_montar <- function() {
  dic <- ler_dicionario("data/dicionario_contas_estados.csv"); dc <- ler_dicionario("data/dicionario_colunas_estados.csv")
  rreo <- readRDS(dados("outputs/cache_rreo.rds")); fl <- readRDS(dados("outputs/cache_fluxos_com.rds"))
  intra <- fluxo_intra(rreo); fh <- harmonizar_fluxos(fl, intra); checar_identidade_intra(fh[fh$exercicio %in% 2023:2025, ], fl[fl$exercicio %in% 2023:2025, ], intra)
  f_ipca <- sort(list.files(dados("data/raw"), "^bcb_sgs_433_", full.names = TRUE), decreasing = TRUE)[1]
  ind <- e5_ipca_bim(ler_sgs(f_ipca))
  series <- c(E5_ALVOS, E5_DIAG)
  P <- e5_com_totais(fh[fh$exercicio <= 2025, ]); painel <- e5_marcar_alvos(e5_painel(P, ind, series))
  # despesa bruta (A6 como publicado) do ano anterior, em termos reais: denominador das pendencias
  Pb <- e5_com_totais(fl[fl$exercicio <= 2025, ]); pb <- e5_painel(Pb, ind, "desp:total")
  den <- data.frame(cod_ibge = pb$cod_ibge[pb$corte == 1], exercicio = pb$exercicio[pb$corte == 1] + 1L, Treal_bruta_ant = pb$Treal[pb$corte == 1])
  a6 <- e5_a6_totais(rreo, dic, dc)
  pend <- a6[a6$periodo %in% 1:5, ]
  pend <- data.frame(cod_ibge = pend$cod_ibge, exercicio = pend$exercicio, corte = pend$periodo, liq_menos_paga = pend$liquidada - pend$paga, emp_menos_liq = pend$empenhada - pend$liquidada)
  base <- e5_base_modelo(painel, ind, pend, den)
  co <- ler_csv(dados("outputs/conceito_unico_bimestral.csv"))
  uf_co <- unique(co[co$conceito_original %in% c(TRUE, "TRUE"), c("cod_ibge", "exercicio")])
  list(painel = painel, base = base, a6 = a6, ind = ind, uf_conceito_original = uf_co, fh = fh)
}
