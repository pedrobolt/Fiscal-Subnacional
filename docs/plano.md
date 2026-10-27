# Plano de implementação — Fase 1 (8 semanas)

Documentação é contínua: toda tarefa atualiza docs/STATUS.md e, quando couber, docs/HANDOVER.md.

Documento completo: documento "Plano de implementação — Previsão Fiscal Subnacional".
Códigos (E1.1 etc.) são usados nos prompts e em `docs/STATUS.md`.

## E1. Preparar o projeto e fazer um primeiro teste (S1)
- E1.1 Repositório R (git, renv, targets, pastas)
- E1.2 AGENTS.md e docs/STATUS.md
- E1.3 Contrato fiscal (docs/contrato.md) — validar com o Pedro
- E1.4 premissas.yml
- E1.5 Fatia mínima: primário regional do BCB → naïve e extrapolação do acumulado → backtest 2016–2025 por mês do cutoff → tabela de erro → número de 2026
Aceite: a fatia roda com um comando, do download ao número.

## E2. Montar e conferir a base de dados (S2–S3)
- E2.1 RREO Anexos 1 e 6: estados por UF
- E2.2 RREO Anexos 1 e 6: municípios agregados por UF, imputação documentada
- E2.3 BCB/SGS, transferências da STN, IPCA, PIB nominal anual histórico pelo IBGE (para % do PIB no backtest; `premissas.yml` só para anos projetados)
- E2.4 Snapshots imutáveis e base canônica com available_at
- E2.5 Dicionário de contas por layout (2015–17, 2018–22, 2023+)
- E2.6 Testes automáticos (duplicidade, ausente vs zero, acumulado → fluxo, identidades, cobertura)
- E2.7 Pesquisa: defasagem real de publicação do RREO → regra de available_at
- E2.8 Pesquisa: nota de quebras (2018, RPPS 2023, RJ/PR/RS 2025) — validar com o Pedro
- E2.9 Conferência manual de amostra contra demonstrativos oficiais
- E2.10 Verificar se a meta de primário da LDO vem no RREO Anexo 6
Aceite: base reconstruída do zero com um comando; nota de quebras validada.

## E3. Definir como avaliar as projeções (S3–S4)
- E3.1 Backtest de evento fixo (cutoffs mensais BCB e bimestrais RREO)
- E3.2 Métricas e teste de Diebold-Mariano
- E3.3 Regra de aceitação escrita e congelada — validar com o Pedro (bloqueia E4 em diante). Sem tolerância de erro externa: o critério é relativo ao benchmark (decisão de 27/10/2026, registrada no contrato)
- E3.4 Benchmarks: naïve, participação sazonal, ETS, SARIMA, previsão atualizada do RREO (Anexo 1)
- E3.5 Viés das metas da LDO, rolante (se a meta vier pela API)
- E3.6 Série do gap RREO × BCB e candidatos simples para prevê-lo
- E3.7 Teste automático de vazamento e registro de experimentos
Aceite: teste de vazamento passa; protocolo aprovado.

## E4. Projetar o resultado fiscal dos governos regionais — P1 (S5)
- E4.1 Torneio: total direto; estados + municípios; bottom-up + gap; combinações; LDO corrigida
- E4.2 Intervalos de previsão
- E4.3 Documentar modelo escolhido e justificativa
Aceite: cumpre a regra do E3; senão, fica o melhor benchmark.

## E5. Projetar receitas e despesas — P2 (S6)
- E5.1 Categorias: receita corrente, ICMS, IPVA, ISS, FPE/FPM, demais (IPTU incluído), pessoal, custeio, investimento
- E5.2 FPE/FPM: projeção pela STN, convertida ao conceito RREO por fator de ponte; avaliado contra o RREO declarado (contrato 23/10)
- E5.3 Resultado RREO (estados, municípios, total), variação real e contribuição de cada item
Aceite: cada categoria usa o candidato vencedor no backtest, nem que seja o benchmark.

## E6. Rodar o modelo e entregar a planilha final (S6)
- E6.1 Comando único (baixar → validar → projetar → exportar)
- E6.2 Excel final: P1, P2, gap, linha "Regionais", candidato de origem de cada número
- E6.3 Arquivo de previsões emitidas
- E6.4 Primeira rodada oficial — validar com o Pedro

## E7. Avaliar, melhorar e documentar (S7–S8)
- E7.1 Gate: tabela de erro → no máximo um item da Fase 2
- E7.2 Implementar e validar o item escolhido
- E7.3 Nota metodológica
- E7.4 Checklist e playbook da rodada mensal
- E7.5 Completar o HANDOVER (dados, decisões, como rodar, problemas conhecidos)
Aceite: todo o processo está documentado no HANDOVER, na nota metodológica e no playbook.

## Fase 2 (posterior; cada item só entra pelo gate)
Viés da LDO via PDFs · Rigidez orçamentária · Elasticidade do ICMS · Ano t+1 e cenários ·
Hierárquico/pooling/clusters · 20 maiores municípios · Ponte RREO × BCB completa ·
Projeto à parte: dinâmica da dívida (DCL/RCL).
