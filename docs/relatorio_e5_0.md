# Relatório E5.0 (4/11/2026)

Critérios fixados antes de computar: `docs/e5_0_criterios.md` (commit 975865e). Script: `scripts/e5_0_relatorio.R`; números de `outputs/e5_0_*.csv` (série com RPPS, 27 UFs, RREO Anexo 6). Nenhum modelo do E5 foi rodado; o único cálculo de previsão é o B0 (SRW na razão restante/acumulado), usado nos erros da calibração de poder. Tudo que foi acrescentado depois de ver o resultado está marcado.

## 1. Anos-alvo e UF-anos efetivos

Regra: UF-ano válido = 5 cortes com acumulado e restante > 0; alvo = válido, com o ano anterior válido e ao menos 3 UF-anos válidos antes.

| Escolha | Categorias | Anos-alvo (todos / sem 2020–22) | UF-anos (todos / sem 2020–22) |
|---|---|---|---|
| R1 receita 2015+ | total, ICMS, IPVA, FPE/FPM, demais | 2018–2025: 8 / 5 | total 214 / 133; ICMS 214 / 133; IPVA 207 / 129 |
| R2 receita 2019+ | idem | 2022–2025: 4 / 3 | total 108 / 81; IPVA 104 / 79 |
| D1 despesa 2018+ | total, pessoal, custeio, investimento | 2021–2025: 5 / 3 | 134 / 81 (todas as categorias) |

- **Escolher 2015+ para a receita dobra os anos-alvo (4 para 8) e os UF-anos (108 para 214).** A perda de células por sinal ou ausência é pequena: o total de receita tem 296 dos 297 UF-anos possíveis (2015–2025) válidos.
- A despesa com reconstrução 2015+ daria 8 anos-alvo (aritmética igual à da receita), mas depende da etapa 2 (Anexo 7); não é contável agora.
- FUNDEB (receita e dedução) e demais despesas de capital ficam de fora desta tabela (sinal misto): entram em nível, como no protocolo.

## 2. Quebra de RJ/PR/RS em 2025 na série com RPPS

Regra do `docs/e5_0_criterios.md`: desvio contra a mediana das outras UFs, 2 bimestres consecutivos, 20 p.p. (despesa, receita, pessoal) ou 10 p.p. em módulo (primário, em % da receita).

| Variável | RJ/PR/RS com corrida iniciada em 2025+ | UFs fora das três com corrida na janela 2024+ (de 24) |
|---|---|---|
| Despesa total | **nenhuma** | 3 |
| Receita total | **nenhuma** | 1 |
| Primário | RJ 2025 b4 (2 bim., desvio médio +2,6 p.p., sinais opostos) e RS 2025 b4 (-11,7 p.p.) | **16** |
| Pessoal COM (controle negativo) | **nenhuma** | 3 |
| Pessoal SEM (controle positivo) | RJ 2025 b1 e b5, 2026 b3; PR 2025 b6; RS 2025 b5 | 4 |

Leitura:
1. **Despesa e receita total sem quebra** nas três UFs, e o controle positivo (pessoal sem RPPS) detecta as três nas datas já conhecidas. A regra tem sensibilidade para o tamanho da quebra do pessoal sem RPPS; não tem para uma quebra menor que 20 p.p. de desvio.
2. **O primário não passa no critério de especificidade** fixado antes (16 de 24 UFs, 67%, acima de 10%): o limiar de 10 p.p. na margem é frouxo demais para a volatilidade bimestral. A corrida do RJ junta desvios de sinais opostos (regra por módulo): não é um degrau.
3. **Descritivo sem limiar (acrescentado depois do resultado):** desvio médio de 2025, em p.p., e posto entre as 27 UFs (1 = maior); desvio-padrão do desvio nas 24 UFs entre parênteses.

| Variável | RJ | PR | RS |
|---|---|---|---|
| Despesa total (dp 5,0) | +9,2 (2º) | +3,0 (7º) | -2,5 (18º) |
| Receita total (dp 2,3) | **+9,7 (1º)** | -3,2 (25º) | -4,4 (26º) |
| Primário (dp 4,4) | +2,6 (9º) | -5,3 (23º) | -2,8 (21º) |
| Pessoal COM (dp 6,2) | +5,2 (3º) | -1,2 (20º) | -0,7 (18º) |
| Pessoal SEM (dp 3,7) | +67,0 (1º) | +22,0 (3º) | +31,2 (2º) |

4. **Recomendação (decisão do Pedro):** retirar o degrau RJ/PR/RS 2025+ da série com RPPS em despesa total e primário. Em despesa total, PR e RS estão dentro de 1 desvio-padrão; no primário, as três ficam a menos de 1,3 desvio-padrão. **Ressalva:** o RJ é o maior desvio de receita total de 2025 (+9,7 p.p., 4 desvios-padrão) e o 2º de despesa total (+9,2 p.p.), na mesma direção nos dois lados, o que não é a assinatura da reclassificação de pessoal (que não mexe no primário). Origem não investigada (a série com RPPS inclui receitas e despesas com fontes RPPS nos dois lados). Fica como item de acompanhamento do RJ, sem dummy.

## 3. Receita do RS na série sem RPPS

A diferença COM − SEM está só em "demais receitas" (as contas de receita com fontes RPPS), em R$ milhões: 19.579 (2023), 19.686 (2024), 10.250 (2025) e 6.982 (2026 b1–b4). Em % da receita total, ela é de 23% a 30% por bimestre até 2025 b4, vira **-34,7% em 2025 b5** (ajuste retroativo dentro do ano, como no pessoal) e fica em 11% a 13% em 2026. Ou seja, **a receita com fontes RPPS do RS cai à metade a partir de 2025**, espelhando a queda de fontes RPPS no pessoal. Na série com RPPS, que soma as duas partes, o efeito sobre o total não aparece (receita COM -0,4% em 2025). Na série sem RPPS, o RS precisa de dummy de receita (degrau em demais receitas) além da de pessoal, nas mesmas datas.

## 4. Calibração de poder

Erro B0 = log r(t−1) − log r(t). RMSE por corte (log da razão), de `outputs/e5_0_rmse_b0.csv`: receita total 0,11 a 0,20; despesa total 0,09 a 0,21; ICMS 0,14 a 0,21; pessoal 0,10 a 0,27; o corte 5 é o pior em todas.

Poder de detectar um candidato com RMSE 10% menor (teste t sobre a média de perda por ano, unilateral 5%, 2.000 réplicas, semente 20261104), por T e correlação ρ entre os erros de candidato e B0:

| Série (T disponível) | ρ | T=3 | T=4 | T=5 | T=8 | T=12 |
|---|---|---|---|---|---|---|
| Receita total (8) | 0,5 | 0,10 | 0,10 | 0,15 | 0,25 | 0,35 |
| Receita total (8) | 0,8 | 0,12 | 0,19 | 0,29 | 0,49 | 0,70 |
| Despesa total (5) | 0,5 | 0,09 | 0,12 | 0,15 | 0,28 | 0,39 |
| Despesa total (5) | 0,8 | 0,14 | 0,24 | 0,33 | 0,58 | 0,75 |
| ICMS (8) | 0,5 | 0,05 | 0,07 | 0,08 | 0,15 | 0,20 |
| ICMS (8) | 0,8 | 0,09 | 0,12 | 0,17 | 0,31 | 0,47 |
| Pessoal (5) | 0,5 | 0,13 | 0,17 | 0,21 | 0,32 | 0,41 |
| Pessoal (5) | 0,8 | 0,19 | 0,29 | 0,40 | 0,58 | 0,77 |

- **Com o T efetivo (8 para receita 2015+, 5 para despesa 2018+), o poder fica entre 0,15 e 0,49 em quase todos os casos** (0,33 a 0,40 na despesa com T=5, ρ=0,8). Só chega a 0,5 com ρ = 0,8 e T ≥ 8 na despesa ou T ≥ 12 na receita. Pela regra fixada em 04/11 (poder abaixo de 50%): **os testes entram como informação e a decisão fica por magnitude e bootstrap por ano.**
- **Efeito da escolha 2015+:** na receita total com ρ = 0,8, o poder passa de 0,19 (T=4, receita 2019+) para 0,49 (T=8). A despesa com reconstrução 2015+ levaria a despesa de T=5 (0,33) a T=8 (0,58, mesmo ρ); só se confirma depois do Anexo 7.
- **Limites:** o poder depende de ρ e do tamanho do ganho (10%), que são hipóteses; o teste agrupa por ano porque os choques comuns correlacionam as UFs, o que é conservador com poucos graus de liberdade. Os erros usam as séries totais e de três categorias, não todas.

## Para o Pedro decidir
1. Retirar o degrau RJ/PR/RS 2025+ da série com RPPS em despesa total e primário (recomendado; ressalva do RJ na seção 2).
2. Escolher o ponto de partida da receita: 2015+ (8 anos-alvo) em vez de 2019+ (4).
3. Aceitar a leitura de poder: testes formais como informação; decisão por magnitude e bootstrap por ano.
4. Nada de modelo do E5 foi rodado; o E5 só começa com sua aprovação deste relatório.
