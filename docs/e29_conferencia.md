# E2.9 — Conferência mínima contra o RREO publicado pelo estado

Escopo reduzido em 30/10/2026 (decisão do Pedro): a validação ampla já está coberta por checagens automáticas; esta etapa faz só uma conferência visual de 3 itens.

## O que está coberto automaticamente (não conferido à mão)
- Fechamento contra o publicado, em todos os arquivos do Anexo 6 dos estados: soma das folhas pelo dicionário = total publicado, e receita − despesa = resultado publicado (tabela em `docs/dicionario_contas_estados.md`, seção 6; exceções em `outputs/e25_fechamento_excecoes.csv`).
- Validação do Anexo 3 contra a DCA (`scripts/dca_validacao_a3.R`) e testes do conceito único (`scripts/conceito_unico.R`).
- Suíte de testes (`tests/`), incluindo o dicionário e a conversão de acumulado em fluxo.

Esses controles comparam o pipeline com os dados da própria API do Siconfi. Não detectam erro da própria fonte nem diferença entre o Siconfi e o que o estado publica. É isso que os 3 itens abaixo testam, sem pretensão de amostra estatística.

## Itens (SP, RJ e MG; 4º bimestre de 2026, acumulado jan–ago; R$ bilhões)
Origem: Anexo 6 (Siconfi), versão baixada em 23/10/2026; planilha em `outputs/e29_planilha.csv` (`scripts/e29_planilha.R`).

| UF | Receita primária | Despesa paga (a) | RP processados pagos (b) | RP não processados pagos (c) | Despesa em caixa (a+b+c) | Resultado publicado |
|---|---|---|---|---|---|---|
| SP | 243,585 | 210,097 | 17,481 | 10,687 | 238,265 | 5,321 |
| RJ | 76,430 | 65,248 | 2,023 | 1,110 | 68,380 | 8,050 |
| MG | 83,582 | 73,745 | 4,712 | 3,145 | 81,602 | 1,979 |

Em cada UF, receita − despesa em caixa fecha com o resultado publicado (diferença ≤ R$ 1.000).

## Como conferir
Abrir o RREO do 4º bimestre de 2026 no site da SEFAZ do estado (não o PDF do Siconfi), demonstrativo do resultado primário. Preencher na planilha as colunas `*_site` (receita primária total exceto fontes RPPS, despesa paga, RP processados pagos, RP não processados pagos, resultado primário), em R$. Se o estado publicou versão posterior à de 23/10/2026 (retificação), anotar em `obs`.

## Regra de aceitação (definida antes da leitura)
Diferença relativa ≤ 0,1% em cada linha e mesmo sinal do resultado primário. Divergência: classificar como erro de leitura, de dicionário (corrigir com teste) ou de definição (registrar em `docs/nota_quebras.md`).

## Resultado (30/10/2026)
**3/3 UFs conferidas, 4º bim. 2026, Anexo 6, sem RPPS.** Leitura do Pedro nos RREO publicados pelos próprios estados: receita primária, despesa (paga + RP processados pagos + RP não processados pagos) e resultado primário batem com o pipeline nas três UFs, dentro de 0,1% e com o mesmo sinal (R$ bi, PDF = pipeline; receita / despesa / resultado): SP 243,585 / 238,265 / 5,321; RJ 76,430 / 68,380 / 8,050; MG 83,582 / 81,602 / 1,979.

**Limite do teste:** cobre só os totais. Não valida a quebra de pessoal por categoria (RJ, PR e RS) nem a classificação por categoria do dicionário; isso segue apoiado nos testes automáticos e na nota de quebras.
