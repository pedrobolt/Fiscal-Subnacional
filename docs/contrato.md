# Contrato metodológico

Versão: 20/10/2026. Alterações só com aprovação do Pedro, registradas em `docs/STATUS.md` (seção Decisões).

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
- **Transferências federais (FPE/FPM)**: usar o valor reportado pela STN (o que a União transferiu), não o declarado pelos entes.
- **Valores**: base em R$ correntes. Variação real deflacionada pelo **IPCA mensal, período a período** (cada mês ou bimestre pelo IPCA do próprio período, depois somado). Não usar IPCA dez/dez para fluxos.
- **Unidades de saída**: R$ bilhões e % do PIB.
- **Agregado**: "total das 27 UFs" só quando a cobertura estiver explícita; senão, rotular como parcial.

## Quebras conhecidas (a tratar no E2, nota de quebras)
- 2018: mudança de layout do RREO Anexo 6.
- 2023: separação das fontes do RPPS.
- 2º sem. 2025: RJ, PR e RS reclassificaram despesa de pessoal no RREO (+41% a +75%, sem mudança no RGF). Decisão entre harmonizar e excluir depende da análise.

## Avaliação
- Backtest de **evento fixo**: erro do total anual por mês do cutoff (jan…dez), anos-alvo 2016–2025.
- Informação em tempo real simulada: `available_at` de cada dado; o histórico do BCB é revisado (limitação declarada); snapshots próprios a partir de agora.
- Métricas: ME (viés), MAE, RMSE, em R$ e % do PIB; teste de Diebold-Mariano.
- Regra de aceitação (proposta, a congelar no E3): reduzir o erro em ≥10% frente ao melhor benchmark em ≥70% dos anos-alvo, sem viés sistemático. Em empate, o mais simples.
