# HANDOVER — manual de passagem

Objetivo: documentar todo o projeto (o que faz, dados, decisões, como rodar, problemas conhecidos) num só lugar.
Atualizar sempre que mudar como o modelo roda, quais dados usa ou alguma decisão.
Última atualização: 23/10/2026 (E1.1: estrutura do repositório).
Repositório: https://github.com/pedrobolt/fiscal-subnacional

## 1. Em uma frase
Modelo em R que projeta o resultado primário dos governos regionais (estados + municípios) do ano corrente
no conceito do Banco Central (P1) e as receitas e despesas no conceito RREO/Siconfi (P2). Ver `docs/contrato.md`.

## 2. Para que serve e quem usa
- Saída: Excel final em `outputs/`, com P1, P2, gap entre os dois e a linha "Regionais" da planilha federal
  ("Projeções Fiscais Economia Brasileira", aba Receitas e Despesas).
- Uso: informe fiscal da CNI/ECON.
- Responsável atual: Pedro Leite (ECON). Próximo responsável: [preencher].

## 3. Como rodar (rodada mensal)
Pré-requisitos: R (≥ 4.3), Rtools (Windows); pacotes instalados com `renv::restore()`.
No Linux, instalar antes a biblioteca de sistema `libglpk40` (exigida pelo `igraph`, dependência do `targets`).
```
Rscript -e "renv::restore()"                 # só na primeira vez ou após mudança de pacotes
cp premissas.exemplo.yml premissas.yml       # e preencher com o cenário vigente
Rscript -e "targets::tar_make()"             # baixa, valida, projeta e exporta (E1.5: fatia mínima; tabelas em outputs/fatia_*.csv)
# o ano-alvo está em _targets.R (ano_t); em jan/fev, trocar para o ano anterior
Rscript -e "testthat::test_dir('tests')"     # confere
```
Passo a passo detalhado, com o que conferir antes de enviar os números: `docs/playbook_rodada.md` (E7.4).

### 3a. Windows da CNI sem PowerShell: usar o Prompt de Comando (cmd)
No PC da CNI o PowerShell está bloqueado (acesso negado). Todos os comandos deste documento funcionam no **Prompt de Comando** (tecla Windows, digitar `cmd`), com estas diferenças:
- Não existe o operador `&`. Onde o texto diz `& "C:\Program Files\R\R-4.3.3\bin\Rscript.exe" scripts/x.R 1`, no cmd é só `"C:\Program Files\R\R-4.3.3\bin\Rscript.exe" scripts/x.R 1`. Use **sempre o caminho completo** do Rscript entre aspas (a versão da pasta pode ser outra). O R pode estar em `C:\Program Files\R` ou, como no PC da CNI, em `%LOCALAPPDATA%\Programs\R` (instalação por usuário, sem administrador); para descobrir: `dir "C:\Program Files\R"` e `dir "%LOCALAPPDATA%\Programs\R"`. Nesse segundo caso o caminho completo fica `"%LOCALAPPDATA%\Programs\R\R-<versão>\bin\Rscript.exe"` (o cmd expande a variável dentro das aspas).
- `-e` com aspas duplas por fora e aspas simples por dentro: `"C:\Program Files\R\R-4.3.3\bin\Rscript.exe" -e "testthat::test_dir('tests')"`. Aspas duplas dentro do código R precisam ser trocadas por simples.
- Entrar na raiz do repositório: `cd /d C:\caminho\Fiscal-Subnacional` (o `/d` troca de disco, se for o caso).
- Dois terminais para a carga histórica: abrir duas janelas do cmd, uma por fatia (ou `start cmd /k ""C:\Program Files\R\R-4.3.3\bin\Rscript.exe" scripts\carga_historica.R 1"` e o mesmo com `2`). Nunca mais de dois.
- Variáveis de ambiente (quando necessário): `set NOME=valor` na mesma janela; não precisa de `LC_ALL` (o código não depende do locale).
- Comando de teste padrão: `"C:\Program Files\R\R-4.3.3\bin\Rscript.exe" -e "r <- as.data.frame(testthat::test_dir('tests', reporter = 'silent', stop_on_failure = FALSE)); cat('FAIL', sum(r$failed), 'ERR', sum(r$error), 'PASS', sum(r$passed), '\n')"`.
- Se o cmd também estiver bloqueado, abrir o R GUI ou o RStudio e rodar o mesmo código com `source("scripts/arquivo.R")` na raiz do repositório (`setwd()`), anotando o que falhar no STATUS.

### 3b. Dados brutos do RREO: carga inicial e rodada incremental
O bruto (`data/raw/rreo/`, ~125 MB compactado, 30 mil arquivos) não está no git. Cópia de referência: **GitHub Release `dados-rreo-20261023`** do repositório (publicado à mão pelo Pedro: a sessão de desenvolvimento não pode criar Releases; a tag aponta para `main` e o commit do código que gerou os dados consta em `commit_codigo` do manifesto JSON; restauração testada em 24/10/2026: 30.428 arquivos, MD5 conferido, 32 s) (dados públicos do Siconfi), com o pacote `rreo_bruto_20261023.tar.gz` e o manifesto (`_manifesto.csv` com arquivo, tamanho e MD5; `_manifesto.json` com contagens, datas de coleta e o commit do código que gerou os dados).
- **Carga inicial** (máquina nova ou ambiente perdido): baixar os dois arquivos do Release (página Releases, ou `gh release download dados-rreo-20261023`) e, na raiz do repositório, `Rscript scripts/restaurar_dados.R rreo_bruto_20261023.tar.gz rreo_bruto_20261023_manifesto.csv`. O script extrai em `data/raw/rreo/` e confere tamanho e MD5 de todos os arquivos; falha se algo estiver ausente ou diferente.
- **Rodada incremental** (mensal/bimestral): `atualizar_rreo(ids, anos, periodos, esfera)` lê o `extrato_entregas` de cada ente × ano (renovado se tiver mais de 7 dias), compara a data de homologação/retificação com a data do arquivo local e baixa só o que falta (`novo`), o que foi retificado (`retificado`, gravado como **snapshot novo**: o anterior nunca é sobrescrito) e entregas atrasadas (`vazio_com_entrega`). A versão vigente é a mais recente. O extrato também vira snapshot a cada consulta (histórico de retificações a partir de agora).
- **Estados**: `Rscript -e 'source("_targets.R"); baixar_rreo_estados()'` (~1,2 h do zero). **Municípios**: `Rscript scripts/coleta_municipal.R 1` e `... 2` (2 processos = 2 conexões, o máximo; não passar disso). Ritmo medido: 1,44 chamada/s; ~13 mil chamadas (~2,5 h) por bimestre.
- Atualizar o Release: `Rscript scripts/empacotar_dados.R <AAAAMMDD>` (valida todos os arquivos, exige código commitado e grava em `outputs/release/`) e criar um novo Release com data no nome; não sobrescrever o anterior.

### 3c. Carga histórica do RREO municipal (Windows, sem supervisor)
Só depois de a E2.4 (snapshots e extrato) estar aprovada e mergeada. Faixas, na ordem: (0) estados; (1) municípios, 6º bimestre de 2025 a 2015; (2) municípios, bimestres 1–5 de 2026 a 2023. Bimestres 1–5 de 2015–2022 **não** entram (pendência condicionada ao E4). Estimativa: ~378 mil chamadas, ~3 dias de API a 1,44 chamada/s (2 conexões; o ritmo na sua rede pode variar).
1. Preparar: clone atualizado do repositório na `main`; `Rscript -e "renv::restore()"` (no Windows, se a instalação do pacote Matrix falhar por falta de compilador, use `renv::restore(exclude = 'Matrix')`, que mantém o Matrix já incluído no R, ou instale o Rtools); restaurar o bruto já coletado (HANDOVER 3b, `scripts/restaurar_dados.R`) para não rebaixar o que já existe.
2. Impedir suspensão: Configurações > Sistema > Energia > "Suspensão" = Nunca (na tomada); notebook: tampa fechada = não fazer nada. Deixar o computador na tomada.
3. Abrir **dois** terminais (PowerShell) na raiz do repositório e rodar um comando em cada: `Rscript scripts/carga_historica.R 1` e `Rscript scripts/carga_historica.R 2`. Se o Windows não reconhecer `Rscript`, usar o caminho completo, por exemplo `& "C:\Program Files\R\R-4.3.3\bin\Rscript.exe" scripts/carga_historica.R 1`. **Nunca mais de dois** (limite de conexões); o script se recusa a rodar a mesma fatia duas vezes ao mesmo tempo (aviso "parece já estar em execução").
4. Acompanhar: `Rscript scripts/carga_historica_progresso.R` (não usa a API): tabela por faixa e ano, chamadas restantes, ritmo da última hora e horas restantes.
5. Interrupção (fechou o terminal, queda de energia ou de rede): rodar os mesmos dois comandos. Arquivos são gravados de forma atômica e o que existe não é rebaixado. Se aparecer "parece já estar em execução", aguardar 2 minutos ou conferir no Gerenciador de Tarefas se há outro `Rscript` ativo.
6. Falhas de rede num ente x ano ficam em `data/raw/rreo/_erros_carga<N>.csv` e são tentadas de novo na próxima execução.
7. Ao terminar (cada terminal imprime "Fatia N concluída"): `Rscript scripts/empacotar_dados.R AAAAMMDD` e publicar um novo Release com a data no nome (HANDOVER 3b). Os scripts não foram testados em Windows; se algo falhar, anotar a mensagem de erro no STATUS.

### 3d. Candidatos do restante do ano (E3.4/E4)
`Rscript scripts/candidatos_restante.R [--registrar]` usa só dados locais: BCB SGS 4642/4643/4644/4382 em `data/raw/` (baixe com `baixar_sgs()`, que faz chamadas ao BCB, não ao Siconfi) e o RREO dos estados em `data/raw/rreo/E`. Saídas em `outputs/restante_*.csv`; `--registrar` acrescenta linhas ao `experiments/registro.csv` (rodar só depois de commitar o código, para o hash ficar certo). Detalhes e leitura: `docs/relatorio_candidatos_restante.md`.

### 3e. PIB do IBGE e transferências da STN (E2.3)
- **PIB:** `baixar_pib_ibge()` grava `data/raw/ibge_pib_6784_<data>.json` e `ibge_pib_1846_<data>.json`; `pib_ibge_anual()` devolve o PIB nominal anual em R$ bi. Não usar o PIB acumulado em 12 meses do BCB (contrato).
- **STN:** o Tesouro Transparente limita a taxa de pedidos (HTTP 429). Na sua máquina: `Rscript -e 'source("R/download/stn_transferencias.R"); print(baixar_stn("estados")); print(baixar_stn("municipios"))'`. Baixa para `data/raw/stn/<estados|municipios>/`, ~5 s entre arquivos, espera o `Retry-After` e para após 3 recusas seguidas; é só rodar de novo (o que já existe não é rebaixado; HTML de erro nunca é gravado). Se continuar recusando, tente em outro horário. Isso não usa a API do Siconfi e pode rodar junto com a carga histórica.

**Procedência dos dados da STN (27/10/2026).** Baixados por Pedro no PC da CNI e publicados no release `dados-stn-20261027` (asset `stn_20261027.zip`, 315.449.049 bytes, SHA-256 `be5f8132cfa1b2060f17d2652acc44990633fc1d4427d83b05406661c8a33638`): 258 arquivos CSV (119 de estados, 139 de municípios), conferidos por Pedro contra a lista do CKAN. Restauração: baixar o asset do release e extrair em `data/raw/stn/` (o zip usa `\` como separador; os arquivos ficam em `estados/` e `municipios/`). Os arquivos são imutáveis; correções de conteúdo acontecem no leitor, nunca no arquivo.
- Achados na conferência do conteúdo, tratados em `R/transform/stn.R` (os arquivos brutos não são alterados): (i) o campo mês vem às vezes sem zero à esquerda ("1", "8"); o leitor o converte em inteiro (sem isso aparecem lacunas falsas); (ii) linhas repetidas entre arquivos sobrepostos: 27 no FPE e 66.072 no FPM, todas com valores idênticos (valores diferentes seriam erro); (iii) meses ausentes: 14 no total (união de FPE e FPM): 2018-05, 2019-10 (FPM), 2020-08, 2020-11, 2021-08, 2022-10 a 2022-12, 2023-01, 2023-02, 2023-11, 2023-12 (FPM), 2024-11 e 2025-11, tratados como NA, sem imputação; (iv) set/2024 (arquivo `Transferencia_Mensal_Estados_202410.csv` e o equivalente de municípios) vem ~100× fora de escala; a correção ÷100 só é aplicada se, nos dois fluxos ao mesmo tempo, o valor corrigido ficar entre 0,5× e 2× a mediana dos 12 meses vizinhos e do mesmo mês nos anos adjacentes, e a razão FPM/FPE ficar no envelope das razões dos meses vizinhos (±12). Set/2024 passa (FPE 9,83 bi e FPM 13,82 bi); a razão 1,41 está acima das razões dos setembros anteriores (1,05 a 1,27) e dentro do envelope por causa dos meses de cota extra (jul, dez); o teste de escala de fato é o de nível. (v) o número no nome do arquivo mensal costuma ser o mês de publicação e o mês de referência é o anterior (ex.: `202410` traz set/2024), com exceções (`202412` traz dez/2024).
- **Parcela extra do FPM em setembro (EC 112/2021).** A emenda (texto na página da Câmara; o Planalto bloqueou o acesso a partir daqui) acrescentou ao art. 159, I, o repasse de 1% ao FPM, entregue no 1º decêndio de setembro, escalonado: 0,25% nos dois primeiros exercícios de efeitos financeiros, 0,5% no terceiro e 1% a partir do quarto, com efeitos a partir de 1º de janeiro do exercício seguinte à publicação (28/10/2021), ou seja, 2022. Isso explica a razão FPM/FPE de setembro crescente nos dados: parcela extra implícita (FPM − 1,0465 × FPE) de R$ 1,2 bi (2022), 1,8 bi (2023) e 3,5 bi (2024), comparável aos R$ 3,33 bi reportados pela imprensa para 2024. **Set/2025 (resolvido em 28/10/2026):** a parcela extra aparece nos CSV de municípios com item e transferência **"FPM 1%"** (linhas próprias, 5.570 municípios) nos meses jul/2025, set/2025, dez/2025, jul/2026 e set/2026; até jun/2025 as parcelas de 1% (jul, set, dez) estavam dentro do "FPM". Em set/2025 ela soma R$ 7,83 bi (1%, cerca do dobro dos R$ 3,5 bi de 2024 em 0,5%, como no escalonamento), e a razão FPM/FPE do mês passa de 1,047 para 1,79. O leitor passou a somar "FPM 1%" ao FPM; antes disso o FPM de jul, set e dez/2025 e jul e set/2026 estava subestimado, e o `fpe_fpm` registrado no PR #27 usou o leitor antigo (linhas marcadas como `obsoleto_leitor_stn`; o torneio regenera o candidato). Lição para o leitor: listar os itens/transferências distintos por mês antes de filtrar por nome.
- **Mai/2018 (causa esclarecida):** o arquivo `Transferencia_Mensal_Estados_201805.csv` (e o de municípios) vem sem a coluna "Transferência" preenchida, com várias linhas por UF e item (ex.: três linhas de FPE por UF) que não dá para separar do que vai ao FUNDEB; segue como NA, sem imputação.
- **`available_at` da STN (provisório):** o mês de referência m entra no último dia útil de m+1, a mesma data de corte do mês m. Não há vintages históricas; a sensibilidade com um mês a mais de defasagem roda como diagnóstico (`fpe_fpm_lag1`).
- Uso: `s <- carregar_stn()` (≈1,5 min; lê 258 CSVs com `data.table`) devolve ano, mes, valor_fpe, valor_fpm (R$ bi), tratamento e available_at.

### 3f. Vazamento e registro (E3.7)
- Todo candidato do P1 implementa `function(info, ano_t, m)` e entra em `CANDIDATOS_P1` (`R/models/candidatos_p1.R`); `info` vem só de `montar_info()`. O teste `tests/test-vazamento.R` perturba o futuro e falha se alguma previsão mudar; rode a suíte inteira antes de abrir PR.
- Antes de registrar resultados: commitar o código, rodar o script com `--registrar` (o hash precisa existir) e conferir `Rscript -e 'source("R/evaluation/registro.R"); print(validar_registro())'` (vazio = ok). Linhas nunca são apagadas; o campo `status` diz o que vale.
- Calendário do BCB: se houver o calendário real de divulgação, passe-o em `calendario` (ano, mes, data); sem ele, vale a aproximação do último dia útil do mês seguinte.

### 3g. Dicionário de contas dos estados (E2.5)
`Rscript scripts/dicionario_e25.R` regenera `data/dicionario_contas_estados.csv` e `data/dicionario_colunas_estados.csv` a partir do bruto local e roda o fechamento do Anexo 6 e a conferência acumulado → fluxo (saídas em `outputs/e25_*.csv`). Se aparecer conta ou coluna nova no Siconfi, o script lista o que falta classificar; a decisão vai para `R/transform/dicionario_contas.R`. Caixa da despesa = paga + RP processados pagos + RP não processados pagos (só de 2018 em diante). Detalhes em `docs/dicionario_contas_estados.md`. CSV do projeto: sempre `ler_csv()`/`gravar_csv()` de `R/utils_io.R` (UTF-8 em qualquer locale); não usar read.csv/write.csv com `fileEncoding`.

## 4. Quando rodar
Sob demanda, após nova divulgação do BCB (fim do mês) ou de um bimestre do RREO. Não há agendamento.

## 5. O que atualizar à mão
- `premissas.yml`: IPCA, PIB real e PIB nominal (R$ bilhões) do cenário vigente da planilha federal (com data e fonte). Não é versionado (informação interna); o formato está em `premissas.exemplo.yml` e a validação em `R/premissas.R` (`ler_premissas()`).
- Nada mais deve exigir edição manual. Se exigir, registrar aqui.

Registro de experimentos: `experiments/registro.csv` (um candidato por linha e cutoff, com parâmetros, amostra e commit). Novo candidato avaliado = nova linha via `registrar_experimento()`.

## 6. Fontes de dados
| Fonte | O quê | Acesso | Defasagem típica |
|---|---|---|---|
| BCB/SGS | Primário regional (4642), estadual (4643), municipal (4644); NFSP sem desvalorização cambial, fluxo mensal, R$ milhões, déficit positivo (o código inverte o sinal) | `https://api.bcb.gov.br/dados/serie/bcdata.sgs.<código>/dados?formato=json`; a API falha de forma intermitente (há novas tentativas) | ~1 mês [confirmar no E2] |
| Siconfi/RREO | Anexos 1 e 6, estados e municípios (bimestral) | API `apidatalake.tesouro.gov.br/ords/siconfi/tt/rreo` (exige `id_ente`; sem download em massa para o RREO). Estados: `Rscript -e 'source("_targets.R"); baixar_rreo_estados()'` (~1,2 h, retomável) | 30 dias legais + atraso [medir no E2.7] |
| STN | Transferências FPE/FPM | [preencher no E2.3] | [preencher] |
| IBGE/BCB | IPCA, PIB | API | — |

## 7. Fluxo de desenvolvimento
Cada tarefa do `docs/plano.md` é feita numa branch própria e entra em `main` por pull request revisado pelo responsável. Regras para o agente de IA em `AGENTS.md`.

## 7b. Decisões tomadas e por quê
Ver `docs/STATUS.md` (seção Decisões). Mudanças de conceito exigem aprovação de quem responde pelo projeto.

## 8. Problemas conhecidos e como tratar
- RJ, PR e RS: reclassificação de pessoal no RREO desde o 2º sem. 2025. Tratamento: [preencher após E2.8].
- Histórico do BCB é revisado; avaliação histórica usa a série atual. Snapshots próprios desde [data do E2.4].
- [Acrescentar falhas de API, entes que atrasam, etc.]

## 9. Se algo quebrar
| Sintoma | Causa provável | O que fazer |
|---|---|---|
| [preencher conforme aparecerem] | | |

## 10. Contatos e referências
- Plano completo: documento "Plano de implementação — Previsão Fiscal Subnacional".
- Referências metodológicas: dossiê do projeto (revisão de literatura, estudo operacional).
- [Contatos na CNI: preencher]
