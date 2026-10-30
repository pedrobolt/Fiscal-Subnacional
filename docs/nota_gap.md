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
