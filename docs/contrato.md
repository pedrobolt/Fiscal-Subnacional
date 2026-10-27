# Contrato metodológico

Versão: 23/10/2026 (seção Avaliação ampliada no mesmo dia). Alterações só com aprovação do Pedro, registradas em `docs/STATUS.md` (seção Decisões).

## Produtos
| Produto | Alvo | Fonte | Avaliado contra |
|---|---|---|---|
| P1 | Resultado primário anual dos governos regionais (estados + municípios), conceito BCB | BCB/SGS (NFSP, fluxo mensal: regionais, estaduais, municipais) | Primário publicado pelo BCB |
| P2 | Receitas, despesas e resultado primário anual, conceito RREO | Siconfi/RREO (Anexos 1 e 6) | RREO realizado |

- Horizonte inicial: **ano corrente (t)**, revisado a cada nova divulgação. t+1 fica para a Fase 2.
- P1: o número final vem do candidato que vencer o backtest (previsão direta do BCB, estados + municípios somados, bottom-up RREO + gap, ou combinação).
- P2: estados (agregado e por UF) e municípios (agregados por UF). Panorama dos 20 maiores municípios fica para a Fase 2.

## Conceitos
- **Sinal**: superávit positivo, déficit negativo.
- **Estágio da despesa**: caixa = despesa paga + restos a pagar pagos. Empenho e liquidação são preservados, mas não são alvo.
- **RPPS**: receitas e despesas primárias **exceto fontes do RPPS** (como no Anexo 6).
- **Primário**: juros, amortizações e operações de crédito ficam fora.
- **FPE/FPM**: projetado a partir da série da STN (valor bruto transferido), convertido ao conceito RREO por fator de ponte (RREO declarado / STN), estimado no histórico por UF e esfera; avaliado contra o RREO declarado. A ponte cobre bruto vs. líquido do Fundeb, timing de decêndios e cobertura de entes. Se o fator for instável em alguma UF, sinalizar como achado de qualidade no E2.
- **Valores**: base em R$ correntes. Variação real deflacionada pelo **IPCA mensal, período a período** (cada mês ou bimestre pelo IPCA do próprio período, depois somado). Não usar IPCA dez/dez para fluxos.
- **Unidades de saída**: R$ bilhões e % do PIB. O denominador do % do PIB é o PIB nominal anual do ano t, tratado como premissa (`premissas.yml`). Não usar o PIB acumulado em 12 meses do BCB.
- **Agregado**: "total das 27 UFs" só quando a cobertura estiver explícita; senão, rotular como parcial.

## Quebras conhecidas (a tratar no E2, nota de quebras)
- 2018: mudança de layout do RREO Anexo 6.
- 2023: separação das fontes do RPPS.
- 2º sem. 2025: RJ, PR e RS reclassificaram despesa de pessoal no RREO (+41% a +75%, sem mudança no RGF). Decisão entre harmonizar e excluir depende da análise.

## Avaliação
- Backtest de **evento fixo**: erro do total anual por mês do cutoff (jan…dez), anos-alvo 2016–2025.
- Informação em tempo real simulada: `available_at` de cada dado; o histórico do BCB é revisado (limitação declarada); snapshots próprios a partir de agora.
- **RREO: versão dos valores.** Os valores usados são a versão mais recente (retificada) de cada demonstrativo, análoga à revisão do histórico do BCB (limitação declarada).
- **RREO: `available_at`** (fonte: `extrato_entregas` do Siconfi, que guarda só o último status de cada ente × ano × período). Demonstrativo homologado (HO): `available_at` = `data_status`. Demonstrativo retificado (RE): a primeira entrega não é observável, e usar o prazo legal puro (fim do bimestre + 30 dias) vazaria informação; `available_at` = prazo legal + atraso mediano dos homologados da mesma UF × período. Para entes sem homologados na mesma UF × período, usar a mediana do período no país (registrar como achado). A defasagem mediana por UF × período é calculada na E2.7.
- Amostras: os candidatos só-BCB também são avaliados em amostra longa (anos-alvo desde o primeiro ano com janela completa), com erro reportado por subperíodo. O torneio formal (Diebold-Mariano e regra de aceitação) permanece na amostra comum 2016–2025, por causa do RREO.
- Métricas: ME (viés), MAE, RMSE, em R$ e % do PIB; teste de Diebold-Mariano.
- **Sem tolerância de erro externa.** Não há faixa de erro "aceitável" em valor absoluto nem exigência de acertar o sinal como condição de aceitação (o acerto de sinal é só uma métrica reportada). O critério de aceitação é exclusivamente relativo ao benchmark.
- Regra de aceitação (proposta, a congelar no E3): reduzir o erro em ≥10% frente ao melhor benchmark (da lista do plano E3.4: naïve, participação sazonal, ETS, SARIMA e previsão atualizada do RREO) em ≥70% dos anos-alvo, sem viés sistemático. Em empate, o mais simples.
