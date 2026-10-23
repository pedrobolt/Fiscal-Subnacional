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

## 4. Quando rodar
Sob demanda, após nova divulgação do BCB (fim do mês) ou de um bimestre do RREO. Não há agendamento.

## 5. O que atualizar à mão
- `premissas.yml`: IPCA, PIB real e PIB nominal (R$ bilhões) do cenário vigente da planilha federal (com data e fonte). Não é versionado (informação interna); o formato está em `premissas.exemplo.yml` e a validação em `R/premissas.R` (`ler_premissas()`).
- Nada mais deve exigir edição manual. Se exigir, registrar aqui.

## 6. Fontes de dados
| Fonte | O quê | Acesso | Defasagem típica |
|---|---|---|---|
| BCB/SGS | Primário regional (4642), estadual (4643), municipal (4644); NFSP sem desvalorização cambial, fluxo mensal, R$ milhões, déficit positivo (o código inverte o sinal) | `https://api.bcb.gov.br/dados/serie/bcdata.sgs.<código>/dados?formato=json`; a API falha de forma intermitente (há novas tentativas) | ~1 mês [confirmar no E2] |
| Siconfi/RREO | Anexos 1 e 6, estados e municípios (bimestral) | API Siconfi | 30 dias legais + atraso [medir no E2.7] |
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
