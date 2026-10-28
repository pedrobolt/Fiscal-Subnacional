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
- Resultados: 5.526 (2025) e 5.539 (2019) municípios com dados; sem dados: 43 (0,61% da população) e 30 (0,18%). Simplificado: 2.294 (41%) em 2025 e 2.067 (37%) em 2019; **entrega os seis bimestres** (119/120 em cada ano), logo **a hipótese de ausência estrutural em b1, b2, b4 e b5 foi refutada** (119/120 entregam 6 bimestres em cada ano); não há imputação separada por esse motivo, e resta verificar as contas do Simplificado por UF. Para 80% da receita municipal: 1.967 municípios por UF (2025), 1.814 (2019); ranking estável (~92% de sobreposição).
- **Decisão (Pedro, 24/10/2026): censo completo.** Apoia-se no custo aceitável (~2,5 h por bimestre, ~13 mil chamadas) e na eliminação da camada de expansão. Carga histórica: 6º bimestre de todos os anos primeiro; depois demais bimestres do mais recente para o mais antigo (2023 em diante primeiro); ≈ 772 mil chamadas ≈ 6,2 dias de API. Onde rodar: a decidir pelo Pedro.
- `extrato_entregas`: dá `tipo_relatorio` (P/S) e `data_status` por ente × ano × período, **mas só o último status** (HO homologado / RE retificado); sem histórico. 10,6% (2025) e 6,4% (2019) das linhas do RREO amostradas estavam retificadas. `available_at` (E2.7) = `data_status` quando HO; quando RE, a primeira entrega não é observável: `available_at` = prazo legal (fim do bimestre + 30 dias) + atraso mediano dos homologados da mesma UF × período (regra aprovada em 24/10/2026; o prazo legal puro vazaria informação). Valores usados são a **versão mais recente (retificada)**, análogo à revisão do BCB.
- Verificação: `testthat::test_dir('tests')` → `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 105 ]`; validação de todos os arquivos do bruto: 0 inválidos.
- Armazenamento do bruto: GitHub Release `dados-rreo-20261023` (https://github.com/pedrobolt/Fiscal-Subnacional/releases/tag/dados-rreo-20261023), publicado pelo Pedro em 24/10/2026 com o pacote `rreo_bruto_20261023.tar.gz` (124 MB, 30.421 arquivos .json.gz) e o manifesto (`.csv` e `.json`). A tag aponta para `main` (2db75f3), não para o commit que gerou os dados; a procedência está no manifesto (`commit_codigo` = 621a830). **Restauração testada em 24/10/2026** numa cópia limpa do código: download do Release + `scripts/restaurar_dados.R` → 30.428 arquivos no manifesto, 0 ausentes, 0 com MD5 diferente, 32 s. Contagens do manifesto: estados 324 arquivos por ano (216 em 2026); municípios 13.207 (2019) e 13.434 (2025); coleta de 23/10/2026 11:54 a 21:50.

### E2.4 — Snapshots e atualização guiada pelo extrato (24/10/2026, branch `e2.4-snapshots-extrato`)
- Corrige a regra "arquivo existente nunca é rebaixado", que conflitava com o contrato (versão mais recente/retificada). Agora: arquivo existente **nunca é sobrescrito**; retificação entra como snapshot novo `..._s<AAAAMMDDTHHMMSSZ>.json.gz` (UTC) e a **versão vigente é a mais recente** (a original, sem sufixo, tem como data a do arquivo). `R/download/snapshots.R`.
- `extrato_entregas` por ente × ano, também em snapshots (`data/raw/rreo/extrato/<ano>/<ente>_s<carimbo>.json.gz`, acumula o histórico a partir de agora). `R/download/extrato.R`: `baixar_extrato()`, `extrato_vigente()`, `ler_extrato()` (só RREO, com tipo RREO/Simplificado, status HO/RE e `data_status` em UTC).
- `planejar_jobs()` / `atualizar_rreo()` (`R/download/atualizacao_rreo.R`): compara `data_status` com a data da versão local; motivos: `novo`, `retificado` (rebaixa como snapshot), `vazio_com_entrega` (arquivo local vazio e entrega posterior a ele: entrega atrasada). Arquivo vazio com entrega anterior à consulta não é refeito (o anexo não existe), mas o extrato é renovado a cada rodada (padrão: reaproveita se tiver até 7 dias), então vazios de anos encerrados voltam sempre à verificação. O tipo (RREO ou Simplificado) vem do extrato, o que elimina a chamada vazia.
- E2.2: `cobertura_rreo()` reconhece o Simplificado e separa `vazios`, `nao_tentado` (Anexo 6 sem arquivo porque o Anexo 1 está vazio/ausente) e `sem_arquivo`; `ler_rreo_pasta()` lê só a versão vigente e acrescenta `tipo_demonstrativo`, `arquivo` e `baixado_em`.
- Teste ao vivo (cópia de um arquivo do SP com data antiga): retificação do 6º bimestre de 2025 detectada (RE em 16/04/2026 > arquivo de 01/04/2026) → snapshot novo; Anexo 6 ausente → baixado como `novo`; extrato salvo como snapshot.
- Verificação: `testthat::test_dir('tests')` → `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 129 ]`; `targets::tar_make()` ok, estados inalterados (3.775 de 3.780 com dados; 5 vazios do RS, Anexo 6, 2018; 0 não tentados; 0 sem arquivo).
- (Superada pela E2.4b: a data da original agora vem do log, não do mtime.)

### E2.4b — Carga histórica em faixas (24/10/2026, branch `e2.5-carga-historica`, empilhada sobre a E2.4)
- `R/download/carga_historica.R` (faixas, trava por fatia, `executar_carga()`, `progresso_carga()`), `scripts/carga_historica.R <1|2>` e `scripts/carga_historica_progresso.R`. Dois processos fixos (2 conexões; `de != 2` é recusado), retomada automática, falha de rede num ente × ano é registrada em `_erros_carga<N>.csv` e não derruba a rodada, instruções para Windows no HANDOVER 3c.
- Faixas: estados; municípios 6º bimestre 2025→2015; municípios bimestres 1–5 de 2026→2023. Estimativa: ~378 mil chamadas (extrato ~67 mil + RREO ~311 mil) ≈ 73 h ≈ 3 dias a 1,44/s (acima dos ~2,5 dias previstos por incluir o extrato de todos os anos, que também alimenta o `available_at`).
- **Não executada**: aguarda a aprovação e o merge da E2.4. Não testada em Windows (código usa `file.path`, `download.file(method = "libcurl")`, gravação atômica por `file.rename`).
- Verificação: `testthat::test_dir('tests')` → `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 144 ]`.

### Gate pré-E4 (24/10/2026, branch `e3.4a-gate-sazonal`)
- (a) SRW (`prever_acumulado`, janela 1) no BCB regional, 2016–2025 e amostra longa 2003–2025 por subperíodo, registrado em `experiments/registro.csv` (`outputs/gate_a_srw_bcb.csv`). SRW ≥ acumulado j=5 até o corte ~6–7 em todas as amostras; j=5 vence nos cortes 9–11 nas amostras com 2020–2025.
- (b) Primário RREO dos estados vs BCB (estaduais e regionais), amostra pareada efetiva 2020–2025 (n=6): sem ganho demonstrado para o P1; só a ponte RREO→BCB ajuda nos estaduais e de forma instável nos regionais. Detalhes e limites em `docs/relatorio_gate.md`.
- **Decisões do Pedro (24/10/2026)**: sem ganho demonstrado do RREO agregado para o P1. O bottom-up continua no torneio do E4 (custo baixo; o RREO existe pelo P2), mas o esforço principal vai para candidatos só-BCB (SRW/acumulado por faixa de corte, LDO). Hipótese ainda não testada: a composição do RREO (ICMS, pessoal) prevê o restante do ano.
- **Faixa 2 da carga roda** (municípios, bimestres 1–5 de 2023+), pelo P2: o acumulado intra-anual de 2026 (b1–b4) e 2023–2025 estimam o restante do ano na operação, não pelo P1.
- Descobertas: Anexo 6 de caixa só a partir de 2018 (2015–2017 = empenhado/liquidado); RS 2018 sem Anexo 6 nos bimestres 1–5 (E2.8); 2018–2022 `RREO6ResultadoPrimarioEstadosMunicipios` (coluna "VALOR INCORRIDO" ou "VALOR"), 2023+ `ResultadoPrimarioSemRPPSAcimaDaLinha`; tratamento de RPPS em 2018–2022 não verificado (E3.6).
- Arquivos: `R/evaluation/gate_rreo.R`, `scripts/gate_sazonal.R`, `tests/test-gate_rreo.R`, `docs/relatorio_gate.md`, `experiments/registro.csv`.

### E2.4b — Data da versão original (24/10/2026, branch `e2.4b-data-original`)
- A data da versão original deixou de vir do mtime (muda ao copiar, extrair no Windows ou restaurar do Release). Agora é o primeiro registro `ok` do demonstrativo nos `_log*.csv` (que viajam no Release); snapshots seguem usando o carimbo UTC do nome. Sem registro no log, cai no mtime e a coluna `baixado_em_fonte` de `ler_rreo_pasta()` marca `mtime`.
- Logs novos gravam `momento` em UTC com "Z"; logs antigos (hora local sem fuso, gerados na nuvem) são lidos como America/Sao_Paulo. Premissa a conferir: todos os logs antigos vieram desse ambiente.
- Dados reais: 30.421 arquivos, todos com data pelo log (0 por mtime).
- Funções: `momentos_originais()`, `datas_versoes()`, `chave_arquivo()`, `momento_log_numerico()` em `R/download/snapshots.R`; `versoes_rreo()` ganhou coluna `fonte`; `arquivo_vigente()` não depende mais de datas de arquivo. 4 testes novos (151 passam).
- Renomeação: a carga histórica passa a se chamar E2.4b (E2.5 = dicionário de contas por layout, conforme `docs/plano.md`).

### E3.4/E4 — Candidatos do restante do ano em % do PIB (27/10/2026, branch `e3.4b-candidatos-restante`)
- E2.3 (parcial; ver a entrada E2.3): o PIB passou a vir do IBGE; a primeira versão usou o SGS 4382, que o contrato veda (impacto nos resultados ≤ 0,0001 p.p.).
- Candidatos 1–3 (+ `m3_tend`, `m3_jan10`, `m3_2eleic`) com estimação rolante, com e sem 2020–22; métricas ME/MAE/RMSE (R$ e % do PIB), MASE vs SRW, DM, acerto de sinal. Registrados em `experiments/registro.csv` (amostras "2007-2025" e "2007-2025 sem 2020-22").
- Resultado: sem 2020–22, o `m3` ganha do SRW só a partir do corte ~8 (não significativo no corte 8); com 2020–22, nenhum ganho. Eleição estadual sem efeito. Acumulado não é só tendência. O `m3` tem viés positivo (+3,7 bi no corte 8).
- Candidato 4 (RREO estados): n = 7, sem sinal utilizável; municípios após a carga. Relatório: `docs/relatorio_candidatos_restante.md`.
- Arquivos: `R/models/candidatos_restante.R`, `R/models/candidato_pendencias_rreo.R`, `scripts/candidatos_restante.R`, `tests/test-candidatos_restante.R`, (a função `pib_anual` do SGS 4382 foi removida na E2.3).

### Decisões após os candidatos do restante (27/10/2026)
1. **Candidato-base do P1: SRW em R$.** O modelo 3 (restante ~ acumulado + restante(t-1) + eleição, em % do PIB) só será adotado, e só para cortes ≥ 9, se passar na regra de aceitação do E3.3, considerando o viés positivo (ME +3,7 bi no corte 8 sem 2020–22).
2. **Fim da busca de candidatos que remodelam a mesma série** (comparações múltiplas). Novos candidatos só com informação nova: estados e municípios separados (E4.1), receitas já observáveis (FPE/FPM) e meta da LDO (E3.5). Candidato 4 (pendências do RREO): uma única variante, a variação interanual da pendência, quando os municípios entrarem na base; depois, encerrar.
3. **Prioridade: E4.2**, intervalos de previsão por corte a partir dos erros históricos do SRW, com cobertura avaliada.
4. **Limitação registrada:** o backtest em % do PIB usa o PIB realizado do ano t, que não é conhecido no corte; em produção o denominador vem do `premissas.yml`. O erro de projeção do PIB não está nos resultados em % do PIB.

### E2.3 — PIB nominal do IBGE e transferências da STN (27/10/2026, branch `e2.3-pib-ibge-stn`)
- **PIB (feito):** `R/download/ibge_pib.R` baixa do SIDRA a tabela 6784 (v9808, anual 1996–2023) e a 1846 (v585, trimestral); `pib_ibge_anual()` usa a anual e completa com a soma de quatro trimestres (2024 e 2025). Comparado com o SGS 4382: diferença máxima 0,11% (1998–2025), nula em 2022–2025. `pib_ultimos_4_trimestres()` serve só para ilustrar o ano corrente sem `premissas.yml`. `scripts/candidatos_restante.R` passou a usar o IBGE; resultados do backtest praticamente idênticos (≤ 0,0001 p.p.). Erro meu corrigido: a frase "confere com o IBGE" do relatório anterior não tinha sido conferida; agora foi.
- **STN FPE/FPM (pendente de rodar):** `R/download/stn_transferencias.R` (`recursos_stn()`, `baixar_stn()`) lê a lista de arquivos no CKAN do Tesouro Transparente (estados: 1997–2015, jan–jul/2016 e mensais desde 08/2016; municípios idem) e baixa com pausa, respeitando o `Retry-After`. Neste ambiente o servidor respondeu HTTP 429 a todos os pedidos de arquivo (mesmo após esperar), então **nenhum arquivo da STN foi baixado**; não insisti. Rodar na máquina do Pedro (HANDOVER 3e).
- Falta: leitura/validação dos CSVs da STN (colunas, FPE por UF, FPM por município e UF), série mensal de FPE/FPM e fator de ponte (depende do RREO municipal para o FPM); IPCA do SGS.

### E3.7 — Teste de vazamento e registro de experimentos (27/10/2026, branch `e3.7-vazamento-registro`)
- **Data de corte (decisão do Pedro):** a de divulgação do BCB do mês m. `data_divulgacao_bcb()` usa um calendário real se for fornecido (data.frame ano, mes, data); senão, aproximação documentada: último dia útil (seg–sex, sem feriados) do mês seguinte, podendo errar 1–2 dias por feriado. O BCB continua "dados até o mês m"; RREO, STN e LDO entram só com `available_at <= data de corte` (`montar_info()`).
- **Teste de perturbação** (`tests/test-vazamento.R`): altera BCB depois do mês m, PIB de anos > t e linhas de RREO/STN/LDO com `available_at` depois do corte; as previsões dos 5 candidatos implementados (SRW em R$, SRW em % do PIB, acumulado j=5, m2, m3, via `R/models/candidatos_p1.R`) não mudam. Um oráculo de controle, alimentado por `montar_info_vazado()`, é reprovado pelo teste. Os adaptadores reproduzem os números do backtest rolante. Limitação declarada no teste: o PIB do ano t é o realizado.
- **`available_at` provisório do RREO** (`available_at_rreo()`): HO = `data_status`; RE = prazo legal + mediana do atraso dos HO da mesma UF × período (reserva: mediana nacional do período). Falha de forma explícita sem o extrato. **Rodado com dados reais (27/10/2026)**: extrato dos 27 estados, 2015–2026 (324 chamadas, 1 conexão, 0 falhas; `scripts/extrato_estados.R`), e `scripts/testar_available_at.R` → `outputs/available_at_rreo_estados.csv`. Resultado: 1.890 entregas do RREO (1.580 HO, 310 RE); nenhum `available_at` anterior ao fim do bimestre (mínimo 18 dias depois). A mediana do atraso dos HO em relação ao prazo legal é 0 dia em todos os períodos, e 9% a 25% deles chegam depois do prazo (p90 do atraso: 7,7 dias no 1º bimestre; 5,4 no 6º). Para os RE, `available_at` cai em geral no prazo legal (22 casos usaram a mediana nacional). No 6º bimestre, 172 de 297 entregas (58%) estão como RE, o que torna a regra de `available_at` dos retificados especialmente relevante nesse período; a defasagem completa fica para a E2.7. Limite: o extrato guarda só o último status, então um HO pode ser uma re-homologação posterior (o que atrasa, nunca antecipa, o `available_at`).
- **Registro:** coluna `status` (valido / diagnostico / obsoleto_pib4382), `validar_registro()` (colunas, status, candidato valido dentro da lista, amostra, corte, métricas, duplicatas, commit existente no git) e `status_candidato()`; K = 9 em `K_P1`. Linhas antigas marcadas por `scripts/marcar_status_registro.R` sem apagar nenhuma (conteúdo anterior preservado; 450 linhas). Linhas de `srw_pib`, `m2` e `m3` com o PIB do SGS 4382 (commit 96645c6) ficaram `obsoleto_pib4382`; os mesmos candidatos foram registrados de novo com o PIB do IBGE.
- Pendente: os candidatos E4.1, FPE/FPM, LDO e combinação entram no teste quando forem implementados; usar `CANDIDATOS_P1` como interface.

### E4.1 — Candidatos por componente e combinação (27/10/2026, branch `e4.1-candidatos-componentes`)
- Definição registrada no contrato antes do backtest: E4.1 = m3 por componente (estados com dummy de eleição estadual, municípios com dummy de eleição municipal); combinação = média simples dos candidatos disponíveis; variantes (`diag_e41_est_m3`, `diag_e41_mun_m3`) só diagnóstico, fora da lista.
- Previsões fora da amostra via `montar_info` (teste de vazamento cobre os 9 modelos), alvos 2007–2025, com e sem 2020–22; `scripts/e41_previsoes.R`; 54 linhas por amostra em `experiments/registro.csv`, validadas.
- RMSE médio por faixa vs SRW em R$ (sem 2020–22; ainda sem DM/Holm nem regra de aceitação, que é o torneio do E4): E4.1 +42% (cortes 1–4), +30% (5–8), −20% (9–11); m3 regional +29%, +12%, −41%; combinação +19%, +12%, −25%. Leitura preliminar: nos cortes 9–11 o m3 regional supera o E4.1 por componente, então a decomposição não agregou; as variantes mostram que o pior vem dos estados. A decisão é do torneio.
- Observação de proveniência: as previsões foram geradas antes de um commit que apenas tornou explícita a fórmula do m3 estadual (mesma fórmula, `r ~ a + r_lag + E`); o hash no registro é o desse commit.
- Limitação mantida: PIB realizado no backtest.

### E2.3 / E4.1b — STN (FPE/FPM) e candidato fpe_fpm (27/10/2026, branch `e4.1b-fpe-fpm`)
- **Dados:** STN restaurada do release `dados-stn-20261027` (procedência e SHA-256 no HANDOVER). Leitor `R/transform/stn.R` com regras explícitas e testadas: mês normalizado, repetições idênticas removidas (27 no FPE, 66.072 no FPM), 14 meses ausentes como NA (sem imputação), correção ÷100 de set/2024 só com critérios (passou: FPE 9,83 e FPM 13,82 bi).
- **Candidato fpe_fpm** = m3 + g (FPE+FPM acumulados jan..m em % do PIB menos o mesmo do ano anterior). Definição no contrato; a definição foi escrita depois de disparado o backtest e antes de eu ver qualquer resultado (a primeira rodada falhou na sensibilidade e foi refeita; as 33 linhas dela estão com `obsoleto_execucao_incompleta`).
- **Elegibilidade (anos-alvo sem 2020–22, após as lacunas):** 14 (cortes 1–4), 12 (5–10), 11 (corte 11); todas as faixas ≥10, mas sem 2023–24 em todos os cortes (e sem 2018–19 a partir do corte 5).
- **Resultado (RMSE médio da faixa vs SRW em R$, sem 2020–22, anos pareados; sem DM/Holm nem regra de aceitação, que são do torneio):** fpe_fpm +44% (1–4), +25% (5–8), −29% (9–11); m3 nos mesmos anos +28%, +23%, −29%.
- **Valor marginal de g (diagnóstico):** nulo. fpe_fpm contra m3 nos mesmos ano × corte: DM com p entre 0,11 e 0,85 em todos os cortes, e a favor do m3 na maioria. Coeficiente de g com |t| < 1 nos cortes 5, 8 e 11; VIF de 1,1 a 1,5, então não há colinearidade com o acumulado: g só não traz informação. Sensibilidade com um mês a mais de defasagem da STN (`fpe_fpm_lag1`): praticamente igual (+44%, +25%, −34%), então o resultado não depende da hipótese de `available_at`.
- **Limitação:** a avaliação pareada perde 2023–24 (lacunas da STN), os anos mais recentes. Saídas em `outputs/fpe_fpm_*.csv`.

### E2.10 / E3.5 — Meta de primário da LDO (27/10/2026, branch `e3.5-ldo-levantamento`)
- **Resultado: "LDO não viável no P1"; E3.5 encerrado.** `scripts/levantamento_ldo.R` lê os RREO dos estados já baixados (Anexo 06, conta `RREO6MetaDeResultadoPrimario...`), sem nova chamada à API. Saídas em `outputs/ldo_meta_*.csv`.
- A meta existe para 2015–2025 (26–27 UFs por ano), só para estados; municípios dependem da carga histórica. Motivos da inviabilidade: (i) 11 anos, e sem 2020–22 sobram 8 anos-alvo mesmo sem nenhum ano de treino, abaixo do piso congelado de 10, então o candidato seria inelegível em qualquer faixa; (ii) a meta é revista no ano (1 a 11 UFs mudam do 1º ao 6º bimestre; em 2024 o agregado vai de +26,3 para −3,9 bi) e só a versão disponível no corte pode ser usada; (iii) o agregado das metas (de −27 a +26 bi) tem pouca relação com o primário dos estados no BCB (de +5 a +78 bi).
- **Correção:** a nota anterior de que a meta só existia em 2015–2017 estava errada; o texto da conta mudou de rótulo em 2018 ("META FIXADA NO ANEXO...") e a busca antiga não o captava.
- **Verificação não concluída:** a consulta ao endpoint `/anexos-relatorios` do Siconfi (para ver se RGF, DCA ou MSC têm campo de meta) falhou duas vezes (timeout do cliente e HTTP 504). O fechamento se apoia só no Anexo 06 do RREO; RGF/DCA/MSC não foram verificados. Sem mais chamadas ao Siconfi desta frente, a menos que você peça.
- A meta pode entrar depois como contexto do informe, fora do torneio.

### E4 — Correção do leitor da STN antes do torneio (28/10/2026, branch `e4-torneio`)
- Pedro pediu para checar se a parcela extra de set/2025 aparecia sob outro nome: **aparecia**. Desde jul/2025 as parcelas de 1% do FPM (jul, set, dez) vêm nos CSV de municípios com item/transferência "FPM 1%", que o filtro do leitor (só "FPM") não capturava. Em set/2025 são R$ 7,83 bi (a razão FPM/FPE vai de 1,047 para 1,79). O leitor agora soma "FPM 1%" ao FPM; teste novo.
- Efeito no PR #27: o g de 2025 (cortes 9–10) estava subestimado; os números do `fpe_fpm` em STATUS (#27) valem só como preliminares e as 42 linhas registradas (fpe_fpm e fpe_fpm_lag1) foram marcadas `obsoleto_leitor_stn`, sem apagar. O torneio regenera o candidato com o leitor corrigido e o registra no novo hash.
- Mai/2018: causa esclarecida (arquivo sem o nome da transferência, não separa FPE de FUNDEB); segue NA.
- Primeira execução do torneio (commit 873d75e) foi interrompida por mim antes de qualquer resultado ou registro, para corrigir o leitor; a execução válida é a do commit seguinte.
- Pareamento do torneio: por par (cada desafiante contra a base, nos anos em que o par tem todos os cortes da faixa), nunca global; lacunas da STN só afetam o fpe_fpm e a combinação.

### E4 — Torneio do P1 (28/10/2026, branch `e4-torneio`, commit de execução `ba5ccf3`)
- **Execução única, regra 7 cumprida:** commit do script e da lista (K = 8) antes da execução; as previsões regeneradas reproduzem o PR #25 (198 linhas regeneradas, 198 registradas, 0 divergências); registro no mesmo hash (242 linhas, validadas). A primeira tentativa (commit 873d75e) foi interrompida por mim antes de qualquer resultado, para corrigir o leitor da STN (parcela "FPM 1%").
- **Decisão: nenhum desafiante é aceito em nenhuma faixa; vale a base (SRW em R$) nas três.** Todos os 7 desafiantes são elegíveis nas três faixas (o fpe_fpm com 14, 12 e 11 anos-alvo sem 2020–22).
- **RMSE da faixa vs base, sem 2020–22:**

| Desafiante | Cortes 1–4 | 5–8 | 9–11 |
|---|---|---|---|
| srw_pib | +5% | +2% | +5% |
| acumulado_j5 | +55% | +75% | −26% |
| m2 | +27% | +25% | −7% |
| m3 | +28% | +15% | −41% |
| e41 | +40% | +35% | −20% |
| fpe_fpm | +44% | +27% | −28% |
| combinacao | +19% | +15% | −26% |

- **Cortes 1–8:** nenhum desafiante passa sequer no critério 1 (RMSE −10%); a base é melhor, e o menor p bruto do DM é 0,025 (E4.1), a favor da base.
- **Cortes 9–11:** cinco desafiantes passam no critério 1 e quatro no 2, mas **nenhum passa no DM com Holm** (menor p bruto 0,129 no m3; ajustado 0,904, família de 7). O m3 é o mais próximo: RMSE −41%, melhor em 81% dos anos-alvo e acerto de sinal maior que o da base, mas com viés de −0,20 bi contra 0,07 da base (critério 4 também falha) e DM sem significância. Com 16 anos-alvo o teste tem pouco poder, que é a limitação já declarada no contrato; a regra não foi alterada.
- **Limitações que continuam valendo:** PIB realizado no backtest; fpe_fpm avaliado sem 2023–24 (lacunas da STN); parcela "FPM 1%" corrigida no leitor.
- Saídas (fora do git): `outputs/torneio_decisao.csv`, `torneio_escolha.csv`, `torneio_backtest.csv`, `torneio_conferencia_pr25.csv`.

## Pendências abertas
- Carga histórica municipal em faixas (só após aprovação da E2.4): agora = 6º bimestre de todos os anos + bimestres 1–5 de 2023 em diante (2026 b1–b4); **pendência condicionada**: bimestres 1–5 de 2015–2022 só se o bottom-up mostrar potencial no E4.
- Contrato (PR próprio): versão mais recente (retificada) e regra do `available_at` (HO: `data_status`; RE: prazo legal + atraso mediano dos homologados da mesma UF × período).
- E2.2: verificar contas do Simplificado por UF (MS, MG, RS, PR, MA, ES têm 34–48% da receita no grupo); validar extração do primário municipal (layout 2019 × 2025; 22 e 135 municípios sem primário).
- E2.7: medir a fração de retificações e a defasagem de entrega com o extrato completo (~5,6 mil chamadas por ano).
- Carga histórica do censo municipal (ordem aprovada em 24/10/2026): definir onde rodar (~6 dias de API) e escrever `scripts/carga_historica.R`.
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
- E2.10: feito (ver acima; RGF/DCA/MSC não verificados).
- E3.3: regra de aceitação a congelar.

## Decisões (com data)
- 24/10/2026 (E1.9): RREO usa a versão mais recente (retificada). `available_at` do RREO: homologado = `data_status`; retificado = prazo legal (fim do bimestre + 30 dias) + atraso mediano dos homologados da mesma UF × período (o prazo legal puro vazaria informação). Aplicado em `docs/contrato.md`, seção Avaliação.
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
