# Dicionário de contas dos estados — RREO Anexos 1 e 6 (E2.5)

Arquivos: `data/dicionario_contas_estados.csv` (conta por layout), `data/dicionario_colunas_estados.csv` (coluna por layout), código em `R/transform/dicionario_contas.R`, geração e conferência em `scripts/dicionario_e25.R`. Os números abaixo vêm de `outputs/e25_*.csv` gerados na execução de 28/10/2026 sobre o bruto local (27 estados, 2015 a 2026).

## 1. Layouts
O layout muda por arquivo, e a mudança coincide com o exercício: 2015–17 (só empenho e liquidação), 2018–22 (despesa paga e restos a pagar pagos) e 2023 em diante (fontes do RPPS em contas próprias). Verificado nos 27 estados nas duas viradas.

## 2. Qual anexo alimenta o P2
- **Anexo 6 (resultado primário)** é a fonte do P2: só ele decompõe ICMS, IPVA, ISS, FPE e FPM, e está no conceito primário.
- **Anexo 1 (orçamentário)** só agrega "Impostos" e inclui juros, amortização e intra-orçamentárias. Está classificado no dicionário (`usar_no_p2 = nao`) e serve de referência.

## 3. Campos do dicionário de contas
`papel`, `nivel` (folha, subtotal, total, detalhe, memo), `usar_no_p2` (soma, conferencia, nao), `estagio_p2`, `categoria_p2` (ICMS, IPVA, ISS, FPE/FPM, demais receitas, pessoal, custeio, investimento), `natureza` (corrente ou capital, para obter a receita corrente), `pai`, `rpps` e `nota`.

**Regra de soma:** somam-se só as folhas (`usar_no_p2 = soma`). Totais e subtotais servem para conferir. Teste automático: nenhuma folha tem ancestral folha pela cadeia `pai`, então pai e filhos nunca entram juntos.

## 4. Estágio a usar
- Receita: `receita_realizada`.
- Despesa em caixa, de 2018 em diante: **paga (a) + restos a pagar processados pagos (b) + restos a pagar não processados pagos (c)**. Confirmado contra o resultado publicado: receita realizada − (a + b + c) fecha em todos os arquivos de 2018–22 e de 2023+; (a) sozinha ou (a + b) não fecham. O contrato dizia "despesa paga + restos a pagar pagos"; agora fica explícito que são os dois tipos de RP.
- 2015–17: o Anexo 6 não traz despesa paga. O caixa não é reconstruível; a despesa fica na liquidação (`sem_caixa(liquidada)`) e o P2 em caixa começa em 2018.

## 5. RPPS
- 2023+: contas "com fontes RPPS" ficam fora (`rpps = excluido`), e os totais de conferência são os "exceto fontes RPPS" (`ja_excluido`).
- 2015–22: o RPPS está dentro das contas (contribuições previdenciárias, pessoal) e não dá para separar (`incluido_nao_separavel`). É a quebra de 2023 da nota do E2.8.

## 6. Fechamento contra o publicado
Somando as folhas pelo dicionário e comparando com o total publicado (tolerância de R$ 1.000), e receita − despesa com o resultado publicado:

| Layout | Receita fecha | Despesa fecha | Resultado fecha |
|---|---|---|---|
| 2015–17 | 486 de 486 | 483 de 483 | 481 de 483 |
| 2018–22 | 805 de 805 | 805 de 805 | 805 de 805 |
| 2023+ | 594 de 594 | 594 de 594 | 594 de 594 |

(Em 2015–17 são 486 arquivos; em três deles não há despesa, por isso 483.) Exceções, em `outputs/e25_fechamento_excecoes.csv`:
- Sem despesa no arquivo: ente 24 em 2015 b6, ente 29 em 2016 b6 e ente 42 em 2017 b1.
- Resultado publicado diferente de receita − despesa: ente 28 em 2015 b1 (publicado = −despesa, como se a receita fosse zero) e ente 29 em 2015 b1 (diferença de R$ 0,38 bi).
- O RS não tem o Anexo 6 dos bimestres 1–5 de 2018 (805 arquivos em vez de 810): lacuna conhecida do E2.8.

## 7. Acumulado → fluxo do bimestre (E2.6)
O RREO é acumulado no ano. `acumulado_para_fluxo()`: fluxo = acumulado do bimestre − acumulado do anterior; no bimestre 1, é o próprio acumulado; se o anterior não existe, o fluxo é NA (nunca zero). Testada com séries sintéticas e contra a coluna publicada "No Bimestre (b)" do Anexo 1: em 70.045 linhas comparadas, 97,56% batem em até R$ 1. As 1.706 divergências ficam em `outputs/e25_fluxo_divergencias.csv`. Concentram-se em totais e subtotais e em poucos estados (acumulado que não cresce ou fluxo negativo na própria publicação); é problema de qualidade da fonte, para o E2.7.

## 8. Decisões para o Pedro
1. `TransferenciasDoFUNDEB` está em "demais receitas" como receita bruta; a contrapartida está na despesa. Tratar no E5.
2. `DemaisInversoesFinanceiras` (inversões financeiras primárias) está em "investimento".
3. `ReservaDeContingencia` está em "custeio" (normalmente zero na execução).
4. `RREO6FPM` (cota-parte do FPM recebida pelo estado) entra em "FPE/FPM". Os dois códigos de FPE (`RREO6FPE` e `RREO6CotaParteDoFPE`) têm o mesmo conteúdo, e cada ente usa um deles.
5. As linhas de apuração alternativa da LC 156/2016, resultado nominal e dívida estão no dicionário como memo, fora do P2.
