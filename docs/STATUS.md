# STATUS

Atualizar ao fim de cada tarefa: o que foi feito, comandos executados, saída dos testes, pendências.

## Estado atual
- Etapa: E1
- Próxima tarefa: E2.1 (RREO Anexos 1 e 6, estados por UF), após o merge da E1.8 (plano de 5 linhas antes de codar; incluir estimativa e início antecipado do download do RREO municipal)

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

### E1.4 — premissas.yml (23/10/2026, branch `e1.4-premissas`)
- `premissas.exemplo.yml` ganhou `pib_nominal` (R$ bilhões, denominador do % do PIB, conforme o contrato).
- `R/premissas.R`: `ler_premissas(caminho, ano_t)` lê e valida; falha se faltar campo, se o ano t estiver em branco ou se houver erro de unidade (IPCA e PIB real em fração; PIB nominal em R$ bilhões). Anos seguintes podem ficar em branco.
- `tests/test-premissas.R`: 5 testes com arquivos temporários; o `premissas.yml` real não é lido nem versionado.
- Verificação: `Rscript -e "testthat::test_dir('tests')"` → `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 12 ]`; `targets::tar_make()` → pipeline ok.
- Pendente (Pedro): criar o `premissas.yml` local a partir do exemplo, incluindo o PIB nominal de 2026 (planilha federal), e conferir as células de IPCA e PIB real.

### E1.5 — Fatia mínima com o BCB (23/10/2026, branch `e1.5-fatia-bcb`)
- Pipeline: SGS 4642 (primário regional, fluxo mensal) → sinal invertido para superávit positivo e R$ bi → naïve (total do ano anterior) e extrapolação do acumulado (acumulado jan..m + média, nos 5 anos anteriores, do realizado de m+1..dez; forma aditiva porque a razão acumulado/participação explode com total anual perto de zero) → backtest 2016–2025, cutoffs jan–nov → ME/MAE/RMSE por modelo e cutoff → número de 2026 (com % do PIB nominal das premissas).
- Arquivos: `R/download/bcb_sgs.R`, `R/models/fatia_minima.R`, `R/evaluation/backtest_fatia.R`, `_targets.R`, testes `tests/test-bcb_sgs.R` e `tests/test-fatia_minima.R`. Saídas em `outputs/fatia_*.csv` (não versionadas); bruto em `data/raw/` (JSON datado, imutável).
- Ajuste pedido pelo Pedro: `ler_premissas()` agora exige `ano_t` (sem default por `Sys.Date()`), porque em jan/fev rodam-se fechamentos do ano anterior. Leitura do YAML passou a forçar UTF-8 (acento em `fonte` quebrava em locale não UTF-8).
- Verificação: `testthat::test_dir('tests')` → `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 45 ]`; `targets::tar_make()` → `ended pipeline [7 completed, 1 skipped]` (dados do SGS até ago/2026).
- Resultados (R$ bi, superávit positivo; totais anuais do BCB: 2016 4,7; 2019 15,2; 2020 38,7; 2021 97,7; 2022 64,9; 2023 17,7; 2024 5,9; 2025 9,5): naïve MAE 20,2 e RMSE 27,7 (igual em todos os cutoffs); acumulado MAE 28,8 em jan, 24–26 em fev–mai, 11,6 em ago, 4,4 em nov. O acumulado só supera o naïve a partir de jul; antes disso a janela de 5 anos carrega 2020–2022 (superávits atípicos). O ME do naïve é a média de T(t−1)−T(t) sobre 2016–2025, que telescopa para (T2015−T2025)/10; só fica perto de zero porque T2015 (9,7) e T2025 (9,5) são próximos, não por construção. Em outra amostra o viés do naïve não seria ~0. Número de 2026 (cutoff ago): naïve 9,5 (0,07% do PIB) e acumulado 5,4 (0,04% do PIB). É checagem do pipeline, não projeção a usar.
- Limitações declaradas: histórico atual do BCB (revisado), sem `available_at`; % do PIB só para o ano corrente (PIB nominal histórico não está nas premissas; entra na E3); sem benchmarks ETS/SARIMA ainda (E3.4).
- Observações do Pedro sobre a planilha federal: K727 (IPCA 2026) está fixada em 1,0502 e diverge da fonte (B336 = 1,0477); foi usada a B336. O PIB real não está em D728/D736/D744, mas dentro das fórmulas A367:A369 da aba "Receitas e Despesas".

### E1.6 — Ajustes da revisão da E1.5 (23/10/2026, branch `e1.6-ajustes-fatia`)
- Correção da explicação do ME do naïve (ver E1.5).
- Teste de consistência SGS: estaduais (4643) + municipais (4644) = regionais (4642), tolerância de R$ 0,05 milhão (diferença máxima observada: 0,01). Função `checar_soma_regional()` em `R/quality/consistencia_sgs.R`, testes em `tests/test-consistencia_sgs.R` e alvo `consistencia_sgs` no pipeline (falha se divergir).
- Pendências registradas abaixo (E3.4, E3.x, rótulo dos cortes, contrato).

### E1.8 — Ajustes gerais (23/10/2026, branch `e1.8-ajustes-gerais`)
- SGS baixado desde o início disponível (`SGS_INICIO_DOWNLOAD = 1900-01-01`; a API devolve desde o primeiro valor). Primeiras datas: 4642 em 02/1991; 4643 e 4644 em 01/1998. A análise usa a partir de 01/1998 (`SGS_INICIO_ANALISE`): é o período em que as três séries existem e a soma estaduais + municipais = regionais foi verificada (diferença máxima 0,01), e evita 1991–1994 (hiperinflação, outra moeda). `checar_soma_regional()` passou a comparar só as datas em comum.
- Primeiro ano-alvo com janela completa (1998 é o primeiro ano civil completo): **2003** com janela 5, **2001** com janela 3 e **1999** com janela 1 (função `primeiro_ano_alvo()`). A amostra longa vai de 2003 a 2025 (23 anos-alvo) para janela 5. O ~2008 estimado antes era conservador.
- `experiments/registro.csv` iniciado (`registrar_experimento()` em `R/evaluation/registro.R`): naïve e acumulado (janela 5), amostra 2016–2025, por cutoff (dados até o mês m), commit `4ac602c`. 22 linhas.
- `docs/plano.md`: E5.2 (FPE/FPM com fator de ponte), E2.3 (PIB nominal anual histórico pelo IBGE; `premissas.yml` só para anos projetados) e E3.3 (tolerância de erro útil para o informe).
- Verificação: `testthat::test_dir('tests')` → `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 55 ]`; `targets::tar_make()` → `ended pipeline [11 completed, 0 skipped]`; resultados 2016–2025 inalterados.

## Pendências abertas
- E3.3: definir com o Pedro a tolerância de erro útil para o informe (ex.: acertar o sinal, ±0,1% do PIB).
- E3.4: incluir o passeio aleatório sazonal (acumulado do ano + realizado do restante do ano anterior = `prever_acumulado` com `janela = 1`) como benchmark.
- E3 (janela do acumulado): vira parâmetro, conjunto fixo {1, 3, 5} × {com, sem 2020–22}, definido antes de ver resultados. Escolha por seleção aninhada (só anos < ano-alvo), não pelo menor erro do backtest completo.
- Rótulo dos cortes: "dados até o mês m" até existir `available_at` (E3). Aplicar nas tabelas e documentos.
- Contrato, seção Avaliação (aguarda aprovação do Pedro; texto proposto no PR da E1.6): backtest dos candidatos só-BCB em amostra longa (anos-alvo desde o primeiro ano com janela completa, ~2008), com erro por subperíodo; o torneio formal (Diebold-Mariano e regra de aceitação) continua na amostra comum 2016–2025, por causa do RREO.
- E2.5: confirmar se o lançamento do FPE/FPM bruto com dedutora do Fundeb vale em todo o período 2015–2025 ou se mudou com o layout de 2018.
- E3.3: discutir o poder estatístico da regra de aceitação. Com 10 anos-alvo, "≥70% dos anos" e Diebold-Mariano são fracos; avaliar agrupar cutoffs por horizonte e reportar com e sem 2020–22.
- E3.6: na ponte RREO × BCB, verificar como o BCB trata os ativos do RPPS, já que o P2 exclui o RPPS.
- E2.8: decisão sobre RJ/PR/RS (harmonizar ou excluir).
- E2.10: meta da LDO disponível pela API?
- E3.3: regra de aceitação a congelar.

## Decisões (com data)
- 23/10/2026 (E1.7): avaliação dos candidatos só-BCB também em amostra longa (anos-alvo desde o primeiro ano com janela completa), com erro por subperíodo; torneio formal (DM e regra de aceitação) segue na amostra comum 2016–2025, por causa do RREO. Aplicado em `docs/contrato.md`, seção Avaliação.
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
