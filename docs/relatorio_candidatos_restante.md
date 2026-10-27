# Candidatos do restante do ano em % do PIB (27/10/2026)

Reprodução: `Rscript scripts/candidatos_restante.R [--registrar]` (saídas em `outputs/restante_*.csv`; linhas em `experiments/registro.csv`, valores em R$ bi). Sem chamadas ao Siconfi.
Alvo: primário regional BCB (SGS 4642), total anual = acumulado até o corte (observado) + restante previsto (corte+1..dez). R$ bi, superávit positivo.

## Candidatos
- `srw_pib`: restante(t-1) em % do PIB(t-1), aplicado ao PIB(t). `srw_brl`: SRW em R$ (referência).
- `m2`: restante ~ restante(t-1) + dummy de eleição estadual. `m3`: restante ~ acumulado(t) + restante(t-1) + dummy (todos em % do PIB).
- Controles da sua ressalva sobre tendência: `m3_tend` (m3 + termo de tendência) e `m3_jan10` (m3 com janela móvel de 10 anos). Sensibilidade: `m3_2eleic` (m3 + dummy de eleição municipal, já que os municípios compõem o regional).
- Estimação rolante: o alvo t usa só anos y < t, mínimo de 8 anos de treino (1999 em diante, alvos 2007–2025). "Sem 2020–22" tira esses anos do treino **e** do teste (n = 16; com eles, n = 19).
- Métricas por corte: ME, MAE, RMSE em R$ bi e em p.p. do PIB; MASE relativo ao SRW (= MAE/MAE do `srw_pib`, em % do PIB); DM (perda quadrática, h = 1, correção HLN) contra o `srw_pib`; acerto de sinal do total anual. Todas em `outputs/restante_resumo.csv`.

## Resultados (cortes 3, 6, 8, 9, 11)

**2007-2025 (n = 19)** — RMSE em % do PIB (MASE vs SRW; p do DM vs SRW)

| Modelo | Corte 3 | Corte 6 | Corte 8 | Corte 9 | Corte 11 |
|---|---|---|---|---|---|
| srw_pib | 0.270 | 0.216 | 0.153 | 0.116 | 0.067 |
| srw_brl | 0.261 | 0.209 | 0.147 | 0.113 | 0.066 |
| m2 | 0.266 (1.08; 0.89) | 0.210 (1.09; 0.83) | 0.144 (1.00; 0.64) | 0.110 (1.01; 0.61) | 0.057 (0.84; 0.40) |
| m3 | 0.273 (1.06; 0.91) | 0.219 (1.07; 0.90) | 0.153 (0.97; 0.99) | 0.110 (0.80; 0.69) | 0.057 (0.84; 0.45) |
| m3_tend | 0.276 (1.09; 0.83) | 0.221 (1.10; 0.88) | 0.140 (0.92; 0.13) | 0.102 (0.79; 0.15) | 0.064 (0.87; 0.85) |
| m3_jan10 | 0.277 (1.11; 0.88) | 0.223 (1.15; 0.89) | 0.137 (0.96; 0.48) | 0.091 (0.72; 0.24) | 0.068 (0.93; 0.95) |
| m3_2eleic | 0.275 (1.06; 0.87) | 0.223 (1.09; 0.79) | 0.156 (1.00; 0.80) | 0.111 (0.79; 0.72) | 0.059 (0.91; 0.58) |

Corte 8: RMSE em R$ bi e acerto de sinal do total anual — srw_pib 13.2 / 0.84; m3 13.5 / 0.95; ME em R$ bi — srw_pib 1.5; m3 6.1.

**2007-2025 sem 2020-22 (n = 16)** — RMSE em % do PIB (MASE vs SRW; p do DM vs SRW)

| Modelo | Corte 3 | Corte 6 | Corte 8 | Corte 9 | Corte 11 |
|---|---|---|---|---|---|
| srw_pib | 0.195 | 0.136 | 0.114 | 0.095 | 0.070 |
| srw_brl | 0.188 | 0.133 | 0.110 | 0.091 | 0.067 |
| m2 | 0.227 (1.20; 0.15) | 0.162 (1.18; 0.18) | 0.124 (1.11; 0.55) | 0.099 (1.10; 0.75) | 0.058 (0.83; 0.41) |
| m3 | 0.235 (1.20; 0.19) | 0.146 (1.03; 0.58) | 0.103 (0.85; 0.48) | 0.058 (0.54; 0.05) | 0.046 (0.72; 0.07) |
| m3_tend | 0.197 (1.05; 0.91) | 0.132 (1.08; 0.79) | 0.100 (0.88; 0.17) | 0.064 (0.66; 0.07) | 0.048 (0.70; 0.14) |
| m3_jan10 | 0.236 (1.27; 0.02) | 0.149 (1.16; 0.38) | 0.104 (0.91; 0.42) | 0.065 (0.64; 0.08) | 0.055 (0.82; 0.22) |
| m3_2eleic | 0.236 (1.20; 0.17) | 0.150 (1.07; 0.47) | 0.105 (0.88; 0.61) | 0.057 (0.53; 0.04) | 0.049 (0.80; 0.12) |

Corte 8: RMSE em R$ bi e acerto de sinal do total anual — srw_pib 8.4 / 0.81; m3 6.7 / 0.94; ME em R$ bi — srw_pib 0.2; m3 3.7.


## Leitura
1. **Com 2020–22 não há ganho em nenhum candidato** (MASE ≈ 1 ou acima nos cortes 1–7; abaixo de 1 em 8–11, sempre com p do DM > 0,1). Sem 2020–22, o `m3` supera o SRW a partir do corte ~8 (corte 8: 0,103 vs 0,114 p.p., −10%, p = 0,48; corte 9: −46% no MAE, p = 0,05; corte 11, p = 0,07) e **perde** nos cortes 1–5 (MASE ≈ 1,2). O ganho é de segunda metade do ano.
2. **Rolante dá menos que a checagem LOO.** Sua checagem (corte ago, 19 anos LOO) deu 0,085 vs 0,106 (−20%); a estimação rolante, que não usa anos futuros no treino, dá −10% e não significativo. A diferença é o esperado do LOO.
3. **O acumulado não é só tendência**, na amostra sem 2020–22 (corte 8, OLS na amostra toda, n = 24): o coeficiente do acumulado é 0,47 (p = 0,002) sem tendência e 0,41 (p = 0,002) com ela; a tendência também é significativa (p = 0,009). A correlação entre o acumulado em % do PIB e o ano é só −0,15. A janela móvel de 10 anos não melhora o `m3`. Ressalva: p-valores de OLS com séries autocorrelacionadas são otimistas. Com 2020–22 o coeficiente do acumulado perde significância (p = 0,44 sem tendência).
4. **Eleição estadual não ajuda**: o coeficiente é ≈ 0 (p = 0,46 sem 2020–22) e o `m2` perde para o SRW nos cortes 1–9 sem 2020–22. A dummy municipal também não melhora (`m3_2eleic` ≈ `m3`).
5. **Normalizar pelo PIB não melhora o SRW**: `srw_brl` ≤ `srw_pib` em todos os cortes das duas amostras.
6. **Viés**: o `m3` erra para cima (ME corte 8 = +3,7 bi sem 2020–22 e +6,1 com), contra +0,2 e +1,5 do SRW. Superestima o superávit; relevante para qualquer número de 2026.
7. **Acerto de sinal** (corte 8): `m3` 0,94 vs `srw_pib` 0,81 (sem 2020–22); 0,95 vs 0,84 (com). É o único indicador em que o `m3` ganha também com 2020–22; com n = 16–19, uma diferença de 2 a 3 anos.
8. **Não é torneio formal.** São 6 modelos × 11 cortes × 2 amostras sem correção de múltiplas comparações: um p = 0,05 isolado não é evidência. Os cortes são dependentes entre si (mesmos anos).

## 2026 (ilustrativo; a escolha vem do backtest, não deste número)
Dados do BCB até agosto (acumulado de 16,2 bi). PIB 2026 aproximado pelo PIB de 12 meses mais recente do SGS 4382 (R$ 13,40 tri), pois `premissas.yml` não está neste ambiente. Total previsto 2026 (R$ bi): `srw_pib` −6,5 (`srw_brl` −5,3); `m3` treinado sem 2020–22 −7,4, com 2020–22 −13,2; `m3_tend` −15,4 / −22,5; `m3_jan10` −18,7 / −24,3. A dispersão entre especificações (−5 a −24) é maior que a diferença de RMSE entre modelos nos backtests, o que é mais um motivo para a regra de seleção ser mecânica por corte. O valor de −20 bi do mercado não entra na avaliação; nenhum candidato razoável bem avaliado o reproduz sem a especificação de tendência.

## Candidato 4 (RREO dos estados: empenhada não paga + RP processados a pagar)
Pendência = (empenhada − paga) da despesa primária total, cumulativa, + saldo de RP processados no bimestre (soma das 27 UFs; `RREO6TotalDespesaPrimaria` inclui RPPS). Alvo: restante do primário **estadual** (SGS 4643) nos cortes m = 2b+1; restante ~ restante(t-1) + pendência (ambos em % do PIB). **Só 2019–2025 (n = 7)**: não cabe estimação rolante com 8 anos de treino; fiz leave-one-out indicativo (`outputs/restante_candidato4_estados.csv`).
- RMSE LOO vs SRW (p.p. do PIB): b1 0,448 vs 0,301; b2 0,419 vs 0,331; b3 0,324 vs 0,251; b4 0,110 vs 0,117; b5 0,100 vs 0,071. Só o bimestre 4 empata; p do coeficiente 0,20 a 0,90.
- A correlação entre a pendência e a "surpresa" do restante (restante − restante do ano anterior) é +0,50 (b1) e +0,45 (b2), com sinal **positivo**, contrário à intuição da hipótese (mais pendência a pagar deveria reduzir o restante). Com n = 7 isso é ruído até prova em contrário.
- Conclusão: **sem sinal utilizável com a amostra atual**; não há como testar de verdade antes de ter mais anos (RREO de caixa de 2015–2017 não é comparável) ou o painel municipal. Limitação adicional: a pendência é um nível persistente (130–200 bi); a variação interanual seria mais coerente com a hipótese e fica como próxima variante. Municípios entram quando a carga terminar.

## Limites
- Denominador = PIB nominal **realizado** do ano t (SGS 4382, dezembro; confere com o IBGE em 2022–2024). Na operação o PIB vem de `premissas.yml`; o erro da projeção do PIB não está no backtest. O SGS 4382 não guarda vintages.
- Mínimo de 8 anos de treino e alvos a partir de 2007 são escolhas minhas; mudar o mínimo altera o conjunto pareado.
- O DM com n = 16–19 e erros possivelmente autocorrelacionados tem pouco poder.
