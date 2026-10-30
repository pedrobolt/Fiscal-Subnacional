# Nota do gap P1 × P2 dos estados (E3.6)

Regra congelada em `docs/contrato.md` (seção "Regra de narrativa do gap P1 × P2", 30/10/2026), antes de calcular. Código: `R/transform/gap_p1_p2.R`, `scripts/gap_p1_p2.R`, `tests/test-gap_p1_p2.R`. Saídas (git-ignored): `outputs/gap_estados_bimestral.csv`, `outputs/gap_resumo_classes.csv`.

## 1. Séries do BCB
- SGS 4642 (regional), 4643 (estados), 4644 (municípios): fluxo mensal corrente, R$ milhões, déficit positivo. A 4382 é o PIB em 12 meses e não entra.
- Não encontrei série do BCB por UF no catálogo de dados abertos (a única de governos estaduais é a 4643, total). Não foi possível varrer o catálogo inteiro (a API bloqueia acesso automático): é "não encontrei", não prova de inexistência. Logo, o gap é só do total dos estados; por UF fica como limitação.

## 2. Tratamento do RPPS pelo BCB: **não confirmado**
- O Manual de Estatísticas Fiscais do BCB (março de 2018) mede as NFSP pelo financiamento (abaixo da linha) e em regime de caixa, e inclui fundos públicos e a administração indireta de estados e municípios. **Não menciona RPPS pelo nome**, e não diz se os ativos dos fundos previdenciários entram no cálculo do primário.
- Em consequência: não há evidência de incompatibilidade com o P2 sem RPPS, mas também não há confirmação de compatibilidade. Se o BCB inclui o fluxo líquido do RPPS (contribuições menos benefícios), o gap de 2023 em diante carrega esse fluxo e o de 2019–22, não (o P2 então incluía o RPPS). A fronteira de 2023 impede que a referência misture os dois regimes, mas não resolve a interpretação do nível do gap.
- **Ação sugerida (fora do repositório):** confirmar com o BCB (Depec) se o resultado primário de governos estaduais inclui o fluxo do RPPS e como trata os ativos financeiros dos fundos. Registrar a resposta aqui.

## 3. Resultado
Gap g = P2 − P1 (estados, bimestre, R$ bi). Há gap em 46 bimestres (2019 b1 a 2026 b4); P2 > P1 em 72% deles; mediana de r = 2,69% da receita primária agregada. O gap começa em 2019 b1 porque 2018 não tem as 27 UFs com fluxo (RS 2018 b1–b5 sem Anexo 6).

**Padrão sazonal forte:** mediana de r por bimestre, 2019–22: 12,0% (b1), 4,1%, 3,2%, 3,7%, 3,0%, −3,8% (b6); 2023 em diante: 7,5%, 2,4%, 2,5%, 2,2%, −0,9%, −9,4%. Confirma, depois do cálculo, a escolha (feita antes) da referência pelo mesmo bimestre dos anos anteriores.

### Classes por bimestre (% entre os classificáveis)
| Variante | Série | Consistente | Atípico | Instável | Quebra conhecida | Sem referência | Excluído |
|---|---|---|---|---|---|---|---|
| com 2020–22 | Informe | 8 (36.4%) | 3 (13.6%) | 1 (4.5%) | 10 (45.5%) | 24 | 0 |
| com 2020–22 | Bruto, sem rótulo de quebra | 14 (63.6%) | 5 (22.7%) | 3 (13.6%) | 0 (0.0%) | 24 | 0 |
| com 2020–22 | Sem reclassificação | 15 (68.2%) | 5 (22.7%) | 2 (9.1%) | 0 (0.0%) | 24 | 0 |
| sem 2020–22 | Informe | 0 (0.0%) | 0 (0.0%) | 0 (0.0%) | 10 (100.0%) | 18 | 18 |
| sem 2020–22 | Bruto, sem rótulo de quebra | 6 (60.0%) | 2 (20.0%) | 2 (20.0%) | 0 (0.0%) | 18 | 18 |
| sem 2020–22 | Sem reclassificação | 7 (70.0%) | 2 (20.0%) | 1 (10.0%) | 0 (0.0%) | 18 | 18 |

- "Informe" rotula como quebra conhecida o gap bruto desde 2025 b1 (10 bimestres) e usa a regra nos demais; "sem reclassificação" = gap + excedente de pessoal de RJ, PR e RS (diagnóstico, não correção).
- Classificáveis efetivos: 2021–22 (12 bimestres) e 2025–26 (10). 2019–20 não têm referência (menos de 2 anos anteriores); 2023–24 não têm referência pós-fronteira do RPPS. Na variante "sem 2020–22", 2021–22 saem e só restam 2025–26.

## 4. Leitura e limites
- A classe governa só a narrativa e o aviso do informe; não exclui o P2 da mistura do E5.4 (decisão do backtest do E5.4).
- Limiar e piso são convenções, sem calibração nem taxa de falso alarme conhecida. Qualquer ajuste depois destes números será mudança pós-resultado.
- Com 2 ou 3 observações na referência, o MAD é frágil (com 2, é metade da diferença entre elas); o piso de 1% pesa mais do que o 4 × MAD nesses casos.
- Gap sem reclassificação "consistente" em 2025–26 é evidência compatível com a reclassificação, não prova (excedente estimado pela proporção do RGF; três inícios escalonados).
- O gap é estruturalmente diferente de zero (P2 acima do P1 na maioria dos bimestres): são medidas diferentes (acima da linha em caixa × abaixo da linha). Estabilidade do gap não significa que o P2 esteja certo, só que é informativo para o P1.
- Municípios: fora do escopo até a carga e o dicionário municipais estarem prontos.

Fontes: Banco Central do Brasil, [Manual de Estatísticas Fiscais (2018)](https://www.bcb.gov.br/ftp/infecon/estatisticasfiscais.pdf); [Portal de Dados Abertos do BCB, governos estaduais (4643)](https://dadosabertos.bcb.gov.br/dataset?q=governos+estaduais+resultado+primario).

## 5. Teste da hipótese do RPPS (30/10/2026; critério fixado antes de calcular)
**Hipótese (Pedro):** o BCB (SGS 4643) cobre a administração direta e indireta dos estados e não exclui o RPPS; a exclusão do RPPS no Anexo 6 de 2023 em diante (MDF 13ª ed.) é escolha do demonstrativo para a meta da LDO. Logo o P2 "sem RPPS" tem uma quebra própria em 2023 em relação ao BCB. Pendência externa: pergunta enviada ao BCB em 30/10/2026; a resposta não é esperada para este teste.

**Versões do P2.** A (série oficial, não muda): Anexo 6 até 2022 (inclui RPPS) e resultado primário sem RPPS (linha XXXV) de 2023 em diante. B: Anexo 6 até 2022 e resultado primário com RPPS (linha XXXIV) de 2023 em diante, com receita primária total (linha XVI) como denominador. r = gap ÷ receita primária agregada da própria versão.

**Medidas.** (i) Para cada bimestre b1–b6, a mediana de r antes (2019–22) e depois (2023–24) da fronteira, e a diferença; (ii) o gap anual (soma dos 6 bimestres ÷ receita anual) por ano, 2019–25, e a variação 2022→2023 comparada com as variações 2019→20, 2020→21 e 2021→22; 2026 (b1–b4) só como acumulado parcial. "Depois" fica em 2023–24 para não misturar a reclassificação de pessoal de 2025; como robustez, 2023–26 usando o gap sem reclassificação nas duas versões.

**Critério de "contínua na fronteira" (sem limiar formal; n pequeno).** Contínua é a versão com menor soma de |diferença| da mediana por bimestre (b1–b6) **e** menor |variação do gap anual 2022→2023|. Se as duas medidas discordarem, a conclusão é "inconclusivo". Confundidores que não são separáveis aqui: LC 194/2022 (corte de ICMS em 2022, com efeito em 2023), recuperação pós-pandemia, ciclo eleitoral de 2022 (investimento) e a amostra de 2 anos "depois".

### 5.1 Resultado do teste
**(i) Mediana de r por bimestre (% da receita primária agregada).** O "antes" é igual nas duas versões (ambas incluem o RPPS até 2022).

| Bimestre | Antes (2019–22) | A depois (2023–24) | Dif. A | B depois (2023–24) | Dif. B |
|---|---|---|---|---|---|
| b1 | 12,01 | 9,44 | -2,58 | 6,81 | -5,21 |
| b2 | 4,08 | 4,87 | 0,80 | 2,10 | -1,98 |
| b3 | 3,19 | 5,31 | 2,12 | 2,79 | -0,40 |
| b4 | 3,66 | 2,44 | -1,22 | 0,35 | -3,31 |
| b5 | 2,99 | -0,01 | -3,01 | -2,61 | -5,61 |
| b6 | -3,76 | -8,30 | -4,54 | -8,80 | -5,04 |
| Soma de abs(dif), p.p. | | | 14,25 | | 21,55 |

**(ii) Gap anual.** Versão A = série oficial; B = com RPPS a partir de 2023. 2026 só tem b1–b4.

| Ano | Bimestres | Gap A (R$ bi) | Gap B (R$ bi) | B − A (R$ bi) | r A (% receita) | r B (% receita) |
|---|---|---|---|---|---|---|
| 2019  | 6 | 32,7 | 32,7 | 0,0 | 3,94 | 3,94 |
| 2020  | 6 | 26,6 | 26,6 | 0,0 | 3,07 | 3,07 |
| 2021  | 6 | 45,6 | 45,6 | 0,0 | 4,43 | 4,43 |
| 2022  | 6 | 4,7 | 4,7 | 0,0 | 0,42 | 0,42 |
| 2023  | 6 | 20,9 | -5,3 | -26,2 | 1,84 | -0,42 |
| 2024  | 6 | 27,2 | 0,4 | -26,9 | 2,19 | 0,03 |
| 2025  | 6 | -9,7 | -5,5 | 4,1 | -0,72 | -0,38 |
| 2026 (parcial) | 4 | 6,5 | 9,2 | 2,7 | 0,68 | 0,90 |

Variação anual do gap em p.p. da receita: 2019→20 −0,87; 2020→21 +1,36; 2021→22 −4,01 (iguais nas duas versões); **2022→23: A +1,42; B −0,84**. Números de `outputs/gap_rpps_anual.csv`.

### 5.2 Veredito pelo critério fixado antes: **inconclusivo**
- Pela mediana por bimestre, a versão A (sem RPPS) é a mais contínua: soma de |dif| menor (b1, b2, b4, b5 e b6 mais próximos em A; só b3 favorece B). Com 2023–26 e o gap sem reclassificação, o resultado se mantém (soma de |dif|: A 11,80 p.p.; B 20,94 p.p.).
- Pelo gap anual, a versão B é a mais contínua: |−0,84| < |+1,42| p.p. em 2022→23.
- As duas medidas discordam, então a conclusão é "inconclusivo". **Não há proposta de troca da série**: a versão B não é a contínua pelo critério.

**Por que não dá para separar.** A variação do gap anual em 2021→22 (−4,01 p.p.) é maior do que qualquer variação de 2022→23 em qualquer versão: o ano de 2022 é o ponto fora do padrão (gap de 0,42% da receita, contra 3,1% a 4,4% em 2019–21), com a LC 194/2022 (corte de ICMS) e o ciclo eleitoral, e é justamente o ano-base da comparação com 2023. Além disso, "depois" tem só 2 anos.

**Correção de desenho do teste (30/10/2026, Pedro; o erro foi da especificação).** O teste de continuidade **não identifica o tratamento do RPPS pelo BCB**. Como o P2 até 2022 já inclui o RPPS, sob as duas hipóteses (BCB inclui ou exclui) a versão com RPPS é contínua na fronteira de 2023 e a sem RPPS salta em −R, com R = fluxo primário líquido do RPPS. O resultado só informa se a linha "com RPPS" (XXXIV) de 2023 em diante reproduz o conceito anterior. A leitura anterior, que comparava a subida de 16,2 bi do gap A e a queda de 10,0 bi do gap B com os −26,2 bi, foi **retirada**: a soma 16,2 + 10,0 = 26,2 vale por construção (B − A = −26,2). O veredito "inconclusivo" do critério pré-fixado fica como registro, sem leitura sobre o BCB. A proposta condicional anterior foi substituída por `docs/proposta_p2_com_rpps.md`.

### 5.3 Checagem pelo Anexo 4: a linha "com RPPS" reproduz o conceito anterior?
Fluxo líquido do RPPS pelo RREO Anexo 4 (6º bimestre, acumulado do ano), 27 UFs, 2019–2024 (R$ bi). Líquido = receitas realizadas − despesas liquidadas dos dois planos (Fundo em Repartição e Fundo em Capitalização). Ficam fora a administração do RPPS, os benefícios mantidos pelo Tesouro e os militares. "Aportes" = linhas "Aportes para…" (coluna APORTES REALIZADOS), que não estão nas receitas totais. Código: `R/transform/rpps_anexo4.R`, `scripts/rpps_anexo4.R`, coleta em `scripts/baixar_anexo4.R` (162 arquivos).

| Ano | UFs | Receitas | Despesas liquidadas | Líquido (sem aportes) | Aportes do Tesouro | Líquido + aportes | Com − sem RPPS (Anexo 6) |
|---|---|---|---|---|---|---|---|
| 2019 | 27 | 94,1 | 183,3 | -89,2 | 108,0 | 18,7 | — |
| 2020 | 27 | 97,4 | 189,9 | -92,5 | 125,6 | 33,1 | — |
| 2021 | 27 | 87,2 | 152,5 | -65,3 | 92,4 | 27,1 | — |
| 2022 | 27 | 99,8 | 168,2 | -68,4 | 101,6 | 33,2 | — |
| 2023 | 27 | 105,4 | 181,9 | -76,4 | 115,4 | 39,0 | -26,2 |
| 2024 | 27 | 108,2 | 191,9 | -83,7 | 116,0 | 32,3 | -26,9 |

- **A linha "com RPPS" do Anexo 6 não reproduz o fluxo do Anexo 4, em nível nem em sinal.** O "com − sem" do Anexo 6 é −26,2 e −26,9 bi; o líquido do Anexo 4 sem aportes é de cerca de −76 e −84 bi (três vezes maior) e, com os aportes do Tesouro, é positivo (+39,0 e +32,3 bi). O Anexo 6 fica entre as duas medidas e não coincide com nenhuma.
- **Corte transversal por UF (2023 e 2024).**

| Ano | Regressão (27 UFs) | Inclinação | R² |
|---|---|---|---|
| 2023 | com − sem (A6) contra líquido do A4 (sem aportes) | 0,25 | 0,07 |
| 2023 | com − sem (A6) contra líquido do A4 + aportes | -1,00 | 0,47 |
| 2024 | com − sem (A6) contra líquido do A4 (sem aportes) | 0,29 | 0,10 |
| 2024 | com − sem (A6) contra líquido do A4 + aportes | -0,74 | 0,20 |

  A inclinação contra o líquido sem aportes é baixa e sem poder explicativo; contra o líquido com aportes é negativa (−1,00 em 2023, R² 0,47; −0,74 em 2024, R² 0,20), ou seja, o sinal é o oposto do esperado se o "com − sem" fosse o fluxo do RPPS. Não tenho explicação verificada (o tratamento dos aportes e das receitas e despesas intraorçamentárias no cálculo "fontes RPPS" do MDF é a hipótese a investigar); fica como achado, não como conclusão.
- **Sobre a "queda de 10 bi" do gap com RPPS em 2023:** o líquido do Anexo 4 muda −8,0 bi de 2022 para 2023 (sem aportes) e +5,8 bi (com aportes). Não há quebra do fluxo do RPPS em 2023 que explique sozinha a variação, e 2022 já é atípico no gap. O Anexo 4 não permite atribuir a variação.
- **Conclusão:** não foi possível verificar que a linha XXXIV reproduz o conceito pré-2023. Não refuta e não confirma. A premissa da série contínua com RPPS (`docs/proposta_p2_com_rpps.md`) fica condicionada a esse ponto.

## 6. Fim do rótulo "quebra conhecida" (esclarecimento de 30/10/2026, após o resultado do E3.6)
O gap bruto volta a ser classificado quando a referência (mín. 2 observações do mesmo bimestre, janela de 3 anos) estiver toda após o início das três quebras (RJ 2025 b1, RS 2025 b5, PR 2025 b6), isto é, depois do início da última (2025 b6). Implementado em `classificar_gap(quebras = )` (cada início abre um segmento novo; a referência só vale dentro do mesmo segmento) e calculado com o mesmo código (`primeiro_classificavel()`):

| Bimestre | Primeiro ano classificável |
|---|---|
| b1 | 2028 |
| b2 | 2028 |
| b3 | 2028 |
| b4 | 2028 |
| b5 | 2028 |
| b6 | 2027 |

Nenhum bimestre dos dados atuais (até 2026 b4) muda de classe com isso: 2025–26 continuam "quebra conhecida" no gap bruto.

## 7. NFSP por estado no BCB: só relato (30/10/2026; nada foi calculado)
- **O que o Manual de Estatísticas Fiscais diz (edição de maio de 2019, pp. 10–11, "Estatísticas fiscais regionais"):** o BCB divulga desde 2009 indicadores de dívida líquida e necessidades de financiamento **por estado**, pela capital e por uma amostra de municípios de cada estado (exceto a capital); estoques retroagem a dezembro de 2007 e fluxos a 1º trimestre de 2008; periodicidade **trimestral**; também em % da RCL acumulada em 12 meses, estimada pelos Relatórios de Gestão Fiscal. O manual diz que os dados regionais seguem a metodologia consolidada mas usam **dados de amostra**, por isso diferem da série consolidada. O manual **não** diz onde se publica nem em que formato, e não menciona RPPS na parte regional.
- **Onde é publicado hoje: não consegui localizar.** O site do BCB renderiza por JavaScript e não devolve conteúdo para leitura automática; o catálogo de dados abertos mostra só a SGS 4643 (total dos estados); o texto mensal de estatísticas fiscais de julho de 2026 só traz o agregado dos governos regionais. Portanto não posso informar formato, período coberto nem última data. Não sei se a série ainda é publicada com esse detalhe. Quem tem acesso ao site pode confirmar (ou incluir a pergunta na consulta ao BCB sobre o RPPS).
- **Se existir, (a) teste de corte transversal do tratamento do RPPS (critério fixado agora, antes de qualquer dado):** para cada UF i e ano y (2023 e 2024), gap_sem,i = P2 sem RPPS_i − P1_i (BCB por UF, anual) e R_i = P2 com RPPS_i − P2 sem RPPS_i (Anexo 6, linhas XXXIV − XXXV), ambos em % da receita da UF. Regressão de gap_sem,i em R_i, 27 UFs por ano, erros robustos (HC3). Inclinação −1 = o BCB inclui o RPPS (P1_i ≈ P2 com RPPS_i); inclinação 0 = exclui. Decisão: IC de 95% da inclinação contém −1 e não contém 0 → inclui; contém 0 e não contém −1 → exclui; contém os dois ou nenhum → inconclusivo. Ressalvas já conhecidas: o P1 por UF é de amostra e pode diferir do consolidado (erro de medida no regressor dependente atenua o resultado, mas aqui o erro está em y, não em x, e inflaria a variância); o resultado do Anexo 4 mostra que R_i não é o fluxo bruto do RPPS, o que não afeta o teste (R_i é a diferença das duas linhas do Anexo 6) mas impede dar a R_i uma interpretação econômica; e o gap por UF ainda mistura as diferenças de conceito acima/abaixo da linha. Antes, reconciliar a soma das 27 UFs do BCB regional com a SGS 4643.
- **(b) Reabertura do gap por UF no E3.6:** só se a série existir, for pública e de acesso reproduzível, e a soma das UFs reconciliar com a SGS 4643 em tolerância declarada. A periodicidade é trimestral, então o gap por UF seria anual (ou trimestral), não bimestral, e a regra de classificação do E3.6 não se aplica direto (referência sazonal de mesmo bimestre); exigiria nova regra, fixada antes dos dados.

Fontes: Banco Central do Brasil, [Manual de Estatísticas Fiscais (maio de 2019)](https://www.bcb.gov.br/content/estatisticas/Documents/notas_metodologicas/estatisticas-fiscais/estatisticasfiscais.pdf); [Portal de Dados Abertos do BCB, governos estaduais (4643)](https://dadosabertos.bcb.gov.br/dataset?q=governos+estaduais+resultado+primario); [Texto de estatísticas fiscais, julho de 2026](https://www.bcb.gov.br/content/estatisticas/hist_estatisticasfiscais/202607_Texto_de_estatisticas_fiscais.pdf).
