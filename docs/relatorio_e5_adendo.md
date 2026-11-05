# Adendo ao relatorio E5 (05/11/2026): checagens antes de adotar

Pedido de 05/11: (1) M4 fora da producao, M5 de producao = media dos aceitos **sem o M4**, criterios recalculados (**decisao operacional pos-resultado**, sem nova rodada); (a) B0' (SRW em R$) nas mesmas celulas; (b) variantes; (c) erro por ano. As regras de aceitacao nao mudaram. Script: `scripts/e5_adendo.R`; CSVs `outputs/e5_adendo_*.csv`.

## Leitura

1. **Os aceitos tambem batem o B0'** (SRW em R$, o do P1), com razao de RMSE de 0,75 (receita b3-b4), 0,75 (receita b5) e 0,59 (despesa b5) e bootstrap por ano de 0,99, 0,97 e 1,00.
2. **Instabilidade da razao:** na receita o B0 e o B0' ficam no mesmo nivel (RMSE 5,83 e 5,87 em b3-b4; 3,99 e 3,79 em b5), entao o ganho do candidato nao vem de a razao ser instavel. Na despesa b5 o B0 (7,35) e bem pior que o B0' (4,73): cerca de 36% dos 62% do ganho sobre o B0 e fraqueza da razao (concentrada em 2022: B0 13,33 contra B0' 5,51); o ganho sobre o B0' e de 41%. Nos cortes iniciais da despesa o B0 e pior no corte 1 (15,34 contra 11,63 do B0') mas melhor nos demais cortes de b1-b4.
3. **Variantes:** receita b3-b4 segue aceita (criterios 1-5) em todas as variantes, M5 sem M4 e membros. Receita b5 **falha sem conceito_original** (M5 sem M4: razao 0,880, anos 0,62, bootstrap 0,87) e passa sem RJ e sem RS. Despesa b5 (M3) **falha sem o RS** (pares UF-ano 0,48, abaixo de 0,50; razao de RMSE 0,377) e passa nas outras duas.
4. **Por ano:** receita b3-b4 e espalhada (nenhum ano responde por mais de 29% da reducao; retirando qualquer ano a razao fica entre 0,72 e 0,80; o candidato perde para o B0 em 1 dos 8 anos). **Receita b5 e concentrada em 2020** (64% da reducao; sem 2020 a razao sobe para 0,85; o candidato perde para o B0 em 2 dos 8 anos). **Despesa b5 e concentrada em 2022** (74% da reducao; sem 2022 a razao e 0,58; ainda melhor que o B0 nos 5 anos).
5. **Em suma:** favoravel para a receita b3-b4. Para a receita b5 as checagens **nao** sao favoraveis (ganho de um ano, 2020, e falha em uma variante); para a despesa b5 sao parcialmente favoraveis (ganho forte e estavel nos anos, mas concentrado em 2022 e fragil sem o RS). A decisao de adotar e do Pedro; as regras de aceitacao nao foram alteradas.


## 1. M5 sem M4: criterios

| serie | faixa | candidato | aceitos | n | razao_RMSE | pares | anos | sinal | vies | boot | razao_S | aceito |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| despesa total | b5 | M3 | M3 | 134 | 0,381 | 0,51 | 1,00 | ok | ok | 1,00 | 0,622 | sim |
| receita total | b3_b4 | M5 sem M4 | M1+M2+M3 | 428 | 0,758 | 0,61 | 0,88 | ok | ok | 1,00 | 0,728 | sim |
| receita total | b5 | M5 sem M4 | M1+M3 | 214 | 0,714 | 0,56 | 0,75 | ok | ok | 0,97 | 0,894 | sim |

Receita b3-b4: M1+M2+M3; receita b5: M1+M3; despesa b5: so o M3 (com um unico aceito a regra do protocolo manda o proprio M3).

## (a) Benchmark em R$: B0 (razao), B0' (SRW em R$, restante(t-1) nominal) e candidato nas mesmas celulas

RMSE em % do total anual, amostra A; `n` = celulas UF-ano-corte comuns aos tres. Candidato: M5 sem M4 (receita) ou M3 (despesa b5); nas celulas sem aceito, so os dois benchmarks.

| serie | faixa | n | candidato | B0 | B0' | candidato_RMSE |
|---|---|---|---|---|---|---|
| despesa total | b1_b2 | 268 | - | 12,18 | 10,75 |  NA |
| despesa total | b3_b4 | 268 | - | 5,24 | 6,59 |  NA |
| despesa total | b5 | 134 | M3 | 7,35 | 4,73 | 2,80 |
| receita total | b1_b2 | 428 | - | 8,29 | 8,77 |  NA |
| receita total | b3_b4 | 428 | M5 sem M4 | 5,83 | 5,87 | 4,42 |
| receita total | b5 | 214 | M5 sem M4 | 3,99 | 3,79 | 2,85 |

Por corte (mesmas celulas):

| serie | corte | B0 | B0' | candidato |
|---|---|---|---|---|
| despesa total | 1 | 15,34 | 11,63 |  NA |
| despesa total | 2 | 7,83 | 9,81 |  NA |
| despesa total | 3 | 5,47 | 7,49 |  NA |
| despesa total | 4 | 5,00 | 5,54 |  NA |
| despesa total | 5 | 7,35 | 4,73 | 2,80 |
| receita total | 1 | 9,27 | 9,46 |  NA |
| receita total | 2 | 7,17 | 8,01 |  NA |
| receita total | 3 | 6,66 | 6,62 | 5,16 |
| receita total | 4 | 4,87 | 5,00 | 3,52 |
| receita total | 5 | 3,99 | 3,79 | 2,85 |

Candidato contra o B0' (informacao, mesmos criterios 2-5 com o B0' como base):

| serie | faixa | candidato | razao_RMSE_vs_B0p | pares | anos | boot | sinal | vies |
|---|---|---|---|---|---|---|---|---|
| despesa total | b5 | M3 | 0,592 | 0,68 | 1,00 | 1,00 | ok | ok |
| receita total | b3_b4 | M5 sem M4 | 0,753 | 0,70 | 0,88 | 0,99 | ok | ok |
| receita total | b5 | M5 sem M4 | 0,752 | 0,57 | 0,88 | 0,97 | ok | ok |

## (b) Variantes de robustez nas tres celulas candidatas (amostra A; criterios 1-5; o criterio 6 usa a amostra S e nao foi reestimado nas variantes)

| variante | serie | faixa | modelo | n | razao_RMSE | pares | anos | boot | passa 1-5 |
|---|---|---|---|---|---|---|---|---|---|
| sem_conceito_original | despesa total | b5 | M3 | 134 | 0,381 | 0,51 | 1,00 | 1,00 | sim |
| sem_conceito_original | receita total | b3_b4 | M1 | 402 | 0,781 | 0,65 | 0,88 | 1,00 | sim |
| sem_conceito_original | receita total | b3_b4 | M2 | 392 | 0,887 | 0,58 | 0,75 | 0,91 | sim |
| sem_conceito_original | receita total | b3_b4 | M3 | 402 | 0,810 | 0,65 | 0,75 | 0,99 | sim |
| sem_conceito_original | receita total | b3_b4 | M5 sem M4 | 402 | 0,807 | 0,62 | 0,75 | 1,00 | sim |
| sem_conceito_original | receita total | b5 | M1 | 201 | 0,858 | 0,54 | 0,62 | 0,92 | nao |
| sem_conceito_original | receita total | b5 | M3 | 201 | 0,912 | 0,53 | 0,62 | 0,77 | nao |
| sem_conceito_original | receita total | b5 | M5 sem M4 | 201 | 0,880 | 0,52 | 0,62 | 0,87 | nao |
| sem_RJ | despesa total | b5 | M3 | 129 | 0,377 | 0,51 | 1,00 | 1,00 | sim |
| sem_RJ | receita total | b3_b4 | M1 | 412 | 0,740 | 0,66 | 0,88 | 1,00 | sim |
| sem_RJ | receita total | b3_b4 | M2 | 412 | 0,848 | 0,58 | 0,88 | 0,92 | sim |
| sem_RJ | receita total | b3_b4 | M3 | 412 | 0,785 | 0,61 | 0,88 | 0,98 | sim |
| sem_RJ | receita total | b3_b4 | M5 sem M4 | 412 | 0,771 | 0,61 | 0,88 | 0,99 | sim |
| sem_RJ | receita total | b5 | M1 | 206 | 0,712 | 0,56 | 0,75 | 0,96 | sim |
| sem_RJ | receita total | b5 | M3 | 206 | 0,724 | 0,55 | 0,75 | 0,95 | sim |
| sem_RJ | receita total | b5 | M5 sem M4 | 206 | 0,715 | 0,58 | 0,75 | 0,96 | sim |
| sem_RS | despesa total | b5 | M3 | 130 | 0,377 | 0,48 | 1,00 | 1,00 | nao |
| sem_RS | receita total | b3_b4 | M1 | 416 | 0,735 | 0,67 | 0,88 | 1,00 | sim |
| sem_RS | receita total | b3_b4 | M2 | 416 | 0,831 | 0,59 | 0,88 | 0,94 | sim |
| sem_RS | receita total | b3_b4 | M3 | 416 | 0,760 | 0,61 | 0,88 | 0,99 | sim |
| sem_RS | receita total | b3_b4 | M5 sem M4 | 416 | 0,758 | 0,61 | 0,88 | 1,00 | sim |
| sem_RS | receita total | b5 | M1 | 208 | 0,711 | 0,56 | 0,75 | 0,97 | sim |
| sem_RS | receita total | b5 | M3 | 208 | 0,727 | 0,54 | 0,75 | 0,95 | sim |
| sem_RS | receita total | b5 | M5 sem M4 | 208 | 0,716 | 0,55 | 0,75 | 0,96 | sim |

## (c) Erro por ano nas tres celulas (RMSE %, todas as UFs do ano e cortes da faixa)

`parcela` = parte da reducao total da soma dos erros ao quadrado (B0 menos candidato) que cada ano responde; `sem o ano` = razao de RMSE candidato/B0 retirando aquele ano.

| serie | faixa | ano | n | B0 | B0' | candidato | parcela | sem o ano |
|---|---|---|---|---|---|---|---|---|
| despesa total | b5 | 2021 | 26 | 7,17 | 7,42 | 4,02 | 0,15 | 0,327 |
| despesa total | b5 | 2022 | 27 | 13,33 | 5,51 | 2,86 | 0,74 | 0,583 |
| despesa total | b5 | 2023 | 27 | 4,68 | 3,28 | 1,83 | 0,08 | 0,380 |
| despesa total | b5 | 2024 | 27 | 2,91 | 2,73 | 2,34 | 0,01 | 0,359 |
| despesa total | b5 | 2025 | 27 | 3,23 | 3,04 | 2,51 | 0,02 | 0,356 |
| receita total | b3_b4 | 2018 | 52 | 2,96 | 4,60 | 4,48 | -0,09 | 0,720 |
| receita total | b3_b4 | 2019 | 52 | 5,83 | 7,31 | 5,12 | 0,07 | 0,740 |
| receita total | b3_b4 | 2020 | 54 | 7,80 | 7,53 | 5,56 | 0,26 | 0,770 |
| receita total | b3_b4 | 2021 | 54 | 5,25 | 6,35 | 4,22 | 0,09 | 0,752 |
| receita total | b3_b4 | 2022 | 54 | 8,44 | 4,38 | 6,16 | 0,29 | 0,767 |
| receita total | b3_b4 | 2023 | 54 | 6,22 | 6,48 | 2,58 | 0,28 | 0,801 |
| receita total | b3_b4 | 2024 | 54 | 3,92 | 4,84 | 3,36 | 0,04 | 0,751 |
| receita total | b3_b4 | 2025 | 54 | 3,86 | 4,43 | 2,39 | 0,08 | 0,765 |
| receita total | b5 | 2018 | 26 | 2,20 | 2,49 | 2,05 | 0,01 | 0,704 |
| receita total | b5 | 2019 | 26 | 4,00 | 5,05 | 4,67 | -0,09 | 0,626 |
| receita total | b5 | 2020 | 27 | 6,74 | 4,96 | 2,38 | 0,64 | 0,852 |
| receita total | b5 | 2021 | 27 | 2,70 | 3,56 | 1,88 | 0,06 | 0,715 |
| receita total | b5 | 2022 | 27 | 4,03 | 2,85 | 4,17 | -0,02 | 0,653 |
| receita total | b5 | 2023 | 27 | 4,43 | 4,71 | 1,94 | 0,26 | 0,754 |
| receita total | b5 | 2024 | 27 | 2,95 | 3,12 | 2,75 | 0,02 | 0,695 |
| receita total | b5 | 2025 | 27 | 3,03 | 2,48 | 1,19 | 0,13 | 0,733 |

## Para o texto do informe

Os entes subestimam a receita na previsao atualizada: vies de -8,4% (b1-b2), -7,1% (b3-b4) e -5,1% (b5) do total anual (`outputs/e5_entes.csv`, previsao atualizada contra a receita realizada, Anexo 6, 27 UFs, 2018-2025).

