# STATUS

Atualizar ao fim de cada tarefa: o que foi feito, comandos executados, saída dos testes, pendências.

## Estado atual
- Etapa: E1
- Próxima tarefa: E1.4 (premissas), após o merge da E1.3; depois E1.5 (fatia mínima com o BCB)

## Concluído
### E1.1 — Estrutura do repositório (23/10/2026, branch `e1.1-estrutura`)
- Pastas conforme `AGENTS.md`; `renv` inicializado (repositório CRAN via Posit Package Manager); `_targets.R` com um alvo de teste (`ambiente`); teste em `tests/test-ambiente.R`.
- Arquivos criados: `AGENTS.md`, `README.md`, `.gitignore`, `premissas.exemplo.yml`, `_targets.R`, `R/ambiente.R`, `tests/test-ambiente.R`, `renv.lock`, `.Rprofile`, `renv/activate.R`, `renv/settings.json`, `docs/` (contrato, plano, STATUS, HANDOVER), `.gitkeep` nas pastas vazias.
- Verificação (ambiente na nuvem, R 4.3.3):
  - `Rscript -e "targets::tar_make()"` → `ended pipeline [1 completed, 0 skipped]`
  - `Rscript -e "testthat::test_dir('tests')"` → `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 4 ]`
- Observações: `Matrix` fixado em 1.6-5 (versões novas exigem R ≥ 4.4); no Linux, o pacote `igraph` (dependência do `targets`) precisa da biblioteca de sistema `libglpk40`.

### E1.3 — Revisão do contrato (23/10/2026, branch `e1.3-contrato`)
- Contrato aprovado pelo Pedro com ajustes (ver Decisões de 23/10/2026); `docs/contrato.md` atualizado para a versão 23/10/2026.

## Pendências abertas
- E2.5: confirmar se o lançamento do FPE/FPM bruto com dedutora do Fundeb vale em todo o período 2015–2025 ou se mudou com o layout de 2018.
- E3.3: discutir o poder estatístico da regra de aceitação. Com 10 anos-alvo, "≥70% dos anos" e Diebold-Mariano são fracos; avaliar agrupar cutoffs por horizonte e reportar com e sem 2020–22.
- E3.6: na ponte RREO × BCB, verificar como o BCB trata os ativos do RPPS, já que o P2 exclui o RPPS.
- E2.8: decisão sobre RJ/PR/RS (harmonizar ou excluir).
- E2.10: meta da LDO disponível pela API?
- E3.3: regra de aceitação a congelar.

## Decisões (com data)
- 23/10/2026 (E1.3): % do PIB usa o PIB nominal anual do ano t como premissa (`premissas.yml`), não o PIB 12 meses do BCB.
- 23/10/2026 (E1.3): FPE/FPM projetado da série da STN (bruto transferido) e convertido ao conceito RREO por fator de ponte (RREO declarado / STN) estimado por UF e esfera; avaliado contra o RREO declarado. Substitui a decisão anterior de usar apenas o valor da STN. Fator instável em alguma UF vira achado de qualidade no E2.
- 23/10/2026 (E1.3): "melhor benchmark" da regra de aceitação refere-se à lista do plano E3.4 (naïve, participação sazonal, ETS, SARIMA, previsão atualizada do RREO).
- 23/10/2026: desenvolvimento pelo GitHub (`pedrobolt/fiscal-subnacional`): uma branch e um pull request por tarefa; revisão e merge pelo Pedro. `premissas.yml` e o Excel final não são versionados (informação interna da CNI).
- 19–20/10/2026: P1 = primário regional conceito BCB; P2 = receitas, despesas e primário RREO; gap sempre explícito.
- Horizonte inicial: ano corrente; t+1 na Fase 2.
- Exceto RPPS; caixa (pago + RP pagos); superávit positivo.
- Deflator: IPCA mensal período a período.
- Municípios: todos, agregados por UF. 20 maiores: Fase 2.
- FPE/FPM: ver decisão de 23/10/2026 (E1.3).
- Stack: R, CRAN, execução local e manual.
- Sem orquestração multiagente; um agente, tarefas pequenas, revisão humana.
