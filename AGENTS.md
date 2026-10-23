# AGENTS.md — Previsão Fiscal Subnacional (CNI/ECON)

Leia este arquivo, `docs/contrato.md`, `docs/plano.md`, `docs/STATUS.md` e `docs/HANDOVER.md` antes de qualquer tarefa.

O projeto precisa poder ser assumido por outra pessoa a qualquer momento: documentação faz parte de toda tarefa, não só do fim.

## O que é o projeto
Modelo em R que projeta, para o ano corrente, o resultado primário dos governos regionais
(estados + municípios) e suas receitas e despesas.
- **P1**: resultado primário no conceito do Banco Central (o número principal).
- **P2**: receitas, despesas e resultado primário no conceito RREO/Siconfi (a explicação).
- O gap entre P1 e P2 sempre aparece nas saídas.

## Como trabalhar (fluxo GitHub)
1. **Uma tarefa por vez**, exatamente a pedida, numa branch própria (`e<etapa>.<tarefa>-<nome>`, ex.: `e2.1-rreo-estados`). Não adiante tarefas de outras etapas.
2. **Antes de codar**, descreva em até 5 linhas o que vai fazer e quais arquivos vai criar ou alterar. Espere aprovação se a tarefa envolver conceito fiscal, dados ou avaliação.
3. **Ao terminar**: rode os testes e o pipeline, mostre a saída real, atualize `docs/STATUS.md` (incluindo a lista de arquivos alterados) e, se a tarefa mudou como o modelo roda, quais dados usa ou alguma decisão, atualize `docs/HANDOVER.md`.
4. Faça commit na branch da tarefa e abra um **pull request** para `main`. A revisão e o merge são do Pedro.
5. **Nunca** faça push direto em `main`, merge, force-push ou apague arquivos sem pedido explícito.
6. Nunca declare sucesso sem executar. Se algo falhou ou ficou pendente, diga.

## Regras que você não pode mudar sozinho
- Alvos, conceitos e unidades de `docs/contrato.md`.
- Cutoffs, métricas e regra de aceitação do protocolo de avaliação (depois de aprovados).
- Premissas em `premissas.yml` (só o Pedro altera).
Se achar que alguma está errada, aponte e pergunte. Não "corrija" por conta própria.

## Informação interna da CNI
- `premissas.yml` (cenário macro da planilha federal) **não vai para o repositório**: está no `.gitignore`. O modelo de formato está em `premissas.exemplo.yml`.
- O Excel final em `outputs/` também não é versionado.
- Dados de BCB, Siconfi, STN e IBGE são públicos.

## Regras de dados
- Dados brutos são imutáveis: cada coleta vira um snapshot novo em `data/raw/<fonte>/<data>/`. Nunca sobrescreva.
- Ausente não é zero. Nunca preencha ausência com 0. Diferencie: zero declarado, não declarado, falha de coleta.
- Não interpole RREO bimestral para mensal.
- Saúde/educação (funções) e pessoal/custeio/investimento (categorias econômicas) se cruzam: nunca some como blocos separados.
- Saltos extremos são sinalizados, nunca apagados.
- Toda correção ou imputação fica registrada (motivo + flag) em camada separada do bruto.

## Regras de avaliação (anti-vazamento)
- Em cada cutoff do backtest, só entra informação com `available_at <= cutoff`.
- Regressores macro entram como previsão disponível no cutoff, nunca como valor realizado.
- Todo candidato testado vai para `experiments/registro.csv`, inclusive os que perdem.
- Em empate prático, fica o mais simples.

## Stack
R com `renv` (versões fixadas), `targets` (pipeline), `testthat` (testes). Só pacotes do CRAN.
Sugestões para as próximas etapas: `dplyr`, `tidyr`, `arrow` (Parquet), `httr2`/`jsonlite` (API Siconfi),
`rbcb` (BCB/SGS), `tsibble`/`fable`/`fabletools` (benchmarks e backtest), `openxlsx` (saída Excel).
Caminhos sempre relativos à raiz do projeto.

## Estrutura de pastas
```
R/               funções (download/, transform/, quality/, models/, evaluation/, export/)
data/raw/        snapshots imutáveis
data/processed/  base canônica
tests/           testthat
experiments/     registro.csv e resultados
outputs/         Excel final e previsões emitidas (não versionado)
docs/            contrato, plano, status, handover, notas técnicas
_targets.R       pipeline
```

## Comandos
- Instalar dependências: `Rscript -e "renv::restore()"`
- Testes: `Rscript -e "testthat::test_dir('tests')"`
- Pipeline: `Rscript -e "targets::tar_make()"`
