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

## 8. Decisões de 28/10/2026 (Pedro) e o que mudou
1. **FUNDEB (corrigido em 28/10/2026 depois do Anexo 3 e da DCA):** a decisão original era manter impostos e FPE pelo bruto. Os dados mostraram que o Anexo 6 não tem um único conceito: em parte dos UF-anos a receita de impostos vem líquida do FUNDEB e da cota-parte dos municípios, em parte bruta de uma ou das duas. A base do P2 passa a ser o Anexo 6 em **conceito único, líquido de FUNDEB e cota-parte**, com despesa sem esses repasses (seção 10). `TransferenciasDoFUNDEB` segue como categoria própria ("receita FUNDEB"). A dedução de formação do FUNDEB não está nos Anexos 1 e 6; está no Anexo 3 (linha `DeducaoDeReceitaParaFormacaoDoFUNDEB`, a partir de 2022) e, anual por imposto, na DCA.
2. **Inversões financeiras:** `DemaisInversoesFinanceiras` passa a "demais despesas de capital" (fora de investimento).
3. **Reserva de contingência:** "demais despesas". No bruto observado ela só tem dotação (nenhuma coluna paga); `sinalizar_reserva_paga()` roda no script e avisa se aparecer valor pago (hoje, 0 linhas).
4. **FPM:** só o DF (53) tem `RREO6FPM`; fica em "FPE/FPM" com nota. Os 26 outros estados usam `RREO6CotaParteDoFPE` para o FPE, e o DF usa `RREO6FPE` (mesmo conteúdo, códigos diferentes).
5. **Protocolo do E5:** despesa em caixa só desde 2018 (no máximo 8 anos-alvo até 2025). A avaliação do P2 é em painel de 27 UFs, não série a série com piso de 10 anos. Registrado em `docs/plano.md` (E5) e `docs/STATUS.md`.
6. As linhas de apuração alternativa da LC 156/2016, resultado nominal e dívida seguem como memo, fora do P2.

## 9. RREO dos estados antes de 2015: o que se verificou
Só verificação, sem download em massa.
- **API do Siconfi (testada em 28/10/2026):** o Anexo 6 de SP com 2014 volta 0 itens; com 2015, 186. O extrato de entregas de SP e do DF em 2013 e 2014 lista só o balanço anual (QDCC em 2013, DCA em 2014), sem RREO. Portanto **não há RREO bimestral dos estados pela API antes de 2015**.
- **Tesouro (páginas oficiais):** a página de dados consolidados cita, além do Finbra municipal (1989–2012) e do QDCC (2008–2012), uma planilha "Execução Orçamentária de Estados, 1995 a 2013" (`pge_exec_orc_estados_1995_2013.xls`). **Não abri o arquivo**: periodicidade, colunas e se há despesa paga ou só liquidada/empenhada estão sem verificação. Pelo contexto das outras séries do Tesouro dessa época, deve ser anual, o que não serve ao RREO bimestral.
- O SISTN foi o sistema de coleta anterior ao Siconfi, mas não achei série pública do RREO dos estados nele. Também não confirmei se o Tesouro mantém esse acervo em algum arquivo.
- **Compatibilidade com o dicionário:** mesmo que exista, uma série anual sem a coluna paga não alimentaria o caixa (que só existe a partir de 2018 no Anexo 6) e caberia, no máximo, na liquidação, como o layout de 2015–17.
- **Próximo passo, se você quiser:** localizar e abrir só a planilha de 1995–2013 (um arquivo) para ver colunas e granularidade, e checar com a STN se o SISTN tem RREO bimestral dos estados guardado.

## 10. Conceito único do Anexo 6 (PR de 28/10/2026)
**Problema.** Comparando o 6º bimestre do Anexo 6 com a DCA (bruto, dedução de transferências constitucionais, dedução do FUNDEB), o conceito do Anexo 6 varia por UF, imposto e ano. No ICMS (297 UF-anos): líquido das duas deduções em 170, líquido só do FUNDEB em 93, sem dedução em 9, só da cota-parte em 1 e fora de qualquer combinação em 24 (`outputs/conceito_a6_dca.csv`). Onde a receita vem bruta de algo, a despesa carrega o repasse em "outras despesas correntes".

**Ajuste.** `ajuste_conceito_unico()` retira de receita e despesa, por UF × imposto × bimestre, o que o Anexo 6 não deduziu: parcela da DCA do ano (ou mediana do imposto, se a DCA não mostra) × bruto do Anexo 3 calibrado. Ano corrente (sem DCA): último conceito observado. O resultado primário não muda (tautologia, verificada em `outputs/conceito_unico_bimestral.csv`).

**Validação do ajuste** (`validar_conceito_unico()`, bimestres de 2018 em diante com despesa em caixa):
- Custeio (outras despesas correntes) reconstruído deve ser positivo: 6 bimestres UF violam (RR 2018–19, MA 2019, MG 2019), `outputs/conceito_unico_violacoes_positividade.csv`.
- Sem quebra na troca de conceito: das 11 trocas, a variação da razão custeio/receita reconstruída fica abaixo do percentil 90 das variações sem troca em 9 (inclusive SP 2022→2023) e é menor que a do Anexo 6 sem ajuste em 9. Violam o limite RR 2019 e PA 2022; RR 2019 também piora em relação ao Anexo 6 (`outputs/conceito_unico_trocas.csv`).
- Não reconstruíveis (algum imposto fora de regime): 186 dos 1.885 bimestres UF, nenhum de 2022 em diante. São excluídos do agregado e listados.

**Limitação documentada.** O ajuste supõe que o repasse não deduzido aparece em "outras despesas correntes" e que a parcela da DCA do ano vale para os dois bimestres; as violações acima são onde essa suposição falha.
