# Gate pré-E4 — passeio aleatório sazonal e ganho do RREO (24/10/2026)

Reprodução: `Rscript scripts/gate_sazonal.R [--registrar]` (saídas em `outputs/gate_*.csv`; linhas em `experiments/registro.csv`).
Valores em R$ bi, superávit positivo. Teste simples para medir ganho, **não** é o torneio formal (sem Diebold-Mariano; n pequeno).

## (a) Passeio aleatório sazonal (SRW = `prever_acumulado`, janela 1) no BCB regional (SGS 4642)
SRW = acumulado até o corte + o que se realizou de corte+1..dez no ano anterior. RMSE por corte (dados até o mês m).

| Amostra | Corte 1 | 3 | 6 | 9 | 11 | Leitura |
|---|---|---|---|---|---|---|
| 2016–2025 (n=10): SRW | 27,8 | 26,9 | 22,7 | 12,9 | 7,1 | |
| 2016–2025: acumulado j=5 | 36,2 | 33,7 | 27,7 | 9,8 | 5,4 | |
| 2016–2025: naïve | 27,7 | 27,7 | 27,7 | 27,7 | 27,7 | |
| 2003–2025 (n=23): SRW | 19,9 | 19,2 | 15,9 | 9,1 | 5,1 | |
| 2003–2025: acumulado j=5 | 25,6 | 23,8 | 19,4 | 7,4 | 4,3 | |
| 2003–2015 (n=13): SRW / j=5 | 10,4 / 12,3 | 9,9 / 11,2 | 7,3 / 8,7 | 4,2 / 4,8 | 2,6 / 3,1 | SRW melhor em todos |
| 2016–2019 (n=4): SRW / j=5 | 6,2 / 8,5 | 4,4 / 6,2 | 4,2 / 4,8 | 3,9 / 3,8 | 2,8 / 1,9 | |
| 2020–2025 (n=6): SRW / j=5 | 35,5 / 46,3 | 34,5 / 43,2 | 29,1 / 35,5 | 16,4 / 12,3 | 8,9 / 6,8 | j=5 melhor a partir do corte ~9 |

Leitura: o SRW é melhor ou igual ao j=5 até o corte 6–7 em todas as amostras (a janela longa carrega a média de um regime que muda); depois do corte ~8–9 o j=5 vence nas amostras que incluem 2020–2025. O SRW é praticamente igual ao naïve nos cortes 1–2 (pouca informação do ano) e muito melhor depois. Implicação para a E3.4: o benchmark sazonal é obrigatório e o candidato com janela deve ser avaliado por faixa de corte, não com uma janela única. Erros por subperíodo: ver `outputs/gate_a_srw_bcb.csv`.

## (b) O primário RREO acumulado dos estados melhora a previsão do total anual do BCB?
**Desenho.** RREO (Anexo 6, base caixa, sem RPPS quando separado), soma das 27 UFs, cumulativo até o bimestre b; bimestre b só entra no corte m = 2b+1 (prazo legal + 1 mês, regra conservadora). Comparação pareada (mesmos anos e cortes) contra o SRW:
- `mom_rreo_g`: SRW + g × (variação interanual do RREO acumulado até b); `mom_bcb_g`: o mesmo com a variação do próprio BCB (isola o efeito da fonte); g ∈ {0,5; 1}.
- `ponte_rreo`: RREO acumulado + restante do ano anterior (RREO) + diferença BCB−RREO do ano anterior. Para "regionais", só a parcela estadual usa o RREO; a municipal segue o SRW (não há RREO municipal histórico).

**Amostra efetiva: 2020–2025 (n = 6 por corte).** O RREO de caixa só existe de 2018 (2015–2017 trazem empenhado/liquidado, outro conceito); em 2018 o RS não tem Anexo 6 nos bimestres 1–5 (pendência E2.8); 2019 usa 2018 como base. A amostra inclui 2020–2021.

RMSE (R$ bi), estaduais (SGS 4643):

| Corte | SRW | mom_bcb g=0,5 | mom_rreo g=0,5 | ponte_rreo |
|---|---|---|---|---|
| 3 | 30,0 | 33,4 | 29,7 | 23,8 |
| 6 | 28,3 | 33,7 | 32,7 | 27,5 |
| 9 | 12,7 | 19,0 | 17,2 | 10,6 |
| 11 | 8,3 | 18,8 | 22,0 | 14,9 |

RMSE (R$ bi), regionais (SGS 4642):

| Corte | SRW | mom_bcb g=0,5 | mom_rreo g=0,5 | ponte_rreo |
|---|---|---|---|---|
| 3 | 34,5 | 35,9 | 33,9 | 32,2 |
| 6 | 29,1 | 32,0 | 32,7 | 32,1 |
| 9 | 16,4 | 19,7 | 17,5 | 13,3 |
| 11 | 8,9 | 18,9 | 22,0 | 14,9 |

**Leitura.**
1. Os ajustes de momento (RREO ou BCB) **pioram** o SRW na maioria dos cortes (a exceção são melhoras de até ~2% do `mom_rreo` g=0,5 nos cortes 3–4, dentro do ruído); o RREO não é melhor que o BCB como fonte do ajuste de forma consistente. Sem ganho.
2. Só a `ponte_rreo` reduz o erro, e sobretudo nos estaduais: RMSE 3–22% menor nos cortes 3–7 (4–5 de 6 anos melhor), +64% no corte 8, 4–17% menor nos cortes 9–10 e +80% no corte 11. Nos **regionais** (o alvo P1) o padrão é instável: −7% no corte 3, −5% a +10% nos cortes 4–7, +52% no corte 8, −19% no corte 9, −5% no corte 10, +67% no corte 11. A ponte só muda quando entra um bimestre novo (cortes ímpares), enquanto o SRW incorpora cada mês novo do BCB; por isso ela perde nos cortes 8 e 11 (no 11 o SRW já tem 11 meses do BCB).
3. A diferença anual RREO−BCB dos estados é grande e instável (2018–2025: +16, +33, +27, +46, +5, +21, +27, −10 R$ bi), o que limita a ponte e explica parte do resultado.
4. Estrutural: no corte m, o BCB já cobre os meses que o RREO acumulado até b cobre; o RREO só poderia ajudar por diferença de medida/composição, não por antecedência.

**Limites.** n = 6 (com 2020–2021): o teste não tem poder para detectar ganho moderado nem para afirmar ausência; é evidência de que **não há ganho demonstrado**. Não testa receita/despesa separadas (só o primário), nem municípios.

## Recomendação para a faixa 2 (municípios, bimestres 1–5 de 2023 em diante)
Pela regra do gate, não há ganho demonstrado do primário RREO para o P1, então a faixa 2 **não deve rodar** agora. Dois argumentos adicionais, já fora do teste: (i) a faixa 2 só entregaria 2023–2026 (3 anos completos de bimestres municipais), insuficiente para backtest no protocolo 2016–2025; (ii) o P2 já fica coberto pelo 6º bimestre (anual) e o ganho infra-anual municipal não foi mostrado nos estados. Faixas 0 e 1 ficam como estão. Decisão é do Pedro; reavaliar se o E4 (bottom-up) mostrar potencial.
