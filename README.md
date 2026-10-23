# Fiscal-Subnacional

Modelo em R que projeta o resultado primário dos governos regionais (estados + municípios) do ano corrente,
no conceito do Banco Central, e as receitas e despesas no conceito RREO/Siconfi. CNI/ECON.

- O que o modelo faz e como rodar: [`docs/HANDOVER.md`](docs/HANDOVER.md)
- Conceitos e regras de avaliação: [`docs/contrato.md`](docs/contrato.md)
- Tarefas e etapas: [`docs/plano.md`](docs/plano.md)
- Estado atual e decisões: [`docs/STATUS.md`](docs/STATUS.md)
- Regras para o agente de IA: [`AGENTS.md`](AGENTS.md)

## Rodar
```
Rscript -e "renv::restore()"               # primeira vez
cp premissas.exemplo.yml premissas.yml     # preencher com o cenário vigente (não versionado)
Rscript -e "targets::tar_make()"
Rscript -e "testthat::test_dir('tests')"
```
