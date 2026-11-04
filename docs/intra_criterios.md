# Intraorçamentárias: critérios fixados antes de computar (4/11/2026)

Pedido do Pedro (04/11, 16:41), item 2 da decisão do E5.0. Este arquivo é commitado antes do script e dos resultados; o que mudar depois entra como mudança pós-resultado.

**Plano (resumo):** (2a) testar se a receita primária do Anexo 6 passou a incluir as intraorçamentárias em 2023, como a despesa; (2b) harmonizar retirando as intra (receita e despesa, do Anexo 1) de 2023 em diante e medir o efeito no crescimento real de 2023 a 2026; (2c) registrar a quebra na nota de quebras; (2d) refixar o critério da etapa 2 da despesa 2015–17 com a definição harmonizada. Série com RPPS, 27 UFs, UF-ano no b6 salvo indicação.

## 2a. Simetria da receita
- Receita primária do A6 (`RREO6TotalReceitaPrimaria`, coluna "Receitas realizadas (a)") contra o Anexo 1 (coluna "Até o Bimestre (c)"): `base = ReceitasExcetoIntraOrcamentarias − (ReceitasDeOperacoesDeCredito + AlienacaoDeBens + AmortizacoesDeEmprestimos) − RREO6AplicacoesFinanceiras (do A6)`. Duas hipóteses: **sem intra** (A6 = base) e **com intra** (A6 = base + `ReceitasIntraOrcamentariasTotal`).
- Uma hipótese "vale" num ano se a diferença em módulo é ≤ 1% da receita primária do A6 em ≥ 90% das UFs. Lê-se por ano: a receita **inclui** as intra no ano se a hipótese "com intra" vale e a "sem intra" não; **exclui** no caso inverso; inconclusivo nos demais.
- Se a receita incluir as intra nos mesmos anos que a despesa (2023+, etapa 1 da despesa, #59), o primário com RPPS não é subestimado: o efeito líquido no primário é (intra receita − intra despesa primária paga). Reporta-se esse líquido por UF e ano de 2023 a 2025, em R$ e em % da receita primária. Se só a despesa incluísse, o erro seria a intra de despesa inteira (reportada também).
- Intra de despesa primária = pagas de `PessoalEEncargosSociaisIntra`, `OutrasDespesasCorrentesIntra`, `InvestimentosIntra`, `InversoesFinanceirasIntra` (sem juros e amortização), Anexo 1 "DESPESAS PAGAS ATÉ O BIMESTRE (j)".

## 2b. Harmonização
- **Definição harmonizada (conceito consolidado e contínuo):** sem intraorçamentárias em todos os anos. Até 2022 o Anexo 6 já não as inclui; de 2023 em diante, subtrai-se do total e das categorias a intra do Anexo 1, convertida em fluxo bimestral (acumulado − acumulado anterior).
- **Mapeamento fixado antes (hipótese a validar):** receita total e `demais receitas` ← `ReceitasIntraOrcamentariasTotal`; despesa total ← soma dos quatro grupos acima; `pessoal` ← `PessoalEEncargosSociaisIntra`; `custeio` ← `OutrasDespesasCorrentesIntra`; `investimento` ← `InvestimentosIntra`; `demais despesas de capital` ← `InversoesFinanceirasIntra`.
- **Validação do mapeamento por categoria (critério):** com o mapeamento, o yoy nominal de 2023 contra 2022 (mediana das UFs) deve ficar mais perto da média dos yoy de 2022 e de 2024 do que sem a retirada, e em ≥ 50% das UFs o desvio absoluto contra essa média deve cair. Categoria que não passar fica **sem** retirada de categoria (a retirada vale só no total), e isso é reportado.
- A intra de despesa só tem a parcela **paga** no Anexo 1; os restos a pagar pagos de intra não estão no raw (dependem do Anexo 7). O resíduo é reportado, não corrigido.
- **Efeito no crescimento real** (IPCA mensal do SGS 433, índice médio do bimestre, bimestres comparáveis, como em `scripts/crescimento_conceito_rpps.R`): receita e despesa dos estados, 27 UFs, em 2023 contra 2022, 2024 contra 2023, 2025 contra 2024 e 2026 b1–b4 contra 2025, **com** e **sem** a retirada, mais a diferença em p.p.

## 2d. Critério da etapa 2 da despesa 2015–17, refixado
Substitui o critério de `docs/proposta_e62_e5_fase2.md`, 2.3, na definição de conceito. **A variante C da etapa 1 foi definida depois de ver o resultado; a definição abaixo, harmonizada, é fixada agora, antes de qualquer cálculo com o Anexo 7.**
- **Alvo (caixa harmonizado):** caixa do Anexo 6 (paga + RP processados pagos + RPNP pagos, `RREO6TotalDespesaPrimaria`) menos, de 2023 em diante, a intra de despesa primária **paga** do Anexo 1; 2018–2022 sem ajuste.
- **Reconstrução:** pagas do Anexo 1 nos grupos Pessoal, Outras despesas correntes, Investimentos e Inversões financeiras **sem as contas Intra em todos os anos** + restos a pagar pagos do Anexo 7 (processados e não processados, mesmos grupos, sem intra).
- **Critério:** diferença absoluta ≤ 1% do alvo em ≥ 90% dos UF-anos (b6), em 2018–2025 (e reportado também em acumulados bimestrais). Se passar, usar 2015–17; se falhar, o liquidado entra só como sensibilidade declarada e a despesa começa em 2018.
- O Anexo 7 só depois da carga histórica, com no máximo 2 conexões. Antes disso, checar se as colunas "Em AAAA" do Anexo 6 de 2015–17 trazem o pagamento de RP.
- **Limite conhecido:** os RP pagos de intra de 2023+ não estão separados no alvo; a diferença pode ter um resíduo desse tipo, que o Anexo 7 permitirá medir.
