# STATUS

Atualizar ao fim de cada tarefa: o que foi feito, comandos executados, saída dos testes, pendências.

## Estado atual
- Etapa: E1
- Próxima tarefa: decisão do Pedro sobre a recomendação da E2.0 (censo completo) e ordem da carga histórica; depois E2.2

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

### E2.1 — RREO Anexos 1 e 6, estados (23/10/2026, branch `e2.1-rreo-estados`)
- `R/download/siconfi_rreo.R`: `baixar_rreo()` (um ente × ano × bimestre × anexo; 1 conexão; novas tentativas; JSON compactado `.json.gz` em `data/raw/rreo/<esfera>/<ano>/`, imutável e retomável; resposta vazia só é guardada para exercícios encerrados; log por chamada em `data/raw/rreo/_log.csv`), `ler_rreo()` (formato longo, sem somar nem reclassificar), `baixar_rreo_estados()`. Reaproveitável na E2.0 (municípios).
- `R/transform/rreo.R`, `R/quality/cobertura_rreo.R`; alvos `rreo_estados` e `cobertura_estados` no pipeline (leem o bruto local; o download é fora do pipeline: `Rscript -e 'source("_targets.R"); baixar_rreo_estados()'`).
- Download: 27 entes (26 estados + DF) × 2015–2026 × bimestres publicados × Anexos 1 e 6 = **3.780 chamadas, 0 erros, mediana 1,07 s por chamada** (1 conexão, ~1,2 h). Bruto: 34 MB compactado. Sem paginação (máx. ~700 linhas por chamada).
- Cobertura: 3.775 de 3.780 demonstrativos com dados. Os 5 vazios são o **Rio Grande do Sul (43), Anexo 6, 2018, bimestres 1–5** (o 6º existe). Achado de qualidade: **causa a investigar no E2.8** (a mudança de layout de 2018 valeu para todos os entes e só o RS veio vazio, então não se atribui ao layout). O agregado estadual desses bimestres é rotulado como **parcial** (26 de 27 UFs no Anexo 6); ausência tratada como ausência, nunca zero.
- Tabela longa: 1.383.117 linhas, 27 entes, 2015–2026.
- Verificação: `testthat::test_dir('tests')` → `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 74 ]`; `targets::tar_make()` → pipeline concluído.
- Pendente: `available_at` (E2.7) e política de snapshots/retificações (E2.4).

### E2.0 — Piloto do RREO municipal (23/10/2026, branch `e2.0-piloto-municipal`)
- Relatório completo: `docs/relatorio_e2_0.md`. Código: `R/download/siconfi_rreo.R` (tentativa `RREO` e depois `RREO Simplificado`; gravação atômica; `validar_rreo_pasta()`), `R/evaluation/cobertura_municipal.R`, `R/quality/manifesto.R`, `scripts/` (coleta, curvas, amostra do extrato, empacotar/restaurar).
- Amostras (tamanhos exatos): exploratória de **8** municípios (descobriu o Simplificado); piloto A **200** municípios (1 conexão, 273 chamadas, 0 erros, 0,85/s); piloto B **200** outros municípios, sem sobreposição com A (2 conexões, 287 chamadas, 1 erro transitório, ~1,7/s); coleta completa 2025 e 2019 (6º bimestre, Anexos 1 e 6): **26.089 chamadas em 5,0 h ativas = 1,44/s**, 7 erros transitórios; amostra do extrato: **120** Simplificados por ano (2025 e 2019).
- Resultados: 5.526 (2025) e 5.539 (2019) municípios com dados; sem dados: 43 (0,61% da população) e 30 (0,18%). Simplificado: 2.294 (41%) em 2025 e 2.067 (37%) em 2019; **entrega os seis bimestres** (119/120 em cada ano), logo **não há ausência estrutural em b1, b2, b4, b5** (a hipótese de imputação separada por ausência estrutural foi descartada; resta verificar contas do Simplificado por UF). Para 80% da receita municipal: 1.967 municípios por UF (2025), 1.814 (2019); ranking estável (~92% de sobreposição).
- **Recomendação: censo completo** (expansão dos grandes deixa erro de R$ 0,7–7,6 bi no agregado com sinal instável contra primário regional do BCB de R$ 9,5–15,2 bi; custo por bimestre 2,5 h contra 0,9 h). Carga inicial do censo 2015–2026 ≈ 913 mil chamadas ≈ 7,3 dias; começar pelo 6º bimestre de todos os anos (~1,2 dia). A aprovar pelo Pedro.
- `extrato_entregas`: dá `tipo_relatorio` (P/S) e `data_status` por ente × ano × período, **mas só o último status** (HO homologado / RE retificado); sem histórico. 10,6% (2025) e 6,4% (2019) das linhas do RREO amostradas estavam retificadas. `available_at` (E2.7) = `data_status` quando HO; quando RE, só limite superior: usar a data legal (fim do bimestre + 30 dias) como proxy e registrar a limitação. Valores usados são a **versão mais recente (retificada)**, análogo à revisão do BCB.
- Verificação: `testthat::test_dir('tests')` → `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 105 ]`; validação de todos os arquivos do bruto: 0 inválidos.
- Armazenamento do bruto: GitHub Release `dados-rreo-20261023` (ver HANDOVER 3b). **Pendente do Pedro:** a criação de Releases foi negada (HTTP 403) para a sessão de desenvolvimento. Pacote (`rreo_bruto_20261023.tar.gz`, 124 MB, 30.421 arquivos, 0 inválidos) e manifesto (`.csv` e `.json`) foram gerados e enviados ao Pedro; criar o Release com tag `dados-rreo-20261023`, alvo = commit `621a830`, anexando os três arquivos. Manifesto: contagem estados 324 por ano (216 em 2026), municípios 13.207 (2019) e 13.434 (2025), coleta de 23/10/2026 11:54 a 21:50.

## Pendências abertas
- Contrato (PR próprio, a aprovar): registrar que os valores do RREO são a versão mais recente (retificada) e a regra do `available_at` (HO: `data_status`; RE: proxy legal).
- E2.2: verificar contas do Simplificado por UF (MS, MG, RS, PR, MA, ES têm 34–48% da receita no grupo); validar extração do primário municipal (layout 2019 × 2025; 22 e 135 municípios sem primário).
- E2.7: medir a fração de retificações e a defasagem de entrega com o extrato completo (~5,6 mil chamadas por ano).
- Carga inicial do censo histórico municipal (decisão do Pedro sobre a ordem: 6º bimestre de todos os anos primeiro).
- E2.8: investigar a causa do RS, Anexo 6, 2018 b1–b5 vazio e decidir o tratamento (o agregado estadual desses bimestres fica rotulado como parcial; o 6º bimestre existe e cobre o total anual).
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
