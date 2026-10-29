# Dicionário de contas e colunas do RREO por layout (E2.5, estados). Mapeia o que o Siconfi publica ao que o P2 usa.
# Nada aqui soma ou reclassifica o bruto: o dicionário diz o que cada (layout, anexo, conta, coluna) é, e as funções
# abaixo aplicam essa leitura. As regras de leitura estão em `data/dicionario_*.csv` (versionados); o que foi
# confirmado contra os totais publicados está em `fechar_anexo6()`.
#
# Layouts (por exercício): "2015-17" (sem despesa paga, só empenho e liquidação), "2018-22" (despesa paga e restos a pagar
# pagos; RPPS dentro das contas) e "2023+" (fontes do RPPS separadas em contas próprias). A mudança vale para o arquivo
# inteiro, não por conta: verificado nos 27 estados em 2017/2018 e 2022/2023.

LAYOUTS_RREO <- c("2015-17", "2018-22", "2023+")

layout_rreo <- function(exercicio) {
  cut(exercicio, c(-Inf, 2017, 2022, Inf), labels = LAYOUTS_RREO, right = TRUE)
}

#' Texto sem acento, minúsculo e com espaços simples, para casar rótulos que mudam de caixa e espaçamento entre layouts.
normalizar_rotulo <- function(x) {
  # Sem iconv: a transliteração muda com o locale (em locale C vira "?"). O mapa explícito vale em qualquer sistema.
  com <- "\u00e1\u00e0\u00e2\u00e3\u00e4\u00e9\u00e8\u00ea\u00eb\u00ed\u00ec\u00ee\u00ef\u00f3\u00f2\u00f4\u00f5\u00f6\u00fa\u00f9\u00fb\u00fc\u00e7\u00c1\u00c0\u00c2\u00c3\u00c4\u00c9\u00c8\u00ca\u00cb\u00cd\u00cc\u00ce\u00cf\u00d3\u00d2\u00d4\u00d5\u00d6\u00da\u00d9\u00db\u00dc\u00c7"
  sem <- "aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC"
  x <- chartr(com, sem, enc2utf8(x))
  x <- gsub("[^A-Za-z0-9/()=%.-]+", " ", x)
  trimws(gsub(" +", " ", tolower(x)))
}

#' Estágio de uma coluna do RREO. O ano que aparece no rótulo vira "AAAA"; `ano_rel` diz se ele é o exercício ("corrente"),
#' o anterior ("anterior") ou não se aplica. Retorna data.frame(estagio, ano_rel).
classificar_coluna <- function(coluna, exercicio) {
  n <- normalizar_rotulo(coluna)
  ano <- suppressWarnings(as.integer(sub(".*((19|20)[0-9]{2}).*", "\\1", ifelse(grepl("(19|20)[0-9]{2}", n), n, NA))))
  ano_rel <- ifelse(is.na(ano) | is.na(exercicio), "nao_se_aplica",
                    ifelse(ano == exercicio, "corrente", ifelse(ano == exercicio - 1, "anterior", "outro")))
  # Em "Em 31/12/AAAA" o ano é o do saldo (RP), não uma comparação de exercícios
  est <- rep("outro", length(n))
  set <- function(padrao, valor) { k <- est == "outro" & grepl(padrao, n); est[k] <<- valor }
  set("^previsao (inicial|atualizada|orcamentaria)", "previsao")
  set("^mr(-[0-9]+)?$", "mes_mr")                      # Anexo 3 (RCL): 12 colunas mensais, MR = último mês do bimestre
  set("^total \\(ultimos 12 meses\\)", "total_12m")
  set("^dotacao (inicial|atualizada)", "dotacao")
  set("^receitas realizadas", "receita_realizada")
  set("^despesas empenhadas no bimestre", "empenhada_no_bimestre")
  set("^despesas liquidadas no bimestre", "liquidada_no_bimestre")
  set("^despesas empenhadas( ate o bimestre)?( ?/ ?[0-9]{4})?( \\([a-z]\\))?$", "empenhada")
  set("^despesas liquidadas( ate o bimestre)?( ?/ ?[0-9]{4})?( \\([a-z]\\))?$", "liquidada")
  set("^despesas pagas( ate o bimestre)?( \\([a-z]\\))?$", "paga")
  set("^restos a pagar processados pagos", "rp_processado_pago")
  set("^liquidados$", "rpnp_liquidado")
  set("^pagos \\(c\\)$", "rpnp_pago")
  set("^inscritas em (rpnp|restos a pagar nao processados)", "rp_inscrito")
  set("^no bimestre \\(b\\)$", "receita_realizada_no_bimestre")
  set("^ate o bimestre \\(c\\)$", "receita_realizada")
  set("^ate o bimestre ?/ ?[0-9]{4}$", "receita_realizada")
  set("^valor$|^valor corrente$|^valor incorrido$", "valor")
  set("^em (31/12/)?[0-9]{4}", "saldo_rp")
  set("^(ate|no) o bimestre", "memo_bimestre")
  set("^%|^saldo", "derivada")
  data.frame(estagio = est, ano_rel = ano_rel, stringsAsFactors = FALSE)
}

# ---- Tabela de colunas -------------------------------------------------------------------------------------------------

#' Estágios que compõem o caixa da despesa (contrato): despesa paga + restos a pagar pagos (processados e não processados).
#' Confirmado em 28/10/2026: receita realizada − (a + b + c) reproduz o resultado primário publicado em 486 de 486 linhas
#' (2018–22) e 594 de 594 (2023+); (a) sozinha ou (a + b) não fecham.
ESTAGIOS_CAIXA_DESPESA <- c("paga", "rp_processado_pago", "rpnp_pago")
ESTAGIO_RECEITA <- "receita_realizada"

#' Quais colunas observadas entram no P2 e com que papel. Só o Anexo 6 alimenta o P2; o Anexo 1 é referência.
papel_coluna <- function(anexo, layout, estagio, ano_rel) {
  a6 <- anexo == "RREO-Anexo 06"
  corrente <- ano_rel %in% c("corrente", "nao_se_aplica")
  ifelse(a6 & estagio == "receita_realizada" & corrente, "receita_p2",
  ifelse(a6 & layout != "2015-17" & estagio %in% ESTAGIOS_CAIXA_DESPESA, "despesa_caixa_p2",
  ifelse(a6 & layout == "2015-17" & estagio %in% c("empenhada", "liquidada") & corrente, "despesa_sem_caixa",
  ifelse(a6 & estagio == "valor", "resultado_ou_meta",
  ifelse(anexo == "RREO-Anexo 03" & estagio == "mes_mr", "rcl_mensal",
  ifelse(anexo == "RREO-Anexo 03" & estagio == "total_12m", "rcl_total12m",
         "referencia"))))))
}

#' Constrói a tabela de colunas a partir do que existe no bruto (`rreo` = saída de ler_rreo_pasta()).
tabela_colunas <- function(rreo) {
  u <- unique(rreo[, c("anexo", "exercicio", "coluna")])
  u$layout <- as.character(layout_rreo(u$exercicio))
  cl <- classificar_coluna(u$coluna, u$exercicio)
  u <- cbind(u, cl)
  u$padrao <- gsub("(19|20)[0-9]{2}", "AAAA", u$coluna)
  u$papel <- papel_coluna(u$anexo, u$layout, u$estagio, u$ano_rel)
  out <- unique(u[, c("anexo", "layout", "padrao", "estagio", "ano_rel", "papel")])
  out <- out[order(out$anexo, out$layout, out$papel, out$padrao), ]
  rownames(out) <- NULL
  out
}

# ---- Tabela de contas (Anexo 6, base do P2) ----------------------------------------------------------------------------
# Papel: rec_folha / desp_folha entram na soma; rec_total / desp_total / resultado só conferem; filho_de_folha é detalhe de uma
# folha (nunca somar com ela); memo não entra no primário (dívida, nominal, financeiras). Regra geral: somar só folhas.
# Um mesmo cod_conta pode mudar de papel entre layouts, por isso a chave é (layout, cod_conta).

contas_a6 <- function() {
  L <- function(cod, layouts, papel, cat = NA, nat = NA, pai = NA, rpps = "nao_se_aplica", nota = NA)
    data.frame(cod_conta = cod, layouts = layouts, papel = papel, categoria_p2 = cat, natureza = nat, pai = pai,
               rpps = rpps, nota = nota, stringsAsFactors = FALSE)
  rec <- function(cod, layouts, cat, nat, rpps = "nao_se_aplica", nota = NA, pai = NA) L(cod, layouts, "rec_folha", cat, nat, pai, rpps, nota)
  des <- function(cod, layouts, cat, nat, nota = NA) L(cod, layouts, "desp_folha", cat, nat, NA, "nao_se_aplica", nota)
  ABC <- "ABC"; AB <- "AB"; BC <- "BC"; B <- "B"; C <- "C"; A <- "A"
  rpps_ab <- "incluido_nao_separavel"   # RPPS dentro da conta em 2015–2022 (separação só em 2023)
  rbind(
    # receitas: folhas
    rec("RREO6ICMS", ABC, "ICMS", "corrente", pai = "RREO6ReceitasTributarias"),
    rec("RREO6IPVA", ABC, "IPVA", "corrente", pai = "RREO6ReceitasTributarias"),
    rec("RREO6ISS", ABC, "ISS", "corrente", pai = "RREO6ReceitasTributarias"),
    rec("RREO6IPTU", ABC, "demais receitas", "corrente", pai = "RREO6ReceitasTributarias"),
    rec("RREO6ITBI", ABC, "demais receitas", "corrente", pai = "RREO6ReceitasTributarias"),
    rec("RREO6ITCD", ABC, "demais receitas", "corrente", pai = "RREO6ReceitasTributarias"),
    rec("RREO6IRRF", ABC, "demais receitas", "corrente", pai = "RREO6ReceitasTributarias"),
    rec("RREO6OutrasReceitasTributarias", ABC, "demais receitas", "corrente", pai = "RREO6ReceitasTributarias"),
    rec("RREO6FPE", ABC, "FPE/FPM", "corrente", pai = "RREO6TransferenciasCorrentes"),
    rec("RREO6CotaParteDoFPE", ABC, "FPE/FPM", "corrente", pai = "RREO6TransferenciasCorrentes",
        nota = "Mesmo conteúdo de RREO6FPE sob outro cod_conta: 26 estados usam este código e o DF (53) usa RREO6FPE; verificado no bruto de 28/10/2026"),
    rec("RREO6FPM", ABC, "FPE/FPM", "corrente", pai = "RREO6TransferenciasCorrentes",
        nota = "Cota-parte do FPM: só o DF (53) tem valor, por acumular as competências de estado e município; fica em FPE/FPM. Valores brutos, coerentes com a ponte pela STN"),
    rec("RREO6ReceitasDeContribuicoes", BC, "demais receitas", "corrente", rpps = rpps_ab, pai = "RREO6ReceitasPrimariasCorrentes"),
    rec("RREO6ReceitasPrevidenciarias", A, "demais receitas", "corrente", rpps = "incluido_nao_separavel", pai = "RREO6ReceitasDeContribuicoes",
        nota = "Contribuições previdenciárias (RPPS) dentro do primário em 2015–17"),
    rec("RREO6OutrasReceitasDeContribuicoes", A, "demais receitas", "corrente", pai = "RREO6ReceitasDeContribuicoes"),
    rec("RREO6ReceitaPatrimonialLiquida", A, "demais receitas", "corrente", nota = "Patrimonial menos aplicações financeiras (já líquida); os dois filhos não entram"),
    rec("OutrasReceitasPatrimoniais", BC, "demais receitas", "corrente", pai = "RREO6ReceitaPatrimonial", nota = "Patrimonial sem aplicações financeiras"),
    rec("CotaParteDoITR", BC, "demais receitas", "corrente", pai = "RREO6TransferenciasCorrentes"),
    rec("TransferenciasDaLC871996", B, "demais receitas", "corrente", pai = "RREO6TransferenciasCorrentes", nota = "Lei Kandir; só em 2018–22"),
    rec("TransferenciasDaLCn611989", BC, "demais receitas", "corrente", pai = "RREO6TransferenciasCorrentes"),
    rec("TransferenciasDoFUNDEB", BC, "receita FUNDEB", "corrente", pai = "RREO6TransferenciasCorrentes",
        nota = "Receita recebida do FUNDEB, categoria própria. Impostos e FPE estão pelo bruto; a dedução de formação do FUNDEB não está nos Anexos 1 e 6 (ver linha do Anexo 3). Líquido = bruto − dedução + receita FUNDEB"),
    rec("RREO6ConveniosCorrentes", A, "demais receitas", "corrente", pai = "RREO6TransferenciasCorrentes"),
    rec("RREO6OutrasTransferenciasCorrentes", ABC, "demais receitas", "corrente", pai = "RREO6TransferenciasCorrentes"),
    rec("RREO6DividaAtiva", A, "demais receitas", "corrente", pai = "RREO6DemaisReceitasCorrentes"),
    rec("RREO6DiversasReceitasCorrentes", ABC, "demais receitas", "corrente", pai = "RREO6DemaisReceitasCorrentes"),
    rec("RREO6ConveniosCapital", ABC, "demais receitas", "capital", pai = "RREO6TransferenciasDeCapital"),
    rec("RREO6OutrasTransferenciasDeCapital", ABC, "demais receitas", "capital", pai = "RREO6TransferenciasDeCapital"),
    rec("RREO6OutrasReceitasDeCapital", A, "demais receitas", "capital", pai = "RREO6ReceitasDeCapital"),
    rec("OutrasReceitasDeCapitalPrimarias", BC, "demais receitas", "capital", pai = "RREO6OutrasReceitasDeCapital"),
    rec("OutrasAlienacoesDeBens", BC, "demais receitas", "capital", pai = "RREO6AlienacaoDeBens",
        nota = "Alienação de bens que não é de investimentos; entra no primário (verificado contra o total)"),
    # receitas: totais e subtotais (só conferência)
    L("RREO6TotalReceitaPrimaria", ABC, "rec_total", nota = "Receita primária total; em 2023+ inclui fontes RPPS", rpps = "inclui_rpps_em_2023+"),
    L("ReceitaPrimariaTotalExcetoFontesRPPS", C, "rec_total", rpps = "ja_excluido", nota = "Total de conferência do P2 em 2023+"),
    L("ReceitasPrimariasCorrentesExcetoFontesRPPS", C, "rec_subtotal", rpps = "ja_excluido"),
    L("ReceitasPrimariasDeCapitalExcetoFontesRPPS", C, "rec_subtotal", rpps = "ja_excluido"),
    L("RREO6ReceitasPrimariasCorrentes", A, "rec_subtotal"),
    L("ReceitasPrimariasCorrentes", B, "rec_subtotal"),
    L("RREO6ReceitasPrimariasDeCapital", AB, "rec_subtotal"),
    L("ReceitasCorrentes", B, "rec_subtotal"),
    L("ReceitasCorrentesExcetoFontesRPPS", C, "rec_subtotal", rpps = "ja_excluido"),
    L("RREO6ReceitasTributarias", ABC, "rec_subtotal"),
    L("RREO6ReceitasDeContribuicoes", A, "rec_subtotal"),
    L("RREO6ReceitaPatrimonial", ABC, "filho_de_folha"),
    L("RREO6TransferenciasCorrentes", ABC, "rec_subtotal"),
    L("RREO6DemaisReceitasCorrentes", ABC, "rec_subtotal"),
    L("RREO6ReceitasDeCapital", AB, "rec_subtotal"),
    L("ReceitasDeCapitalExcetoFontesRPPS", C, "rec_subtotal", rpps = "ja_excluido"),
    L("RREO6TransferenciasDeCapital", ABC, "rec_subtotal"),
    L("RREO6AlienacaoDeBens", ABC, "rec_subtotal"),
    # receitas fora do primário (financeiras) e fontes RPPS
    L("RREO6AplicacoesFinanceiras", BC, "memo_financeira", rpps = "nao_se_aplica", nota = "Retirada do primário"),
    L("RREO6MenosAplicacoesFinanceiras", A, "filho_de_folha", nota = "Filha de RREO6ReceitaPatrimonialLiquida; não somar"),
    L("OutrasReceitasFinanceiras", BC, "memo_financeira", nota = "Retirada do primário"),
    L("RREO6OperacoesDeCredito", ABC, "memo_financeira"),
    L("RREO6AmortizacaoDeEmprestimos", ABC, "memo_financeira"),
    L("ReceitaDeAlienacaoDeInvestimentosPermanentes", BC, "memo_financeira"),
    L("ReceitasDeAlienacaoDeInvestimentosPermanentes", BC, "memo_financeira"),
    L("ReceitasDeAlienacaoDeInvestimentosTemporarios", BC, "memo_financeira"),
    L("OutrasReceitasDeCapitalNaoPrimarias", BC, "memo_financeira"),
    L("ReceitasPrimariasCorrentesComFontesRPPS", C, "so_rpps", rpps = "excluido", nota = "Fontes RPPS: fora do P2 (contrato)"),
    L("ReceitasNaoPrimariasCorrentesComFontesRPPS", C, "so_rpps", rpps = "excluido"),
    L("ReceitasPrimariasDeCapitalComFontesRPPS", C, "so_rpps", rpps = "excluido"),
    L("ReceitasNaoPrimariasDeCapitalComFontesRPPS", C, "so_rpps", rpps = "excluido"),
    L("RecursosArrecadadosEmExerciciosAnteriores", BC, "memo_financeira", nota = "Recursos do RPPS arrecadados em exercícios anteriores"),
    L("ReservaOrcamentariaDoRPPSPrevidenciario", BC, "so_rpps", rpps = "excluido"),
    L("RREO6ReservaDoRPPS", A, "so_rpps", rpps = "excluido"),
    L("AjustesRelativosAoRPPS", B, "so_rpps", rpps = "excluido"),
    # despesas: folhas
    des("RREO6PessoalEEncargosSociais", ABC, "pessoal", "corrente"),
    des("RREO6OutrasDespesasCorrentes", ABC, "custeio", "corrente", nota = "Inclui transferências constitucionais e legais; juros ficam fora do primário"),
    des("RREO6Investimentos", ABC, "investimento", "capital"),
    des("RREO6DemaisInversoesFinanceiras", ABC, "demais despesas de capital", "capital", nota = "Inversões financeiras primárias (sem concessão de empréstimos e títulos); fora de investimento"),
    des("RREO6ReservaDeContingencia", ABC, "demais despesas", "corrente", nota = "A reserva só tem dotação no bruto observado (nenhum valor pago); `sinalizar_reserva_paga()` avisa se aparecer pago"),
    # despesas: totais, subtotais, filhos
    L("RREO6TotalDespesaPrimaria", ABC, "desp_total", rpps = "inclui_rpps_em_2023+"),
    L("DespesaPrimariaTotalExcetoFontesRPPS", C, "desp_total", rpps = "ja_excluido", nota = "Total de conferência do P2 em 2023+"),
    L("DespesaPrimariaTotalOpcional", B, "desp_total"),
    L("RREO6DespesasPrimariasCorrentes", AB, "desp_subtotal"),
    L("RREO6DespesasPrimariasDeCapital", AB, "desp_subtotal"),
    L("DespesasPrimariasCorrentesExcetoFontesRPPS", C, "desp_subtotal", rpps = "ja_excluido"),
    L("DespesasPrimariasDeCapitalExcetoFontesRPPS", C, "desp_subtotal", rpps = "ja_excluido"),
    L("DespesasCorrentesExcetoFontesRPPS", C, "desp_subtotal", rpps = "ja_excluido"),
    L("DespesasDeCapitalExcetoFontesRPPS", C, "desp_subtotal", rpps = "ja_excluido"),
    L("RREO6DespesasCorrentes", AB, "desp_subtotal"),
    L("RREO6DespesasDeCapital", AB, "desp_subtotal"),
    L("DespesasPrimariasCorrentesComFontesRPPS", C, "so_rpps", rpps = "excluido"),
    L("DespesasPrimariasDeCapitalComFontesRPPS", C, "so_rpps", rpps = "excluido"),
    L("DespesasNaoPrimariasCorrentesComFontesRPPS", C, "so_rpps", rpps = "excluido"),
    L("DespesasNaoPrimariasDeCapitalComFontesRPPS", C, "so_rpps", rpps = "excluido"),
    L("RREO6DemaisDespesasCorrentes", ABC, "filho_de_folha", pai = "RREO6OutrasDespesasCorrentes"),
    L("RREO6TransferenciasConstitucionaisELegais", ABC, "filho_de_folha", pai = "RREO6OutrasDespesasCorrentes"),
    L("RREO6InversoesFinanceiras", ABC, "desp_subtotal"),
    L("RREO6ConcessaoDeEmprestimos", ABC, "memo_financeira"),
    L("RREO6AquisicaoDeTituloDeCapitalJaIntegralizado", ABC, "memo_financeira"),
    L("AquisicaoDeTituloDeCredito", BC, "memo_financeira"),
    L("RREO6AmortizacaoDaDivida", ABC, "memo_financeira"),
    L("RREO6JurosEEncargosDaDivida", ABC, "memo_financeira", nota = "Juros: fora do primário"),
    # resultado e metas
    L("RREO6ResultadoPrimarioEstadosMunicipios", AB, "resultado"),
    L("ResultadoPrimarioOpcional", B, "resultado"),
    L("ResultadoPrimarioSemRPPSAcimaDaLinha", C, "resultado", rpps = "ja_excluido", nota = "Resultado de conferência do P2 em 2023+"),
    L("ResultadoPrimarioComRPPSAcimaDaLinha", C, "resultado", rpps = "inclui_rpps_em_2023+"),
    L("ResultadoPrimarioAbaixoDaLinha", B, "resultado_abaixo_da_linha"),
    L("ResultadoPrimarioAbaixoDaLinhaSemRPPS", C, "resultado_abaixo_da_linha", rpps = "ja_excluido"),
    L("RREO6MetaDeResultadoPrimarioFixadaNoAnexoDeMetasFiscaisDaLDOParaOExercicioDeReferencia", ABC, "meta"),
    L("MetaResultadoPrimarioOpcional", B, "meta"),
    L("RREO6SaldoDeExerciciosAnteriores", ABC, "memo_financeira"),
    # outras linhas do Anexo 6: resultado nominal, dívida, apuração alternativa da LC 156/2016 (nada disso é primário do P2)
    L("ReceitaPrimariaTotalOpcional", B, "memo_alternativo", nota = "Repete o total de RREO6TotalReceitaPrimaria; não somar os dois"),
    L("RREO6OutrasReceitasDeCapital", BC, "rec_subtotal", nota = "Pai de OutrasReceitasDeCapitalPrimarias"),
    L("ResultadoNominalAbaixoDaLinha", B, "memo_nominal"), L("ResultadoNominalAcimaDaLinha", B, "memo_nominal"),
    L("ResultadoNominalAjustado", B, "memo_nominal"), L("ResultadoNominalOpcional", B, "memo_nominal"),
    L("ResultadoNominalAbaixoDaLinhaSemRPPS", C, "memo_nominal"), L("ResultadoNominalAbaixoDaLinhaSemRPPSAjustado", C, "memo_nominal"),
    L("ResultadoNominalAcimaDaLinhaSemRPPS", C, "memo_nominal"),
    L("MetaDeResultadoNominalFixadaNoAnexoDeMetasFiscaisDaLDOParaOExercicioDeReferencia", BC, "memo_nominal"),
    L("MetaResultadoNominalOpcional", B, "memo_nominal"),
    L("OutrosAjustes", BC, "memo_nominal"), L("VariacaoCambial", BC, "memo_nominal"), L("VariacaoSaldoRPP", BC, "memo_nominal"),
    L("VariacaoDoSaldoDasDemaisObrigacoesIntegrantesDaDC", C, "memo_nominal"), L("VariacaoDoSaldoDePrecatoriosIntegrantesDaDC", C, "memo_nominal"),
    L("JurosEncargosEVariacoesMonetariasAtivosExcetoRPPS", C, "memo_nominal"), L("JurosEncargosEVariacoesMonetariasPassivosExcetoRPPS", C, "memo_nominal"),
    L("JurosEEncargosAtivos", B, "memo_nominal"), L("JurosEEncargosPassivos", B, "memo_nominal"),
    L("SuperavitFinanceiro", BC, "memo_nominal"),
    L("DividaConsolidada", BC, "memo_divida"), L("DividaConsolidadaLiquida", BC, "memo_divida"), L("DeducoesDaDividaConsolidada", BC, "memo_divida"),
    L("DisponibilidadeDeCaixaBruta", BC, "memo_divida"), L("RREO5DisponibilidadeDeCaixa", BC, "memo_divida"),
    L("DemaisHaveresFinanceiros", BC, "memo_divida"), L("DepositosRestituiveisEValoresVinculados", BC, "memo_divida"),
    L("RestosAPagarProcessadosExcetoPrecatorios", BC, "memo_divida"), L("PassivosReconhecidosNaDC", B, "memo_divida"),
    L("PagamentoDePrecatoriosIntegrantesDaDC", B, "memo_divida"),
    L("ContribuicoesParaOPisPasepLC156", B, "memo_lc156"), L("DespesasCorrentesLC156", B, "memo_lc156"),
    L("DespesasPrimariasCorrentesConformeArt4LC156", B, "memo_lc156"), L("DespesasPrimariasCorrentesLC156", B, "memo_lc156"),
    L("JurosEEncargosDaDividaLC156", B, "memo_lc156"), L("OutrasDespesasCorrentesLC156", B, "memo_lc156"),
    L("PessoalEEncargosSociaisLC156", B, "memo_lc156"), L("TransferenciasConstitucionaisELegaisLC156", B, "memo_lc156",
      nota = "Apuração alternativa da LC 156/2016; fora do P2")
  )
}

#' Expande a tabela de contas do Anexo 6 por layout ("A" = 2015-17, "B" = 2018-22, "C" = 2023+) e marca o nível.
expandir_contas_a6 <- function() {
  x <- contas_a6()
  mapa <- c(A = "2015-17", B = "2018-22", C = "2023+")
  linhas <- lapply(seq_len(nrow(x)), function(i) {
    ls <- strsplit(x$layouts[i], "")[[1]]
    r <- x[rep(i, length(ls)), ]; r$layout <- unname(mapa[ls]); r
  })
  out <- do.call(rbind, linhas)
  out$layouts <- NULL
  out$rpps <- ifelse(out$rpps == "inclui_rpps_em_2023+", ifelse(out$layout == "2023+", "inclui_rpps", "incluido_nao_separavel"), out$rpps)
  out$anexo <- "RREO-Anexo 06"
  out$nivel <- ifelse(out$papel %in% c("rec_folha", "desp_folha"), "folha",
               ifelse(out$papel %in% c("rec_total", "desp_total", "resultado"), "total",
               ifelse(out$papel %in% c("rec_subtotal", "desp_subtotal"), "subtotal",
               ifelse(out$papel == "filho_de_folha", "detalhe", "memo"))))
  out$usar_no_p2 <- ifelse(out$papel %in% c("rec_folha", "desp_folha"), "soma",
                    ifelse(out$papel %in% c("rec_total", "desp_total", "resultado"), "conferencia", "nao"))
  out$estagio_p2 <- ifelse(out$papel == "rec_folha", "receita_realizada",
                    ifelse(out$papel == "desp_folha" & out$layout != "2015-17", "paga+rp_processado_pago+rpnp_pago",
                    ifelse(out$papel == "desp_folha", "sem_caixa(liquidada)", NA)))
  out
}

# ---- Tabela de contas (Anexo 1, só referência orçamentária) ------------------------------------------------------------

#' O Anexo 1 é orçamentário (inclui juros, amortização, intra-orçamentárias e dedução do RPPS não separada) e só agrega
#' impostos; ICMS, IPVA, ISS e FPE/FPM aparecem só no Anexo 6. Aqui só se classifica, sem uso no P2.
contas_a1 <- function(rreo) {
  u <- unique(rreo[rreo$anexo == "RREO-Anexo 01", c("exercicio", "cod_conta", "conta")])
  u$layout <- as.character(layout_rreo(u$exercicio))
  ag <- stats::aggregate(conta ~ layout + cod_conta, u, function(z) z[1])
  cc <- ag$cod_conta
  intra <- grepl("Intra", cc)
  total <- cc %in% c("TotalReceitas", "TotalDespesas", "TotalReceitasComDeficit", "TotalDespesasComSuperavit", "Deficit", "Superavit",
                     "SubtotalDasReceitas", "SubtotalDasDespesas")
  grande <- cc %in% c("ReceitasExcetoIntraOrcamentarias", "ReceitasIntraOrcamentariasTotal", "DespesasExcetoIntraOrcamentarias",
                      "DespesasIntraOrcamentariasTotal", "ReceitasCorrentes", "ReceitasDeCapital", "DespesasCorrentes", "DespesasDeCapital")
  desp <- grepl("^Despesa|Pessoal|Juros|Amortizacao|Investimentos|InversoesFinanceiras|ReservaDeContingencia|OutrasDespesas|Superavit$", cc) &
          !grepl("^Receita", cc)
  data.frame(layout = ag$layout, anexo = "RREO-Anexo 01", cod_conta = cc, conta = ag$conta,
             papel = ifelse(total, "total_orcamentario", ifelse(grande, "subtotal_orcamentario",
                      ifelse(desp, "desp_orcamentaria", "rec_orcamentaria"))),
             nivel = ifelse(total, "total", ifelse(grande, "subtotal", "folha")),
             intra = intra,
             usar_no_p2 = "nao", stringsAsFactors = FALSE)
}

# Anexo 3 (RCL) dos estados: informação complementar (bruto por imposto, FUNDEB), não entra na soma do P2. As contas acompanhadas
# (CATEGORIAS_A3) alimentam a receita mensal bruta/líquida; as demais ficam como memo.
CATEGORIAS_A3 <- c(
  ICMSLiquidoExcetoTransferenciasEFUNDEB = "ICMS", IPVALiquidoExcetoTransferenciasEFUNDEB = "IPVA",
  ITCDLiquidoExcetoTransferenciasEFUNDEB = "ITCD", IRRFLiquidoExcetoTransferenciasEFUNDEB = "IRRF",
  CotaParteDoFPE = "FPE", TransferenciasDoFUNDEB = "FUNDEB_receita", DeducaoDeReceitaParaFormacaoDoFUNDEB = "FUNDEB_deducao")

#' Contas do Anexo 3 observadas no bruto, por layout (o prefixo RREO3 aparece a partir de 2018 e é tirado para achar a categoria).
contas_a3 <- function(rreo) {
  u <- unique(rreo[rreo$anexo == "RREO-Anexo 03", c("exercicio", "cod_conta", "conta")])
  if (!nrow(u)) return(NULL)
  u$layout <- as.character(layout_rreo(u$exercicio))
  ag <- stats::aggregate(conta ~ layout + cod_conta, u, function(z) z[1])
  cat <- unname(CATEGORIAS_A3[sub("^RREO3", "", ag$cod_conta)])
  data.frame(anexo = "RREO-Anexo 03", layout = ag$layout, cod_conta = ag$cod_conta, conta = ag$conta,
             papel = ifelse(is.na(cat), "rcl_memo", "rcl_acompanhada"), nivel = "folha", usar_no_p2 = "nao",
             estagio_p2 = NA, categoria_p2 = cat, natureza = "corrente", pai = NA, rpps = "nao_se_aplica",
             nota = ifelse(is.na(cat), NA, "Alimenta a receita mensal bruta/líquida (calibrada pela DCA)"), stringsAsFactors = FALSE)
}

#' Dicionário completo de contas dos estados (Anexos 6 e 1) a partir do bruto observado (`rreo`). Conta observada e não
#' curada entra como "memo_nao_curado" (fora do P2), para o teste de cobertura apontar o que ainda falta decidir.
dicionario_contas_estados <- function(rreo) {
  r6 <- rreo[rreo$anexo == "RREO-Anexo 06", ]
  r6$layout <- as.character(layout_rreo(r6$exercicio))
  rotulo <- stats::aggregate(conta ~ layout + cod_conta, r6, function(z) z[1])
  a6 <- expandir_contas_a6()
  falta <- rotulo[!paste(rotulo$layout, rotulo$cod_conta) %in% paste(a6$layout, a6$cod_conta), c("layout", "cod_conta")]
  if (nrow(falta)) {
    falta$papel <- "memo_nao_curado"; falta$categoria_p2 <- NA; falta$natureza <- NA; falta$pai <- NA
    falta$rpps <- "nao_se_aplica"; falta$nota <- "Observada no bruto e ainda não classificada; fora do P2 até decisão"
    falta$anexo <- "RREO-Anexo 06"; falta$nivel <- "memo"; falta$usar_no_p2 <- "nao"; falta$estagio_p2 <- NA
    a6 <- rbind(a6[, names(falta)], falta)
  }
  a6 <- merge(a6, rotulo, by = c("layout", "cod_conta"), all.x = TRUE)
  a1 <- contas_a1(rreo)
  cols <- c("anexo", "layout", "cod_conta", "conta", "papel", "nivel", "usar_no_p2", "estagio_p2", "categoria_p2", "natureza", "pai", "rpps", "nota")
  for (n in setdiff(cols, names(a1))) a1[[n]] <- NA
  a1$rpps <- "nao_se_aplica"
  a3 <- contas_a3(rreo)
  out <- rbind(a6[, cols], a1[, cols], if (!is.null(a3)) a3[, cols])
  out <- out[order(out$anexo, out$layout, out$papel, out$cod_conta), ]
  rownames(out) <- NULL
  out
}

# ---- Aplicação -------------------------------------------------------------------------------------------------------

# fread/fwrite tratam o arquivo como UTF-8 em qualquer locale (read.csv com fileEncoding falha em locale C e com caracteres fora da code page).
ler_dicionario <- function(arquivo) data.table::fread(arquivo, encoding = "UTF-8", data.table = FALSE, na.strings = c("", "NA"), colClasses = "character")
gravar_dicionario <- function(x, arquivo) data.table::fwrite(x, arquivo, na = "", bom = FALSE)

#' Anexa ao bruto longo o layout, o estágio, o papel da coluna e os campos do dicionário de contas. Linha sem entrada no
#' dicionário fica com papel NA (aparece em `cobertura_dicionario()`); nada é descartado nem somado aqui.
aplicar_dicionario <- function(rreo, dic_contas, dic_colunas) {
  rreo$layout <- as.character(layout_rreo(rreo$exercicio))
  cl <- classificar_coluna(rreo$coluna, rreo$exercicio)
  rreo$estagio <- cl$estagio; rreo$ano_rel <- cl$ano_rel
  rreo$padrao <- gsub("(19|20)[0-9]{2}", "AAAA", rreo$coluna)
  rreo <- merge(rreo, dic_colunas[, c("anexo", "layout", "padrao", "papel")], by = c("anexo", "layout", "padrao"), all.x = TRUE, sort = FALSE)
  names(rreo)[names(rreo) == "papel"] <- "papel_coluna"
  rreo <- merge(rreo, dic_contas[, c("anexo", "layout", "cod_conta", "papel", "nivel", "usar_no_p2", "categoria_p2", "natureza", "rpps")],
                by = c("anexo", "layout", "cod_conta"), all.x = TRUE, sort = FALSE)
  names(rreo)[names(rreo) == "papel"] <- "papel_conta"
  rreo
}

#' O que o dicionário não cobre: combinações (anexo, layout, cod_conta) e (anexo, layout, coluna) observadas sem entrada.
cobertura_dicionario <- function(rreo, dic_contas, dic_colunas) {
  r <- unique(data.frame(anexo = rreo$anexo, layout = as.character(layout_rreo(rreo$exercicio)), cod_conta = rreo$cod_conta, stringsAsFactors = FALSE))
  sem_conta <- r[!paste(r$anexo, r$layout, r$cod_conta) %in% paste(dic_contas$anexo, dic_contas$layout, dic_contas$cod_conta), ]
  c1 <- unique(data.frame(anexo = rreo$anexo, layout = as.character(layout_rreo(rreo$exercicio)), padrao = gsub("(19|20)[0-9]{2}", "AAAA", rreo$coluna), stringsAsFactors = FALSE))
  sem_coluna <- c1[!paste(c1$anexo, c1$layout, c1$padrao) %in% paste(dic_colunas$anexo, dic_colunas$layout, dic_colunas$padrao), ]
  list(contas = sem_conta, colunas = sem_coluna)
}

# ---- Acumulado -> fluxo do bimestre (E2.6) ----------------------------------------------------------------------------

#' Converte valores acumulados no ano (RREO é "até o bimestre") em fluxo do bimestre: fluxo_b = acum_b − acum_{b−1}; no
#' bimestre 1, fluxo = acum. Se o bimestre anterior não existe para a mesma série, o fluxo é NA (nunca se supõe zero).
#' `x` precisa de: chave de série (colunas em `serie`), `ano`, `periodo`, `valor`. Retorna x com `fluxo` e `acum_anterior_ausente`.
acumulado_para_fluxo <- function(x, serie = c("cod_ibge", "cod_conta", "estagio"), ano = "exercicio", periodo = "periodo", valor = "valor") {
  chave <- do.call(paste, c(lapply(c(serie, ano), function(n) x[[n]]), sep = "\r"))
  ant <- paste(chave, x[[periodo]] - 1L, sep = "\r"); atual <- paste(chave, x[[periodo]], sep = "\r")
  v_ant <- x[[valor]][match(ant, atual)]
  x$fluxo <- ifelse(x[[periodo]] == 1L, x[[valor]], x[[valor]] - v_ant)
  x$acum_anterior_ausente <- x[[periodo]] > 1L & is.na(v_ant)
  x
}

# ---- Fechamento contra o publicado ----------------------------------------------------------------------------------------

#' Fechamento do Anexo 6 por ente x exercício x bimestre. Para cada arquivo: soma das folhas de receita e de despesa (pelo
#' dicionário) contra o total publicado, e receita − despesa contra o resultado publicado. Em 2015–17 não há caixa: o
#' resultado fecha na liquidação. `tol` em reais. Retorna uma linha por ente x ano x bimestre.
fechar_anexo6 <- function(rreo, dic_contas, dic_colunas, tol = 1000) {
  d <- aplicar_dicionario(rreo[rreo$anexo == "RREO-Anexo 06", ], dic_contas, dic_colunas)
  d <- d[!is.na(d$papel_conta), ]
  d$chave <- paste(d$cod_ibge, d$exercicio, d$periodo)
  corrente <- d$ano_rel %in% c("corrente", "nao_se_aplica")
  rec <- d[d$papel_coluna == "receita_p2" & corrente, ]
  rec$grupo <- ifelse(rec$papel_conta == "rec_folha", "folhas", ifelse(rec$papel_conta == "rec_total" & rec$rpps != "inclui_rpps", "total", NA))
  # 2015–17: despesa na liquidação; 2018+: caixa = soma dos estágios
  dsp <- d[(d$papel_coluna == "despesa_caixa_p2") | (d$papel_coluna == "despesa_sem_caixa" & d$estagio == "liquidada" & corrente), ]
  dsp <- dsp[!duplicated(dsp[, c("chave", "cod_conta", "estagio", "coluna")]), ]
  dsp$grupo <- ifelse(dsp$papel_conta == "desp_folha", "folhas", ifelse(dsp$papel_conta == "desp_total" & dsp$rpps != "inclui_rpps", "total", NA))
  rec <- rec[!duplicated(rec[, c("chave", "cod_conta", "coluna")]), ]
  soma <- function(x, g) { y <- x[!is.na(x$grupo) & x$grupo == g, ]; tapply(y$valor, y$chave, sum, na.rm = TRUE) }
  chaves <- sort(unique(d$chave))
  get <- function(v) { o <- v[chaves]; ifelse(is.na(o), NA_real_, o) }
  res_pub <- d[d$papel_conta == "resultado" & d$rpps != "inclui_rpps", ]
  res_pub <- res_pub[res_pub$papel_coluna == "resultado_ou_meta" | (res_pub$layout == "2015-17" & res_pub$estagio == "liquidada" & res_pub$ano_rel == "corrente"), ]
  res_pub <- res_pub[!duplicated(res_pub[, c("chave", "cod_conta", "coluna")]), ]
  rp <- tapply(res_pub$valor, res_pub$chave, function(z) z[1])
  out <- data.frame(chave = chaves, rec_folhas = get(soma(rec, "folhas")), rec_total = get(soma(rec, "total")),
                    desp_folhas = get(soma(dsp, "folhas")), desp_total = get(soma(dsp, "total")), resultado_publicado = get(rp),
                    stringsAsFactors = FALSE)
  out$rec_ok <- abs(out$rec_folhas - out$rec_total) <= tol
  out$desp_ok <- abs(out$desp_folhas - out$desp_total) <= tol
  out$resultado_ok <- abs((out$rec_total - out$desp_total) - out$resultado_publicado) <= tol
  p <- strsplit(out$chave, " "); out$cod_ibge <- as.integer(vapply(p, `[`, "", 1)); out$exercicio <- as.integer(vapply(p, `[`, "", 2))
  out$periodo <- as.integer(vapply(p, `[`, "", 3)); out$layout <- as.character(layout_rreo(out$exercicio))
  out$chave <- NULL
  out
}

#' Linhas em que a reserva de contingência aparece com valor pago (paga, RP processado pago ou RPNP pago) diferente de zero.
#' A reserva deveria ser só dotação; qualquer valor pago merece olhar antes de seguir (mapeada em "demais despesas").
sinalizar_reserva_paga <- function(rreo) {
  x <- rreo[rreo$anexo == "RREO-Anexo 06" & grepl("ReservaDeContingencia$", rreo$cod_conta), ]
  if (!nrow(x)) return(x)
  cl <- classificar_coluna(x$coluna, x$exercicio)
  x <- x[cl$estagio %in% ESTAGIOS_CAIXA_DESPESA & !is.na(x$valor) & x$valor != 0, ]
  x
}
