# Intraorçamentárias no Anexo 6 de 2023 em diante (4/11/2026)

Critérios fixados antes de computar: `docs/intra_criterios.md` (commit 5378d5a). Script: `scripts/intra_harmonizacao.R`; funções: `R/transform/intra.R`. Números de `outputs/intra_{simetria,liquido,validacao,crescimento}.csv` (série com RPPS, 27 UFs, b6 salvo indicação). Despesa de intra = só a parcela **paga** do Anexo 1.

## 2a. A receita primária também passou a incluir as intra em 2023

| Ano | UFs onde "sem intra" vale (≤ 1%) | UFs onde "com intra" vale | Resíduo mediano sem / com intra (% da receita) | Leitura pela regra fixada (90%) |
|---|---|---|---|---|
| 2018 | 85,2% | 7,4% | 0,02 / -7,66 | inconclusivo |
| 2019 | 92,6% | 0,0% | 0,01 / -7,50 | exclui |
| 2020 | 96,3% | 0,0% | 0,00 / -7,56 | exclui |
| 2021 | 100% | 0,0% | 0,01 / -6,75 | exclui |
| 2022 | 100% | 0,0% | 0,01 / -7,03 | exclui |
| 2023 | 3,7% | 74,1% | 5,18 / -0,26 | inconclusivo |
| 2024 | 7,4% | 77,8% | 5,15 / -0,42 | inconclusivo |
| 2025 | 7,4% | 70,4% | 5,39 / -0,42 | inconclusivo |

- **Pela regra literal, 2023–2025 sai "inconclusivo"** (a hipótese "com intra" vale em 70% a 78% das UFs, abaixo de 90%), mas a hipótese "sem intra" falha em 93% a 96% das UFs e o resíduo mediano com intra é de -0,3% a -0,4% contra +5,2% sem. Leio como **inclui as intra**, com um resíduo de uns 0,3% a 0,4% que não identifiquei. A regra de 90% é mais dura que o ruído das outras contas.
- **Simetria:** receita e despesa passaram a incluir as intra no mesmo ano (2023). **O primário com RPPS não está subestimado.** O efeito líquido (intra de receita − intra de despesa paga) soma, nas 27 UFs, R$ 4,0 bi em 2023, R$ 1,5 bi em 2024 e R$ 2,2 bi em 2025, ou seja, o primário de 2023 em diante está **ligeiramente acima** do consolidado, não abaixo.
- Magnitude por UF (`intra_liquido.csv`): o líquido, em % da receita primária, tem mediana de 0,07% (2023), 0,11% (2024) e 0,13% (2025), com mínimo -1,64% e máximo +2,63%. Só duas UF-anos passam de 2%: TO (cód. 17, 2023: +2,6%) e AP (cód. 16, 2023: +2,4%).
- Cada lado, isolado, pesa bem mais: intra de receita R$ 92,5 bi, R$ 95,3 bi e R$ 100,7 bi (2023–2025) e intra de despesa paga R$ 88,6 bi, R$ 93,8 bi e R$ 98,5 bi; a intra de despesa é 5,6% a 6,0% da receita primária (mediana das UFs). Se só a despesa a incluísse, o primário estaria subestimado nesse valor; não é o caso.
- Limite: a intra de despesa é só a paga; os RP pagos de intra estão fora (dependem do Anexo 7), e parte do resíduo de 0,3% a 0,4% pode vir daí ou de outras contas.

## 2b. Harmonização: retirar as intra de 2023 em diante

Mapeamento fixado antes (intra do Anexo 1 → série do P2) e validação (yoy nominal de 2023 contra a média dos yoy de 2022 e 2024, mediana das UFs; passa se a diferença diminui e se o desvio cai em ≥ 50% das UFs):

| Série | n UFs | yoy 2023 bruto / harmonizado | média yoy 2022 e 2024, bruto / harmonizado | UFs com desvio menor | Passa |
|---|---|---|---|---|---|
| rec: demais receitas | 27 | 35,1% / 15,1% | 12,9% / 13,4% | 70,4% | **sim** |
| desp: pessoal | 27 | 20,8% / 10,2% | 11,8% / 12,1% | 66,7% | **sim** |
| desp: custeio | 27 | 9,3% / 7,2% | 21,0% / 20,8% | 40,7% | não |
| desp: investimento | 27 | -17,7% / -17,7% | 62,4% / 62,4% | 14,8% | não |
| desp: demais despesas de capital | 17 | 12,0% / 8,7% | 21,1% / 23,7% | 5,9% | não |

- **A retirada por categoria vale só em `rec:demais receitas` e `desp:pessoal`** (`INTRA_SERIES_VALIDADAS`). Para custeio, investimento e demais despesas de capital o mapeamento não se sustenta: ou a intra é pequena (investimento: o yoy não muda e os anos vizinhos são instáveis demais para a regra discriminar) ou não está nessas categorias do A6 (custeio: a retirada afasta o yoy de 2023 do dos vizinhos). **Nessas três categorias a intra fica no valor bruto**, e só o total é retirado por completo. Resultado: a soma das categorias harmonizadas é maior que o total harmonizado pela intra de custeio, investimento e capital.
- Na razão restante/acumulado do E5, um degrau proporcional que vale o ano inteiro tende a se cancelar; isso não foi testado aqui.

Crescimento real dos estados (27 UFs, IPCA mensal do SGS 433, bimestres comparáveis), total:

| Janela | Lado | Com intra (A6 de 2023+) | Sem intra (harmonizado) | Diferença (p.p.) |
|---|---|---|---|---|
| 2023 vs 2022 | receita | 5,58% | -2,30% | -7,88 |
| 2023 vs 2022 | despesa | 7,75% | -0,08% | -7,83 |
| 2024 vs 2023 | receita | 4,77% | 5,31% | 0,54 |
| 2024 vs 2023 | despesa | 4,38% | 4,62% | 0,25 |
| 2025 vs 2024 | receita | 2,46% | 2,55% | 0,09 |
| 2025 vs 2024 | despesa | 4,70% | 5,04% | 0,34 |
| 2026 b1–b4 vs 2025 | receita | 4,83% | 4,79% | -0,04 |
| 2026 b1–b4 vs 2025 | despesa | 8,45% | 8,77% | 0,32 |

**A quebra está só em 2023 contra 2022: -7,9 p.p. em receita e em despesa (a comparação de 2023 mistura um conceito sem intra com um com intra).** De 2024 em diante a diferença é de 0,0 a 0,5 p.p., porque os dois anos comparados têm o mesmo conceito. Para o informe de 2026 (2026 contra 2025) a retirada muda o crescimento da despesa em 0,3 p.p. (8,45% para 8,77%) e o da receita em -0,04 p.p.

## Para o Pedro
1. **Harmonização no total e em duas categorias** (demais receitas e pessoal). Custeio, investimento e demais despesas de capital ficam brutos.
2. **Implementação:** `R/transform/intra.R` (`fluxo_intra`, `harmonizar_intra`, `total_harmonizado`, com testes). **Não ligada à rodada nem ao informe**: ligar muda os números publicados de 2023 em diante e depende da sua aprovação.
3. Para o E5: usar o total harmonizado e as duas categorias harmonizadas. Os anos-alvo com 2023 como alvo passam a ter o conceito consolidado nos dois lados do cálculo de crescimento.

## Atualização de 04/11/2026 (17:03): linha "intraorçamentárias não alocadas"

Decisão do Pedro: nas categorias em que o mapeamento não passou (custeio, investimento, demais despesas de capital) o valor fica bruto, e uma linha explícita negativa, `desp:intra nao alocada` (e `rec:intra nao alocada`, hoje zero porque toda a intra de receita está em `rec:demais receitas`), faz **categorias + essa linha = total harmonizado, exatamente**. Implementação: `linhas_nao_alocadas()`, `harmonizar_fluxos()` e `checar_identidade_intra()` em `R/transform/intra.R`; a checagem falha se a diferença passar de R$ 1.
- **Teste na série real** (`scripts/intra_harmonizacao.R`, UF × bimestre × lado, 2021–2026): maior diferença absoluta **R$ 0,0000076**, em 1.836 combinações de UF, bimestre e lado. A identidade falha de propósito se uma categoria validada estiver ausente em algum bimestre (testado).
- **Tamanho da linha** (`outputs/intra_nao_alocada.csv`, soma das 27 UFs, despesa): -R$ 15,85 bi (2023), -R$ 21,97 bi (2024), -R$ 19,38 bi (2025) e -R$ 13,08 bi (2026 b1–b4). Zero até 2022.
