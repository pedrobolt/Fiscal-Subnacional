# Rodada de teste 2026 dos estados: projecao, gap implicito e erro do SRW em anos de eleicao

Rodada de TESTE (sem `--oficial`), `--sem-download --rapida` (**DEGRADADA**), data 2026-11-05. P2 com dados do RREO ate o b4 (jan-ago); P1 com o SGS ate setembro. **IPCA de 2026 = 4,77% (premissas oficiais, informado por Pedro em 05/11/2026)**; o PIB nominal de 2026 e as demais premissas continuam sendo os da fixture (13.300 bi), o que so afeta o m3 (secao 4). Numeros de `outputs/teste/` (`scripts/teste_2026_gap.R`, `scripts/teste_2026_md.R`). **O primario implicito do P2 e descritivo: nao entra na planilha nem no texto do informe; o numero oficial continua sendo o P1 (SRW).**

## 1. Projecao 2026 dos estados (crescimento real, modelo oficial de cada serie na faixa b3-b4)

| conceito | despesa real | receita real | modelos | primario por diferenca 2026 (R$ bi) | primario 2025 (R$ bi) |
|---|---|---|---|---|---|
| consolidado (com RPPS, sem intra), 27 UFs | +8,9 | +4,8 | desp B0; rec M5s4 | -59,9 | -2,2 |
| sem RPPS, sem PR e RS, 25 UFs (ponte) | +9,5 | +4,9 | desp B0; rec M5s4 | -52,8 | 4,2 |

Informe anterior: despesa primaria +6,8% e receita +3,6% (`docs/informe_referencia.md`), em **conceito diferente** (serie sem RPPS, sem PR e RS, previsao feita antes desta especificacao); a linha da ponte e a mais proxima, mas tambem nao e igual. O primario por diferenca e a soma da receita total prevista menos a despesa total prevista, nominais.

## 2. Gap implicito em 2026 (P2 projetado menos P1 dos estados) e comparacao com o realizado

**2026 (corte b4 no P2, mes 9 no P1):** P2 projetado -59,9 bi (receita M5s4 1484,1 bi; despesa B0) menos SRW dos estados -14,4 bi = **gap implicito -45,5 bi** (-3,06% da receita projetada). Regra do E3.6 adaptada ao horizonte anual (mediana e MAD do gap realizado, em % da receita, dos tres anos anteriores; limiar = maior entre 4 MAD e 1% da receita; referencia = 3 anos, todos de 2023 em diante): referencia -0,56%, MAD 0,25%, limiar 1,01 p.p. => **classe ATIPICO**.

A regra do E3.6 e definida por bimestre; a versao anual e adaptacao nossa (a instabilidade, que exige 6 bimestres, nao se aplica). Gap = P2 menos P1; P2 realizado = receita total menos despesa total das 27 UFs (conceito consolidado); P1 = SGS 4643. Gap implicito historico = P2 projetado no b4 pelo modelo adotado da faixa (backtest do E5, amostra A) menos o SRW dos estados no mes 9 do mesmo ano.

| ano | P2 real | P1 real | gap real | gap real %rec | classe real | P2 proj b4 | erro P2 | SRW m9 | erro SRW | gap implicito | classe implicito |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2020 | 66,8 | 38,3 | +28,5 | +3,29 | - | - | - | - | - | - | - |
| 2021 | 122,4 | 78,2 | +44,2 | +4,29 | - | - | - | - | - | - | - |
| 2022 | 41,4 | 39,0 | +2,4 | +0,21 | atipico | 57,6 | +16,2 | 57,0 | +18,0 | +0,6 | atipico |
| 2023 | 18,2 | 27,5 | -9,3 | -0,81 | sem_referencia | 17,2 | -0,9 | 6,4 | -21,1 | +10,8 | sem_referencia |
| 2024 | 27,6 | 28,5 | -0,9 | -0,07 | sem_referencia | 5,7 | -21,9 | 36,1 | +7,6 | -30,4 | sem_referencia |
| 2025 | -2,2 | 5,5 | -7,6 | -0,56 | consistente | 18,4 | +20,6 | 17,0 | +11,6 | +1,4 | consistente |
| 2026 | - | - | - | - | - | -59,9 | - | -14,4 | - | -45,5 | atipico |

R$ bi; erro = previsao menos realizado, superavit positivo. Realizado so de 2020 em diante: a despesa total de 2015-17 nao esta reconstruida (Anexo 7 depois da carga) e 2018-19 tem UF faltando; antes de 2022 nao ha previsao do E5 com as 27 UFs na amostra A. "sem_referencia": 2023 e 2024 nao tem 2 anos na mesma serie (fronteira de 2023 do E3.6).

## 3. Decomposicao da diferenca (mesmo corte: P2 ate o b4, P1 no mes 8)

| componente | R$ bi | detalhe |
|---|---|---|
| P2 projetado (b4) | -59,9 | acumulado 14.0 + restante -73.9 |
| P1 SRW estaduais (mes 8) | -13,4 | acumulado 7.1 + restante(t-1) -20.5 |
| diferenca total (P2 - P1, mesmo corte b4/mes 8) | -46,5 |  |
| (i) acumulado ate o corte: P2 realizado - P1 realizado (jan-ago) | +6,9 |  |
| (ii) restante: P2 projetado - P1 restante(t-1) em R$ | -53,3 |  |
| (ii-a) razao do P2 vs restante(t-1) em R$ do proprio P2 (hipotese do modelo) | -27,1 |  |
| (ii-b) restante(t-1): P2 realizado - P1 realizado (gap realizado no fim de t-1) | -26,3 |  |
| memo: passagem do SRW do mes 8 ao mes 9 (P1) | -1,0 |  |
| memo: gap implicito no corte do P1 (P2 projetado - SRW mes 9) | -45,5 |  |
| memo: restante projetado, receita (P2) | +520,2 |  |
| memo: restante projetado, despesa (P2) | +594,1 |  |
| memo: restante(t-1) realizado, receita (P2) | +474,8 |  |
| memo: restante(t-1) realizado, despesa (P2) | +521,7 |  |
| memo: P2 com restante(t-1) em R$ (SRW em R$ no restante, B0') | -32,8 |  |
| memo: acumulado jan-ago de t-1, P2 | +44,6 |  |
| memo: acumulado jan-ago de t-1, P1 | +26,0 |  |
| memo: acumulado jan-ago de t, P2 | +14,0 |  |
| memo: acumulado jan-ago de t, P1 | +7,1 |  |

Leitura: do total (-46,5 bi), o acumulado ate o corte contribui com +6,9 bi (P2 acima do P1 em jan-ago) e a hipotese sobre o restante do ano com -53,3 bi. O restante se divide em (ii-a) -27,1 bi, a hipotese do modelo (restante projetado menos o restante realizado de t-1, ambos em R$ do P2), e (ii-b) -26,3 bi, que nao e hipotese: e a diferenca entre o restante de t-1 medido pelo RREO e pelo BCB. O P2 com o restante de t-1 em R$ (B0') daria -32,8 bi.

Dado dos acumulados: de jan-ago de t-1 para jan-ago de t, o primario acumulado cai de 44,6 para 14,0 bi no P2 e de 26,0 para 7,1 bi no P1; as duas fontes mostram piora, mais forte no RREO. Na receita e na despesa, o restante projetado e de 520,2 e 594,1 bi (t-1: 474,8 e 521,7).

## 4. m3 (sombra) para 2026, so informacao (nao publicar)

| esfera | m3 (R$ bi) | SRW (R$ bi) | m3 - SRW |
|---|---|---|---|
| regional (m3 do regional) | -15,7 | -7,4 | -8,3 |
| estaduais (m3 do componente, E4.1) | -19,6 | -14,4 | -5,2 |
| municipais (m3 do componente, E4.1) | 7,6 | 7,0 | +0,6 |

PIB nominal de 2026 = 13.300 bi (fixture, nao oficial); o m3 e em % do PIB, entao o valor muda com a premissa oficial.

## 5. Erro do SRW por esfera e corte: anos de eleicao estadual x demais (descritivo)

Erro = SRW menos realizado, R$ bi, **superavit positivo** (convencao do contrato): positivo = o SRW superestima o superavit. No sinal do BCB (deficit positivo) os mesmos erros aparecem com o sinal trocado (por exemplo 2014 e 2022 = -12 e -18). Anos de eleicao estadual: 2010, 2014, 2018, 2022 (n = 4); "demais" = 2007-2025 sem esses anos (n = 15); "sem 2020-21" tira a pandemia (n = 13). ME = erro medio; MAE = erro absoluto medio.

**estaduais**

| corte | ME eleicao | MAE eleicao | ME demais | MAE demais | ME demais sem 2020-21 | MAE demais sem 2020-21 |
|---|---|---|---|---|---|---|
| 1 | +18,6 | 18,7 | -3,0 | 11,3 | +1,0 | 8,6 |
| 2 | +19,9 | 20,4 | -3,0 | 10,3 | +0,6 | 7,8 |
| 3 | +21,7 | 22,3 | -3,3 | 10,7 | +0,3 | 8,2 |
| 4 | +21,5 | 23,6 | -3,5 | 9,9 | -0,2 | 7,6 |
| 5 | +21,5 | 23,0 | -3,3 | 10,9 | -0,2 | 9,0 |
| 6 | +18,1 | 19,7 | -2,5 | 9,7 | +0,1 | 8,2 |
| 7 | +16,9 | 18,0 | -2,7 | 8,5 | -0,8 | 7,4 |
| 8 | +10,2 | 10,2 | -1,1 | 6,4 | -0,5 | 6,2 |
| 9 | +7,6 | 7,6 | -0,8 | 5,3 | -0,8 | 5,7 |
| 10 | +4,9 | 6,5 | -0,5 | 4,5 | -0,7 | 5,1 |
| 11 | +2,8 | 3,3 | +0,2 | 4,1 | -0,1 | 4,3 |

**regional**

| corte | ME eleicao | MAE eleicao | ME demais | MAE demais | ME demais sem 2020-21 | MAE demais sem 2020-21 |
|---|---|---|---|---|---|---|
| 1 | +17,4 | 17,4 | -2,7 | 14,5 | +3,0 | 10,7 |
| 2 | +19,3 | 19,3 | -2,6 | 12,8 | +2,6 | 9,2 |
| 3 | +21,8 | 21,8 | -3,0 | 12,0 | +2,2 | 8,2 |
| 4 | +21,4 | 23,0 | -3,1 | 10,4 | +1,6 | 6,9 |
| 5 | +21,5 | 22,5 | -3,0 | 9,8 | +1,4 | 6,4 |
| 6 | +18,7 | 19,6 | -2,4 | 8,9 | +1,5 | 6,1 |
| 7 | +17,3 | 17,8 | -2,7 | 7,4 | +0,4 | 5,0 |
| 8 | +15,4 | 15,4 | -2,3 | 6,1 | -1,0 | 5,4 |
| 9 | +11,2 | 11,2 | -1,5 | 5,1 | -1,0 | 5,2 |
| 10 | +7,5 | 9,0 | -1,0 | 4,3 | -0,9 | 4,7 |
| 11 | +4,0 | 4,2 | +0,1 | 4,0 | -0,3 | 4,0 |

**municipais**

| corte | ME eleicao | MAE eleicao | ME demais | MAE demais | ME demais sem 2020-21 | MAE demais sem 2020-21 |
|---|---|---|---|---|---|---|
| 1 | -1,3 | 2,6 | +0,4 | 7,5 | +2,0 | 7,1 |
| 2 | -0,6 | 1,4 | +0,3 | 7,0 | +1,9 | 6,6 |
| 3 | +0,1 | 0,8 | +0,3 | 6,2 | +1,9 | 5,7 |
| 4 | -0,0 | 0,6 | +0,4 | 5,7 | +1,8 | 5,2 |
| 5 | +0,0 | 0,9 | +0,3 | 5,4 | +1,6 | 4,9 |
| 6 | +0,6 | 1,2 | +0,1 | 5,0 | +1,4 | 4,6 |
| 7 | +0,4 | 0,9 | +0,0 | 4,3 | +1,2 | 3,8 |
| 8 | +5,1 | 5,5 | -1,2 | 2,4 | -0,5 | 2,0 |
| 9 | +3,6 | 3,8 | -0,7 | 1,6 | -0,2 | 1,3 |
| 10 | +2,6 | 2,7 | -0,5 | 1,3 | -0,2 | 1,1 |
| 11 | +1,2 | 1,4 | -0,1 | 0,9 | -0,2 | 0,9 |

**Estaduais, por ano de eleicao** (cortes 4 e 9):

| ano | corte | SRW | realizado | erro |
|---|---|---|---|---|
| 2010 | 4 | 20,3 | 17,0 | +3,3 |
| 2010 | 9 | 17,3 | 17,0 | +0,4 |
| 2014 | 4 | 11,7 | -13,2 | +25,0 |
| 2014 | 9 | -1,3 | -13,2 | +12,0 |
| 2018 | 4 | 0,5 | 4,7 | -4,2 |
| 2018 | 9 | 4,7 | 4,7 | -0,0 |
| 2022 | 4 | 100,8 | 39,0 | +61,7 |
| 2022 | 9 | 57,0 | 39,0 | +18,0 |

Ressalvas: n = 4; em 2022 coincidem eleicao e LC 194 (corte de ICMS); 2010 e 2018 ficam perto de zero. O padrao e de dois anos grandes e dois nulos, nao de um vies estavel.

## 6. Leitura para a redacao do informe (descritiva)

1. **O -59,9 bi e a diferenca de dois agregados de cerca de R$ 1,5 tri**; o erro do P2 por diferenca no b4 foi de +16,2 bi (2022), -0,9 (2023), -21,9 (2024) e +20,6 (2025). Um erro de 1% na receita ja move o primario em cerca de R$ 15 bi.
2. O gap implicito historico no mesmo corte foi de +0,6, +10,8, -30,4 e +1,4 bi em 2022-2025, contra gaps realizados de +2,4, -9,3, -0,9 e -7,6. O implicito de 2026 (-45,5 bi) e atipico pela regra adaptada, mas o implicito tambem oscilou muito nos outros anos (2024: -30,4 bi), por erro de projecao do P2, nao por gap real.
3. Metade do restante vem de um fato medido, nao de hipotese: em set-dez de 2025 o RREO registrou -26,3 bi em relacao ao BCB (ii-b). No ano de 2025 o gap total e de -7,6 bi porque esse fim de ano compensou um gap de sinal oposto em jan-ago. Mesmo com o restante de t-1 em R$ nos dois lados (SRW no P2 e no P1), o gap seria de -19,4 bi (P2 B0' menos P1 no mes 8): o gap implicito de 2026 nao e so a hipotese da razao.
4. A hipotese do modelo (ii-a) e a razao restante/acumulado de t-1: a despesa (B0) repete a razao de 2025 e, como o acumulado da despesa cresce forte, o restante projetado sobe 13,9% nominal contra 9,6% na receita. Isso nao e testado como erro em anos de eleicao: a especificacao nao tem dummy eleitoral no E5.
5. O SRW do P1 nos estados, em ano de eleicao estadual, errou em media +7,6 bi no corte 9 (demais anos: -0,8), com 2014 e 2022 explicando quase tudo. Se o erro de 2022 (+18,0 bi) se repetisse, o P1 de 2026 iria de -14,4 para cerca de -32,4 bi, ainda longe do P2 (-59,9).

Redacao possivel (decisao de Pedro): manter o P1 como numero e, se o texto mencionar o RREO, falar de receita e despesa (crescimento real) e nao do primario implicito; ou citar a divergencia como risco de baixa sem numero do P2.

