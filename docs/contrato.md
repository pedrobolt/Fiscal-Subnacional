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
- Métricas: ME (viés), MAE, RMSE, em R$ e % do PIB; MASE relativo ao SRW (MAE / MAE do SRW); acerto de sinal do total anual; teste de Diebold-Mariano (perda quadrática, h = 1, correção de Harvey-Leybourne-Newbold); cobertura dos intervalos. Sem MAPE (o primário cruza zero).

## Protocolo do P1 (E3.3, congelado em 27/10/2026)
Mudança só por PR com justificativa; resultados que dependam de nova regra são reportados como novos.

**Base e lista fechada (K = 9: 1 base + 8 desafiantes).** Base: SRW em R$ (acumulado até o corte + restante do ano anterior, janela 1). Desafiantes: (1) SRW em % do PIB; (2) acumulado j=5; (3) m2 (restante ~ restante(t-1) + eleição estadual, em % do PIB); (4) m3 (restante ~ acumulado + restante(t-1) + eleição, em % do PIB); (5) E4.1, estados e municípios separados; (6) FPE/FPM observáveis; (7) meta da LDO; (8) combinação, média simples com pesos iguais e não estimados de todos os candidatos da lista disponíveis no corte (a base inclusa). Um desdobramento de (5)–(7) em variantes concretas aumenta K e é reportado com os resultados. Ficam **fora** do P1 e são só diagnóstico: ETS, SARIMA, participação sazonal, m3 com tendência, m3 com janela móvel de 10 anos e m3 com dummy de eleição municipal. ARDL e modelos mais ricos foram considerados e excluídos do P1: com 16–19 anos-alvo o poder de avaliação é insuficiente. A previsão atualizada do RREO fica para o P2 (E5).

**Aceitação por faixa de corte** (jan–abr = cortes 1–4; mai–ago = 5–8; set–nov = 9–11), calculada separadamente em cada faixa, para cada desafiante contra a base. Um desafiante é aceito na faixa se cumprir **todas**:
1. RMSE em R$ (erros de todos os cortes e anos-alvo da faixa) pelo menos 10% menor que o da base;
2. erro absoluto médio da faixa menor que o da base em mais de 50% dos anos-alvo;
3. Diebold-Mariano contra a base, sobre a perda quadrática média da faixa por ano-alvo (um teste por desafiante × faixa × amostra), com p ajustado por Holm abaixo de 0,10; a família do Holm em cada faixa inclui só os desafiantes elegíveis (com pelo menos 10 anos-alvo sem 2020–22 nessa faixa), e os apenas reportados não entram na correção;
4. acerto de sinal e viés (|ME|) não piores que os da base.
**Duas amostras:** com e sem 2020–22 (anos fora do treino e do teste). O desafiante é aceito na faixa se cumprir 1–4 sem 2020–22 e, com 2020–22, cumprir 1–4 ou não ficar com RMSE mais de 10% pior que o da base. O desafiante é comparado à base nos anos-alvo em que ambos têm previsão; são necessários pelo menos 10 anos-alvo sem 2020–22, senão o desafiante é só reportado. Candidatos só-BCB usam a amostra longa (anos-alvo desde 2007 para m2/m3, com 8 anos de treino); os que dependem de RREO, FPE/FPM ou LDO usam a amostra em que existem (limitação declarada). A seleção é sempre fora da amostra (estimação rolante); nada é ajustado manualmente. Sem desafiante aceito numa faixa, vale a base nessa faixa. Reportar K e quantos desafiantes têm previsão em cada faixa.

**Regressões (m2, m3).** Os p-valores dos coeficientes usam erro-padrão robusto a autocorrelação (HAC, Newey-West) e servem só como diagnóstico; a seleção não depende deles.

**Intervalos de previsão (E4.2).** Nível de 80%, paramétrico: previsão ± 1,2816 × σ do corte, onde σ é o RMSE do modelo publicado naquele corte, estimado de forma rolante (só anos anteriores ao alvo), suavizado entre cortes vizinhos (pesos 1-2-1 sobre o RMSE², extremos refletidos) e forçado a não crescer com o corte (regressão isotônica). Divulga-se o intervalo do pior caso (σ estimado **com** 2020–22); o de σ sem 2020–22 é mostrado ao lado. Cobertura avaliada fora da amostra por faixa: aceitável se o intervalo de Wilson a 90% da cobertura observada contém 80%.

**P2 (E5).** A comparação de métodos por UF × categoria é ampla e usa teste para muitos modelos (SPA de Hansen ou Model Confidence Set), no lugar do DM.
