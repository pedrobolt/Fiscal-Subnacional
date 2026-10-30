library(testthat)
source_utf8("../R/transform/dicionario_contas.R")

CONTAS <- ler_dicionario("../data/dicionario_contas_estados.csv")
COLUNAS <- ler_dicionario("../data/dicionario_colunas_estados.csv")

test_that("layout por exercício: 2015-17, 2018-22, 2023+", {
  expect_equal(as.character(layout_rreo(c(2015, 2017, 2018, 2022, 2023, 2026))),
               c("2015-17", "2015-17", "2018-22", "2018-22", "2023+", "2023+"))
})

test_that("classificar_coluna reconhece o estágio apesar de caixa, acento e espaço diferentes", {
  c1 <- classificar_coluna(c("DESPESAS  PAGAS (a)", "DESPESAS PAGAS (a)", "Despesas Pagas Até o Bimestre (j)"), 2020)
  expect_equal(c1$estagio, rep("paga", 3))
  expect_equal(classificar_coluna(c("RESTOS A PAGAR PROCESSADOS PAGOS (b)", "LIQUIDADOS", "PAGOS (c)"), 2024)$estagio,
               c("rp_processado_pago", "rpnp_liquidado", "rpnp_pago"))
  expect_equal(classificar_coluna("RECEITAS REALIZADAS (a)", 2024)$estagio, "receita_realizada")
  # No layout 2015-17 o ano do rótulo separa o exercício corrente do anterior
  k <- classificar_coluna(c("Até o Bimestre / 2016", "Até o Bimestre / 2015"), 2016)
  expect_equal(k$ano_rel, c("corrente", "anterior")); expect_equal(k$estagio, rep("receita_realizada", 2))
  expect_equal(classificar_coluna("Despesas Liquidadas Até o Bimestre/2016", 2016)$estagio, "liquidada")
  expect_equal(classificar_coluna(c("PREVISÃO ATUALIZADA", "DOTAÇÃO ATUALIZADA", "VALOR"), 2023)$estagio, c("previsao", "dotacao", "valor"))
})

test_that("texto acentuado nas colunas e nas contas não depende do locale", {
  expect_equal(normalizar_rotulo("Até o Bimestre — DOTAÇÃO"), "ate o bimestre dotacao")
  expect_equal(normalizar_rotulo("DESPESAS  LIQUIDADAS"), normalizar_rotulo("Despesas Liquidadas"))
})

test_that("acumulado -> fluxo: bimestre 1 é o acumulado; demais, a diferença; anterior ausente vira NA (nunca zero)", {
  x <- data.frame(cod_ibge = 1, cod_conta = "c", estagio = "paga", exercicio = 2024, periodo = c(1, 2, 3, 5, 6), valor = c(10, 25, 45, 100, 130))
  r <- acumulado_para_fluxo(x)
  expect_equal(r$fluxo, c(10, 15, 20, NA, 30))
  expect_equal(r$acum_anterior_ausente, c(FALSE, FALSE, FALSE, TRUE, FALSE))
})

test_that("acumulado -> fluxo não mistura entes, contas, estágios nem anos", {
  x <- rbind(
    data.frame(cod_ibge = 1, cod_conta = "c", estagio = "paga", exercicio = 2024, periodo = 1:2, valor = c(10, 30)),
    data.frame(cod_ibge = 2, cod_conta = "c", estagio = "paga", exercicio = 2024, periodo = 1:2, valor = c(100, 150)),
    data.frame(cod_ibge = 1, cod_conta = "d", estagio = "paga", exercicio = 2024, periodo = 1:2, valor = c(1, 4)),
    data.frame(cod_ibge = 1, cod_conta = "c", estagio = "paga", exercicio = 2025, periodo = 1:2, valor = c(7, 8)))
  expect_equal(acumulado_para_fluxo(x)$fluxo, c(10, 20, 100, 50, 1, 3, 7, 1))
})

test_that("dicionário de contas: chave única e campos preenchidos", {
  expect_false(any(duplicated(CONTAS[, c("anexo", "layout", "cod_conta")])))
  expect_true(all(CONTAS$layout %in% LAYOUTS_RREO))
  expect_false(any(CONTAS$papel == "memo_nao_curado"))
  expect_true(all(CONTAS$nivel %in% c("folha", "subtotal", "total", "detalhe", "memo")))
})

test_that("dicionário: só folhas somam, e nenhuma folha tem ancestral folha (pai e filhos nunca somados juntos)", {
  a6 <- CONTAS[CONTAS$anexo == "RREO-Anexo 06", ]
  folhas <- a6[a6$usar_no_p2 == "soma", ]
  expect_true(all(folhas$nivel == "folha"))
  expect_true(all(a6$usar_no_p2[a6$nivel != "folha"] != "soma"))
  for (l in LAYOUTS_RREO) {
    d <- a6[a6$layout == l, ]; pai <- stats::setNames(d$pai, d$cod_conta); fl <- d$cod_conta[d$usar_no_p2 == "soma"]
    for (f in fl) { anc <- character(0); p <- pai[f]
      while (!is.na(p) && !(p %in% anc)) { anc <- c(anc, p); p <- unname(pai[p]) }
      expect_false(any(anc %in% fl), info = paste(l, f)) }
  }
})

test_that("dicionário: toda folha tem categoria do E5.1, natureza e estágio; e as categorias-chave existem em cada layout", {
  a6 <- CONTAS[CONTAS$anexo == "RREO-Anexo 06" & CONTAS$usar_no_p2 == "soma", ]
  cats <- c("ICMS", "IPVA", "ISS", "FPE/FPM", "demais receitas", "pessoal", "custeio", "investimento")
  permitidas <- c(cats, "receita FUNDEB", "demais despesas de capital", "demais despesas")
  expect_true(all(a6$categoria_p2 %in% permitidas)); expect_true(all(a6$natureza %in% c("corrente", "capital")))
  expect_false(any(is.na(a6$estagio_p2)) && any(a6$layout != "2015-17" & is.na(a6$estagio_p2)))
  for (l in LAYOUTS_RREO) expect_true(all(cats %in% a6$categoria_p2[a6$layout == l]), info = l)
  desp <- c("pessoal", "custeio", "investimento", "demais despesas de capital", "demais despesas")
  expect_true(all(a6$estagio_p2[a6$categoria_p2 %in% desp & a6$layout != "2015-17"] == "paga+rp_processado_pago+rpnp_pago"))
  expect_true(all(a6$estagio_p2[a6$categoria_p2 %in% desp & a6$layout == "2015-17"] == "sem_caixa(liquidada)"))
})

test_that("RPPS (decisão de 30/10/2026): 4 contas primárias 'com fontes RPPS' entram; 'exceto fontes RPPS' é só referência da LDO", {
  # as contas só-RPPS que não são primárias seguem fora do P2
  expect_true(all(CONTAS$usar_no_p2[CONTAS$rpps == "excluido"] == "nao"))
  entram <- c("ReceitasPrimariasCorrentesComFontesRPPS", "ReceitasPrimariasDeCapitalComFontesRPPS",
              "DespesasPrimariasCorrentesComFontesRPPS", "DespesasPrimariasDeCapitalComFontesRPPS")
  e <- CONTAS[CONTAS$layout == "2023+" & CONTAS$cod_conta %in% entram, ]
  expect_equal(nrow(e), 4L); expect_true(all(e$usar_no_p2 == "soma" & e$rpps == "incluido"))
  expect_true(all(e$categoria_p2[grepl("^Receitas", e$cod_conta)] == "demais receitas"))
  expect_true(all(e$categoria_p2[grepl("^Despesas", e$cod_conta)] == "pessoal"))
  ref <- CONTAS[CONTAS$layout == "2023+" & CONTAS$cod_conta %in% c("ReceitaPrimariaTotalExcetoFontesRPPS", "DespesaPrimariaTotalExcetoFontesRPPS", "ResultadoPrimarioSemRPPSAcimaDaLinha"), ]
  expect_true(all(ref$rpps == "referencia_ldo" & ref$usar_no_p2 == "referencia_ldo"))
  # totais de conferência do P2 em 2023+: XVI e XXXIV (com RPPS)
  expect_true(all(CONTAS$usar_no_p2[CONTAS$layout == "2023+" & CONTAS$cod_conta %in% c("RREO6TotalReceitaPrimaria", "ResultadoPrimarioComRPPSAcimaDaLinha")] == "conferencia"))
  # em 2015–22 o RPPS está dentro das contas e não há como separá-lo (quebra declarada)
  expect_true(all(CONTAS$rpps[CONTAS$cod_conta == "RREO6TotalReceitaPrimaria" & CONTAS$layout != "2023+"] == "incluido_nao_separavel"))
})

test_that("Anexo 1 é só referência: nada nele entra no P2", {
  expect_true(all(CONTAS$usar_no_p2[CONTAS$anexo == "RREO-Anexo 01"] == "nao"))
})

test_that("caixa da despesa existe só nos layouts de 2018 em diante", {
  expect_false(any(COLUNAS$papel[COLUNAS$layout == "2015-17"] == "despesa_caixa_p2"))
  expect_true(all(c("paga", "rp_processado_pago", "rpnp_pago") %in% COLUNAS$estagio[COLUNAS$papel == "despesa_caixa_p2" & COLUNAS$layout == "2023+"]))
  expect_equal(sort(ESTAGIOS_CAIXA_DESPESA), sort(c("paga", "rp_processado_pago", "rpnp_pago")))
})

linha <- function(layout_ano, cod, coluna, valor, periodo = 6, ente = 11, anexo = "RREO-Anexo 06")
  data.frame(anexo = anexo, exercicio = layout_ano, periodo = periodo, cod_ibge = ente, cod_conta = cod, conta = cod, coluna = coluna, valor = valor, stringsAsFactors = FALSE)

test_that("fechar_anexo6: caixa = paga + RP processados pagos + RPNP pagos reproduz o resultado publicado (2023+, com RPPS)", {
  r <- rbind(
    linha(2024, "RREO6ICMS", "RECEITAS REALIZADAS (a)", 600), linha(2024, "RREO6IPVA", "RECEITAS REALIZADAS (a)", 100),
    linha(2024, "RREO6FPE", "RECEITAS REALIZADAS (a)", 300),
    linha(2024, "ReceitasPrimariasCorrentesComFontesRPPS", "RECEITAS REALIZADAS (a)", 77),            # RPPS: entra (decisão de 30/10/2026)
    linha(2024, "RREO6TotalReceitaPrimaria", "RECEITAS REALIZADAS (a)", 1077),
    linha(2024, "ReceitaPrimariaTotalExcetoFontesRPPS", "RECEITAS REALIZADAS (a)", 1000),             # referência da LDO: não confere
    linha(2024, "RREO6PessoalEEncargosSociais", "DESPESAS PAGAS (a)", 400), linha(2024, "RREO6PessoalEEncargosSociais", "RESTOS A PAGAR PROCESSADOS PAGOS (b)", 30),
    linha(2024, "RREO6PessoalEEncargosSociais", "PAGOS (c)", 5), linha(2024, "RREO6PessoalEEncargosSociais", "DESPESAS EMPENHADAS", 999),
    linha(2024, "RREO6Investimentos", "DESPESAS PAGAS (a)", 100), linha(2024, "RREO6Investimentos", "PAGOS (c)", 20),
    linha(2024, "DespesasPrimariasCorrentesComFontesRPPS", "DESPESAS PAGAS (a)", 50),               # RPPS: entra, em pessoal
    linha(2024, "RREO6TotalDespesaPrimaria", "DESPESAS PAGAS (a)", 550), linha(2024, "RREO6TotalDespesaPrimaria", "RESTOS A PAGAR PROCESSADOS PAGOS (b)", 30),
    linha(2024, "RREO6TotalDespesaPrimaria", "PAGOS (c)", 25),
    linha(2024, "DespesaPrimariaTotalExcetoFontesRPPS", "DESPESAS PAGAS (a)", 500),                  # referência da LDO: não confere
    linha(2024, "ResultadoPrimarioComRPPSAcimaDaLinha", "VALOR", 1077 - 605))
  f <- fechar_anexo6(r, CONTAS, COLUNAS)
  expect_equal(nrow(f), 1); expect_true(f$rec_ok && f$desp_ok && f$resultado_ok)
  expect_equal(f$desp_folhas, 605); expect_equal(f$rec_folhas, 1077)
})

test_that("fechar_anexo6 acusa quando a conta não fecha (resultado publicado diferente)", {
  r <- rbind(linha(2024, "RREO6ICMS", "RECEITAS REALIZADAS (a)", 100), linha(2024, "RREO6TotalReceitaPrimaria", "RECEITAS REALIZADAS (a)", 100),
             linha(2024, "RREO6PessoalEEncargosSociais", "DESPESAS PAGAS (a)", 40), linha(2024, "RREO6TotalDespesaPrimaria", "DESPESAS PAGAS (a)", 41),
             linha(2024, "ResultadoPrimarioComRPPSAcimaDaLinha", "VALOR", 60))
  f <- fechar_anexo6(r, CONTAS, COLUNAS, tol = 0.5)
  expect_true(f$rec_ok); expect_false(f$desp_ok)
})

test_that("fechar_anexo6 em 2015-17 usa a liquidação do exercício corrente (não o ano anterior)", {
  r <- rbind(linha(2016, "RREO6ICMS", "Até o Bimestre / 2016", 100), linha(2016, "RREO6ICMS", "Até o Bimestre / 2015", 999),
             linha(2016, "RREO6TotalReceitaPrimaria", "Até o Bimestre / 2016", 100),
             linha(2016, "RREO6PessoalEEncargosSociais", "Despesas Liquidadas Até o Bimestre / 2016", 30), linha(2016, "RREO6PessoalEEncargosSociais", "DESPESAS LIQUIDADAS ATÉ O BIMESTRE / 2015", 888),
             linha(2016, "RREO6TotalDespesaPrimaria", "Despesas Liquidadas Até o Bimestre / 2016", 30),
             linha(2016, "RREO6ResultadoPrimarioEstadosMunicipios", "Despesas Liquidadas Até o Bimestre / 2016", 70))
  f <- fechar_anexo6(r, CONTAS, COLUNAS)
  expect_equal(f$rec_folhas, 100); expect_equal(f$desp_folhas, 30); expect_true(f$resultado_ok)
})

test_that("cobertura_dicionario lista conta e coluna nunca vistas", {
  r <- rbind(linha(2024, "RREO6ICMS", "RECEITAS REALIZADAS (a)", 1), linha(2024, "ContaNova", "COLUNA NOVA", 1))
  cob <- cobertura_dicionario(r, CONTAS, COLUNAS)
  expect_equal(cob$contas$cod_conta, "ContaNova"); expect_equal(cob$colunas$padrao, "COLUNA NOVA")
})

test_that("FUNDEB: receita própria; dedução só no Anexo 3, como conta acompanhada fora da soma do P2", {
  f <- CONTAS[CONTAS$cod_conta == "TransferenciasDoFUNDEB" & CONTAS$anexo == "RREO-Anexo 06", ]
  expect_true(all(f$categoria_p2 == "receita FUNDEB"))
  d <- CONTAS[CONTAS$cod_conta == "DeducaoDeReceitaParaFormacaoDoFUNDEB", ]
  expect_true(nrow(d) >= 1); expect_true(all(d$categoria_p2 == "FUNDEB_deducao")); expect_true(all(d$usar_no_p2 == "nao"))
  expect_true(all(d$anexo == "RREO-Anexo 03")); expect_true(all(d$papel == "rcl_acompanhada"))
  expect_false(any(CONTAS$usar_no_p2[CONTAS$anexo == "RREO-Anexo 03"] == "soma"))
})

test_that("inversões financeiras e reserva de contingência têm categoria própria, fora de investimento e custeio", {
  expect_true(all(CONTAS$categoria_p2[CONTAS$cod_conta == "RREO6DemaisInversoesFinanceiras"] == "demais despesas de capital"))
  expect_true(all(CONTAS$categoria_p2[CONTAS$cod_conta == "RREO6ReservaDeContingencia"] == "demais despesas"))
  expect_true(all(CONTAS$categoria_p2[CONTAS$cod_conta == "RREO6Investimentos"] == "investimento"))
})

test_that("sinalizar_reserva_paga acusa só reserva com valor pago", {
  r <- rbind(linha(2024, "RREO6ReservaDeContingencia", "DOTAÇÃO ATUALIZADA", 500), linha(2024, "RREO6ReservaDeContingencia", "DESPESAS PAGAS (a)", 0),
             linha(2024, "RREO6ReservaDeContingencia", "PAGOS (c)", 12, ente = 12), linha(2024, "RREO6Investimentos", "DESPESAS PAGAS (a)", 99))
  s <- sinalizar_reserva_paga(r)
  expect_equal(nrow(s), 1); expect_equal(s$cod_ibge, 12)
})
