# Proposta: P2 com RPPS em todo o período (para aprovação; nada implementado)

Origem: pedido do Pedro em 30/10/2026, depois da correção de desenho do teste do RPPS (`docs/nota_gap.md`, seção 5). Esta proposta só vale se aprovada por escrito.

## 1. O que se propõe
- **Série do P2 para modelagem, gap e ponte (E3.6, E5, E5.4):** Anexo 6 **com** RPPS em todo o período. Até 2022 é o que o Anexo 6 já traz (RPPS dentro das contas, não separável); de 2023 em diante, a linha com RPPS: receita primária total (XVI), despesa primária com fontes RPPS somada à sem RPPS, e resultado primário com RPPS (XXXIV).
- **P2 sem RPPS** (linhas XVII, XXXIII e XXXV) fica só como **referência da meta da LDO**, não como série de modelagem.
- Justificativa: série contínua sem reconstrução, já que o RPPS não é separável antes de 2023 e o Anexo 6 de 2023 em diante só o separa por escolha do demonstrativo (MDF, 13ª ed.).

## 2. Ressalva que a proposta herda (importante)
A premissa é que a linha XXXIV de 2023 em diante reproduz o conceito do Anexo 6 anterior. **Isso não foi verificado**: o Anexo 4 não reproduz o "com − sem" do Anexo 6 em nível nem em sinal (`docs/nota_gap.md`, 5.3). Antes de implementar, proponho uma checagem de continuidade por UF, com critério fixado antes de olhar os dados: variação 2022→2023 de (resultado primário ÷ receita primária) em cada UF, nas duas versões, e comparação da dispersão das 27 variações com as de 2021→22 e 2020→21. Se a versão com RPPS tiver dispersão claramente maior que as do período anterior, a premissa cai.

## 3. Impacto no dicionário (`data/dicionario_contas_estados.csv`, layout 2023+)
- Das 9 contas hoje `rpps = excluido` (papel `so_rpps`, `usar_no_p2 = nao`), **4 mudam**: `ReceitasPrimariasCorrentesComFontesRPPS`, `ReceitasPrimariasDeCapitalComFontesRPPS`, `DespesasPrimariasCorrentesComFontesRPPS`, `DespesasPrimariasDeCapitalComFontesRPPS` passam a `rpps = incluido`, `usar_no_p2 = soma`. As outras 5 (despesas e receitas **não** primárias com fontes RPPS e a reserva orçamentária do RPPS) continuam fora, por serem não primárias.
- **Categorias:** essas 4 contas são totais correntes/capital, sem a abertura por categoria do E5. Até 2022 o RPPS está dentro das categorias (contribuições em "demais receitas"; benefícios em "pessoal"). Opções: (a) mapear receitas RPPS para "demais receitas" e despesas RPPS para "pessoal" (continuidade de categorias, com a hipótese de que benefícios são pessoal), ou (b) categorias próprias "RPPS receitas" e "RPPS despesas" a partir de 2023, deixando as categorias do E5 sem RPPS separável e com quebra em 2023. Recomendo (a) com validação pelo Anexo 4 (aposentadorias e pensões como parcela da despesa do RPPS) e a quebra de 2023 mantida como `conhecida` só se a validação falhar.
- Totais de conferência: a conferência de 2023+ passa a ser contra XVI (receita), a soma XXXIII + despesa RPPS (despesa) e XXXIV (resultado); os "exceto fontes RPPS" ficam como referência da LDO.
- Contrato (`docs/contrato.md`, Conceitos): a linha "RPPS: exceto fontes do RPPS" deixa de valer para a série de modelagem.

## 4. Impacto no conceito único (`R/transform/conceito_unico.R`)
- O ajuste de FUNDEB e cota-parte (impostos) **não muda**; ele mexe igualmente na receita e na despesa e não toca o RPPS.
- Muda a base de 2023+: `rec_total`, `desp_total` e `primario_a6` passam a incluir as 4 contas RPPS. O resultado primário passa a ser o XXXIV (receita − despesa).
- A validação "custeio reconstruído positivo" precisa de atenção: se as despesas RPPS forem mapeadas para "pessoal" (opção a) o custeio não muda; se forem mapeadas para outras despesas correntes, o custeio de 2023+ sobe e a validação de continuidade falha por construção.

## 5. Impacto nos testes
- `tests/test-dicionario.R`: o teste "RPPS: contas só-RPPS nunca entram" passa a valer só para as 5 contas não primárias; novo teste de fechamento (soma das folhas com as 4 contas RPPS = XVI e XXXIV, tolerância de R$ 1.000, em todos os UF-bimestres de 2023+).
- `tests/test-conceito_unico.R`: casos com RPPS (primário igual a receita − despesa com RPPS; ajuste de FUNDEB e cota-parte inalterado).
- Alertas (`R/quality/alertas.R`): a regra "RPPS 2023" de `marcar_conhecidas()` fica obsoleta se a opção (a) passar na validação.
- Gap (`R/transform/gap_p1_p2.R`): `p2_com_rpps_bim()` já existe; o gap oficial passa a usá-la desde 2023 (a referência deixa de ter fronteira em 2023 b1 e a classificação pós-2023 começa antes, em 2021 → mais bimestres classificáveis); mudança a registrar no contrato como pós-resultado.

## 6. Ordem sugerida se aprovada
1. Checagem de continuidade por UF (item 2). 2. Dicionário e testes. 3. Conceito único e testes. 4. Gap e ponte. 5. Contrato, plano e STATUS. Um PR por etapa; nada disso é feito antes da aprovação.
