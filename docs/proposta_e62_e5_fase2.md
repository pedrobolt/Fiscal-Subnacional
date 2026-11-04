# Propostas por escrito: E6.2, E5 (P2), Fase 2, pendência da rodada, municípios e t+1

**Versão 4, CONGELADA em 04/11/2026** (decisões do Pedro de 04/11 às 10:59 incorporadas; incorpora as decisões A–F, a regeneração da reclassificação (PR #54, mergeado) e o texto do informe anterior (`docs/informe_referencia.md`, PR #55, mergeado)). Mudança posterior a esta data só com registro de data e motivo.
Números do repositório citados aqui foram lidos hoje dos arquivos; contagens de anos-alvo são aritmética de disponibilidade e devem ser regeneradas dos CSVs no relatório E5.0 (regra 7).

## Status das aprovações
- Fase 2 (seção 6) e pendência da rodada (seção 7, limite de 2 rodadas): aprovadas.
- E6.2 (seção 1): aprovado com o crescimento projetado; **gabarito reescrito** na estrutura do informe anterior (texto guardado em `docs/informe_referencia.md`, mergeado no #55).
- E5 (seção 2): despesa 2015–17 em duas etapas (aprovada); razão restante/acumulado em log, efeito de ano aleatório e deflator (confirmados).
- Reclassificação de pessoal: **regenerada** (PR #54, mergeado); resultado muda o item 2.5 e a regra 2.7.
- Decisões de 04/11 (10:59): série do informe COM RPPS sem exclusão; `marcar_conhecidas()` só na série sem RPPS (PR #56); dummies do E5 condicionadas ao teste do E5.0; PI 2024 b3–b4 analisado (nota de quebras 6.4).
- pEPA: Pedro testa a instalação binária na CNI. CONFAZ: Pedro baixa; verificação de meio dia na seção 3.

## 0. Pontos que pedem decisão ou que mudam algo

1. **A reclassificação de pessoal de RJ/PR/RS é da série sem RPPS** (PR #54, nota de quebras seção 6). Na série **com RPPS** (oficial) não há quebra de pessoal em 2025: o pessoal cresce de forma normal (RJ +10%, PR +6%, RS +8% em 2025) enquanto a parcela com fontes RPPS cai, e a sem RPPS sobe +76%, +42% e +41%. Isso casa com o "+41% a +75%" do informe anterior. A hipótese do Pedro se confirma na direção; a **origem normativa não está confirmada** (ver 2.7).
2. **Série do informe (decidido em 04/11): COM RPPS (oficial), sem exclusão de UFs.** A versão sem RPPS, com exclusão de PR e RS em 2026, fica na aba como sensibilidade e como ponte com o informe anterior. A nota [1] do informe passa a ser de conceito (ver 1, bloco 6). O tamanho da diferença de conceito está em 2.7.
3. **BCB só dá resultado primário** (SGS 4642–4644). O "acumulado dos estados pelo BCB" é de resultado; crescimento real de receitas e despesas vem do RREO. Municípios e regionais dependem da carga municipal e do consolidado.
4. **Efeito de ano aleatório:** o choque comum do ano-alvo é desconhecido; entra na variância e no intervalo, não no ponto (confirmado).
5. **Razão só para receita e despesa;** o primário sai por diferença (confirmado).
6. **Dummies do E5 (decidido em 04/11):** sai o degrau RJ/PR/RS 2025+ da série com RPPS; entram o degrau de RS em 2023 e a dummy de composição de RS em 2024 (IPE-Saúde). **Condição:** a retirada do degrau só vale se o teste do E5.0 de despesa total e primário com RPPS de RJ/PR/RS em 2025 não mostrar quebra.
7. **Rótulo "conhecida" dos alertas (decidido em 04/11, PR #56):** a reclassificação de RJ/PR/RS só marca alerta como "conhecida" na série sem RPPS; na série oficial o alerta segue "nova".
8. **PI 2024 b3–b4 (decidido analisar antes do E5):** não é quebra; ver `docs/nota_quebras.md`, 6.4. Sem dummy.

## 1. E6.2: planilha e texto do informe

**Princípio:** a planilha é gerada pela rodada a partir de `outputs/rodada/<data>/` e do arquivo de previsões. Nenhuma célula digitada; único campo livre: "comentário do analista" (vazio por padrão). Estrutura segue o informe anterior da CNI: manchete regional em R$ e % do PIB, quadro por esfera, crescimento real de receitas e despesas, nota RJ/PR/RS. O texto do informe anterior foi fornecido pelo Pedro em 04/11 e o gabarito abaixo segue a estrutura dele.

| Aba | Conteúdo |
|---|---|
| Resumo | Carimbo (data, status, commit, corte m, último dado BCB, bimestre de referência, "RODADA DE TESTE" se não oficial, versão e data das premissas); manchete regional (ponto, faixa, frase de cobertura); quadro por esfera; crescimento real projetado de receitas e despesas por esfera (blocos 3 a 5 do gabarito); alertas |
| P1 | Por esfera: ano-alvo, corte m, acumulado do ano e do mesmo período do ano anterior (SGS), variação em R$, restante(t-1), previsão (R$ bi e % do PIB), faixa e cobertura só no regional, checagem de linearidade; histórico de previsões emitidas. **m3 sombra não aparece** |
| Crescimento projetado | Por esfera (estados, municípios, regionais) e para receitas e despesas primárias: **acumulado real até o bimestre**, **projetado no ano** (do E5); série do informe (COM RPPS, todas as UFs) e sensibilidades conforme 2.7 (sem RPPS excluindo as UFs afetadas, sem RPPS bruta, harmonizada pelo RGF). Até existir E5: campo "pendente" |
| P2 estados | Categoria × bimestre e acumulado; R$ bi, variação real (IPCA período a período) e nominal vs mesmo bimestre do ano anterior; `n_ufs`; resultado primário com RPPS (oficial) e sem RPPS (referência da LDO, 2023+) |
| Gap | Série bimestral P2, P1, gap em R$ e % da receita; classe do informe e classe sem 2020–22; legenda "a classe governa só a narrativa" |
| Alertas | Grupo "último" em cima, "revisão" abaixo, contagens, entrega ausente/atrasada com peso > 5% |
| Notas | Definições, versões, quebras e tratamentos, limites, premissas |

**Gabarito do texto** (estrutura do informe anterior, guardado em `docs/informe_referencia.md`). Cada bloco é uma frase por gabarito, com campos lidos dos CSVs; o que é qualitativo vai no "comentário do analista".

1. **Manchete regional.** "A CNI projeta que os governos regionais, que abarcam estados e municípios, registrem [déficit/superávit] primário de R$ [X] bilhões ([Y]% do PIB) em [ano], [revertendo/ampliando/reduzindo] o [superávit/déficit] de R$ [X0] bilhões ([Y0]% do PIB) de [ano−1]." Campos: previsão P1 regional (p1.csv), PIB das premissas, realizado do ano anterior (SGS 4642). Verbo e sinal por condicional.
2. **Acumulado dos estados pelo BCB.** "No acumulado até [mês], o [superávit/déficit] dos estados [recuou/subiu] de R$ [A0] bilhões para R$ [A] bilhões na comparação com o mesmo período de [ano−1]." Campos: SGS 4643 acumulado do ano e do mesmo período do ano anterior. Frase só sobre o resultado; concentração ("a piora se concentra nos estados") é condicional: aparece se a variação dos estados for a maior das três esferas.
3. **Estados.** "As despesas primárias devem registrar [expansão/queda] real de [d]% em [ano], [razão] o crescimento projetado para a arrecadação ([r]%)." Campos: E5 (estados, despesa e receita primárias, série com RPPS, todas as UFs, deflator da seção abaixo). Frase seguinte: "Até [mês], as despesas primárias cresciam acima da arrecadação em [n] das [N] UFs": contagem direta do P2 por UF no último bimestre. Contexto (Propag, ano eleitoral, operações de crédito do BCB) **fica no comentário do analista**.
4. **Municípios.** "A CNI projeta crescimento real de [d]% das despesas [e/após] [variação do ano anterior], e [r]% das receitas ([r0]% em [ano−1]). [Mesmo assim, as despesas não superam as receitas / as despesas superam as receitas], e os municípios devem encerrar o ano com [superávit/déficit] de R$ [X] bilhões [conceito BCB]." Campos: E5 municipal (pendente), resultado = P1 municipal (SGS 4644). Até a carga municipal fechar: "pendente".
5. **Conjunto regional.** "No conjunto, as despesas primárias dos governos regionais devem crescer [d]% em termos reais em [ano], ante [d0]% em [ano−1], com destaque para [categoria de maior contribuição]; as receitas devem avançar [r]%, ante [r0]%." Campos: E5 consolidado (pendente), ano anterior realizado do RREO; "destaque" = categoria de maior contribuição ao crescimento (do P2 por categoria).
6. **Notas.** [1] Nota de conceito: "Receitas e despesas no conceito consolidado dos estados: incluem as fontes do RPPS e excluem as operações intraorçamentárias. O informe anterior usava o conceito sem RPPS e excluía RJ, PR e RS." (A sensibilidade sem RPPS, com RJ a partir de 2025 b1 e PR e RS no 2º semestre de 2025, fica na aba Crescimento projetado.) [2] Propag: comentário do analista. [3] "No conceito do Banco Central" fixo.

Campos de crescimento projetado preenchidos quando o E5 existir; antes, "pendente". O **ano anterior** (d0, r0) vem do RREO realizado, não do E5.

**Deflator do projetado:** o contrato manda IPCA período a período. As premissas têm IPCA **anual**. Para os bimestres ainda não realizados proponho: IPCA restante do ano = (1 + IPCA anual das premissas) / (1 + IPCA acumulado realizado no ano) − 1, distribuído de forma uniforme nos meses restantes. Registrar no contrato como convenção.

**Ressalvas:** a classe do gap saiu "quebra_conhecida" nos quatro bimestres de 2026 da rodada de teste, então fica na aba Gap, e o texto usa o gap em % da receita. P1 (previsão) e P2 (realizado) nunca aparecem lado a lado sem rótulo. % do PIB e variação real usam as premissas oficiais (a rodada de teste usou fixture).

## 2. E5 (P2): protocolo (versão 4, congelado)

### 2.1 Objeto
- Estados agora (categorias do dicionário). Receita: ICMS, IPVA, FPE, FUNDEB (receita e dedução), demais receitas. Despesa: pessoal, custeio, investimento, demais despesas e de capital. ISS, IPTU e FPM entram com os municípios, com o mesmo protocolo.
- **Saída exigida (C7):** crescimento real projetado no ano de receitas e despesas **primárias** por esfera, dado por (acumulado observado + restante projetado), deflacionado como em 1, contra o total do ano anterior deflacionado. Estados primeiro; municípios e regionais quando o consolidado existir.
- FPE/FPM: valor da STN (reportado), com a ponte do contrato.
- Cortes b = 1..5, faixas b1–b2, b3–b4, b5 (como no P1).

### 2.2 Variável-alvo (C1)
- **Razão do restante ao acumulado**: r = restante / acumulado no corte, em log. Escolho a razão (e não a participação) porque a base natural é o passeio aleatório na razão, r(t) = r(t−1) no mesmo corte, aplicado ao acumulado de t. A participação é uma transformação monotônica da razão, então o conteúdo é o mesmo; a razão é mais direta.
- Só para linhas positivas de receita e despesa por categoria. Categorias que mudam de sinal ou ficam perto de zero (ex.: dedução do FUNDEB, linhas de RPPS) entram em nível, com a marca.
- Cancela diferenças proporcionais de conceito (líquido de FUNDEB ou de cota-parte). **Não cancela** degraus no meio do ano (RPPS 2023, reclassificação): esses seguem para as dummies da 2.5.
- Receita desde 2015, **incluindo UF-bimestres em `conceito_original`, com marca** (variante sem esses UF-bimestres como robustez). UF-anos sem b6 (ex.: RS 2018 b1–b5 sem Anexo 6) saem da amostra daquele alvo.
- **B0 (base): SRW na razão.** Também reporto o SRW em R$ do P1 (restante(t−1)) como referência cruzada; a comparação com o P1 agregado passa pela conversão à unidade original.

### 2.3 Despesa em caixa 2015–17: reconstrução (C2)
O Anexo 6 de 2015–17 não tem "pagas". Verificado no dicionário: o Anexo 1 desse layout tem **"DESPESAS PAGAS ATÉ O BIMESTRE (j)"** e "INSCRITAS EM RESTOS A PAGAR NÃO PROCESSADOS (k)", **mas não traz restos a pagar pagos**. O raw baixado hoje tem só os Anexos 1, 3 e 6.

Reconstrução proposta: **pagas dos grupos primários do Anexo 1 + restos a pagar pagos**.
- Grupos primários: despesas correntes menos juros e encargos, mais investimentos, e inversões financeiras só na parte que o Anexo 6 trata como primária; sem amortização da dívida e sem intraorçamentárias. A composição exata sai do dicionário de contas (que já separa "inversões financeiras" de "investimento"), conferida linha a linha antes de fixar.
- Restos a pagar pagos em 2015–17: provável fonte é o **Anexo 7** (restos a pagar por poder/órgão). Antes disso, checar se as colunas "Em AAAA" do Anexo 6 de 2015–17 (classificadas `saldo_rp`) trazem pagamento de RP; se trouxerem, o Anexo 7 não é necessário.
- Custo do Anexo 7, estados, 27 UFs × 6 bimestres: 162 chamadas por ano. Só 2015–17: 486. Se o teste exigir 2018–25 também: mais 1.296. Rodar **depois da carga histórica**, com no máximo 2 conexões.

**Critério fixado antes (em duas etapas):**
1. *Etapa sem download:* em 2018–2025, comparar as "pagas" do Anexo 1 (grupos primários) com a "paga" do Anexo 6. Isso mostra, sem baixar nada, o quanto resta a explicar pelos RP pagos.
2. *Etapa com Anexo 7:* reconstrução completa em 2018–2025 vs caixa do Anexo 6. **Usar 2015–17** se a diferença for ≤ 1% da despesa primária em ≥ 90% dos UF-anos (unidade: UF-ano no b6; reporto também os acumulados bimestrais). Se falhar, o liquidado entra só como sensibilidade declarada, e a despesa começa em 2018.

**Atualização de 04/11/2026 (16:41, depois do congelamento; motivo: achado das intraorçamentárias, #59).** A variante C da etapa 1 foi definida depois de ver o resultado. A etapa 2 usa agora a definição **harmonizada, fixada antes de qualquer cálculo com o Anexo 7**: alvo = caixa do Anexo 6 (paga + RP processados pagos + RPNP pagos) menos, de 2023 em diante, a intra de despesa primária paga do Anexo 1; reconstrução = pagas do Anexo 1 (Pessoal, Outras despesas correntes, Investimentos, Inversões financeiras) **sem as contas Intra em todos os anos** + RP pagos do Anexo 7 sem intra; critério: diferença ≤ 1% do alvo em ≥ 90% dos UF-anos (b6, 2018–2025). Texto completo em `docs/intra_criterios.md`, seção 2d; o critério desta seção 2.3 vale nessa definição.

### 2.4 Amostra e anos-alvo (C4)
Treino mínimo proposto: 3 anos (parâmetro a congelar). Anos-alvo por escolha (aritmética de disponibilidade; contagens a confirmar):

| Escolha | Anos-alvo (todos) | Sem 2020–22 | UF-anos (27 UFs) |
|---|---|---|---|
| Receita 2019+ (plano anterior) | 2022–25: 4 | 2023–25: 3 | 108 / 81 |
| Receita 2015+ | 2018–25: 8 | 2018, 2019, 2023–25: 5 | 216 / 135 |
| Despesa sem reconstrução (2018+) | 2021–25: 5 | 2023–25: 3 | 135 / 81 |
| Despesa com reconstrução (2015+) | 2018–25: 8 | 5 | 216 / 135 |

Esses UF-anos são brutos: caem com UF-bimestres vazios e com a unidade efetiva por choques comuns. O **relatório E5.0** (antes de congelar o protocolo) reporta, por escolha (2019+ vs 2015+; razão vs nível; com e sem despesa reconstruída), o número de anos-alvo e UF-anos efetivos, **testa despesa total e primário com RPPS de RJ/PR/RS em 2025** (para retirar o degrau) e **refaz a calibração de poder** com o T resultante: simulação com os erros históricos, para diferenças de 10% no RMSE. Se o poder continuar baixo (< 50%), os testes entram como informação e a decisão fica por magnitude e bootstrap por ano.

### 2.5 Quebras (C3): regra de 29/10, revista pela regeneração (PR #54)
Ordem: harmonizar → dummy de quebra → excluir só em último caso. Por série:

| Quebra | Série com RPPS (oficial) | Série sem RPPS (referência da LDO) |
|---|---|---|
| RPPS separado em 2023 | sem dummy específica: série contínua (as contas "com fontes RPPS" são a diferença); **exceção RS, ver abaixo** | degrau 2023+ nas categorias afetadas (demais receitas e pessoal) |
| RJ/PR/RS 2025 | **sem dummy em pessoal** (sem quebra). Despesa total e primário: **retirada condicionada ao teste do E5.0** | degrau de 2025 em diante (RJ b1, RS b5, PR b6), inclusive na projeção de 2026 |
| RS 2023 | **degrau** (decidido em 04/11; as contas "com fontes RPPS" entram no pessoal do RS; excedente maior que 20% da despesa) | sem dummy |
| RS 2024 (IPE-Saúde) | pessoal cai e outras despesas correntes sobem; total sem efeito; **dummy de composição** em pessoal e custeio (decidido em 04/11) | idem |
| Pulso 2020–21; marca LC 194 em 2022 b4–b6; choques comuns | como antes (efeito de ano aleatório) | idem |

Nada se apaga e a harmonização pela proporção do RGF continua só como sensibilidade (série sem RPPS).

### 2.6 Candidatos (lista fechada) e benchmarks (C5)
**Aceitação formal só contra o SRW (B0).** Lista:
- **B0** SRW na razão (base). **B0'** SRW em R$ (referência cruzada).
- **M1** MQO agrupado; **M2** efeitos fixos de UF; **M3** Bayes empírico (James-Stein, BLUP via `lme4`); **M4** bayesiano `rstanarm::stan_glmer`; **M5** combinação por média simples dos aceitos (BMA só para probabilidade de inclusão dos preditores, via `BMS`, não para combinar previsões).
- **Ca** (receita): previsão atualizada do ente corrigida pelo viés histórico rolante = previsão atualizada − erro médio relativo dos anos anteriores **no mesmo corte e categoria**, usando só o que existe no corte (o erro de um ano só entra depois do b6 daquele ano). Viés estimado pela média do painel por categoria e corte; variante por UF encolhida como sensibilidade.
- **Cb** (despesa): dotação atualizada × taxa histórica de execução (executado final / dotação atualizada no mesmo corte, anos anteriores).
- Preditores pré-registrados: restante(t−1) na razão; variação interanual do acumulado; dummies de 2.5; para despesa, (liquidado − pago) e (empenhado − liquidado) até o corte, em % da despesa paga do ano anterior (colunas existem no Anexo 6 desde o layout 2018+; em 2015–17, via reconstrução).
- **Reporte obrigatório, sem peso na aceitação:** por categoria e corte, o erro da previsão inicial (LOA) e da atualizada do ente (Anexo 1; Anexo 3 se a coluna `previsao` servir por categoria), com marca **"ente melhor"** quando o ente supera o modelo da faixa, e o **viés médio** das previsões dos entes. Verificado: o Anexo 1 dos estados traz receita só como "Impostos" agregado (sem ICMS nem IPVA em nenhum layout); a comparação por categoria depende do Anexo 3, ainda por conferir (conceito líquido).
- Métricas: ME, MAE, RMSE, MASE vs B0, acerto de sinal, em % da receita da UF e agregadas; **viés com tolerância |ME| ≤ |ME(B0)| + 0,1 × RMSE(B0)**; duas amostras (com e sem 2020–22); aceitação por faixa: RMSE ≥ 10% menor, melhor em mais de 50% dos pares UF-ano e dos anos, sinal e viés não piores.

Comparação: teste S do painel (Akgun et al., 2024) como principal; estatísticas C só com clusters pré-definidos (regiões); bootstrap por blocos de ano e MCS sobre a perda média por ano como complemento. Prioris do M4 (a gravar versionadas antes de rodar): coeficientes normal(0,1), intercepto normal(0,1), resíduo exponencial(1), efeitos por UF `decov(2,1,1,1)`, 4 cadeias × 2000 iterações, `adapt_delta` 0,95, semente fixa; Rhat < 1,01, ESS > 400, zero divergências, senão a célula fica sem previsão. Ordem: commit do protocolo, execução e registro no mesmo hash.

### 2.7 RJ/PR/RS nas variações do informe (C6, decisão de 04/11)
- **Decisão (04/11, substitui a regra de exclusão de 04/11 às 10:22):** o informe usa a série **com RPPS** (oficial) e **não exclui UFs**: nessa série não há quebra de pessoal em 2025. A aba mostra, como sensibilidade e ponte com o informe anterior, a série **sem RPPS** com exclusão das UFs afetadas enquanto os períodos comparados atravessam o início da reclassificação (2026 contra 2025: saem PR e RS; o RJ já é comparável; de 2027 os três entram), a versão sem RPPS bruta e a harmonizada pelo RGF. A regra de 0,5 p.p. foi retirada. A decisão de 29/10 (RGF só sensibilidade) fica.
- **Datas (regeneradas, série sem RPPS):** RJ 2025 b1, RS 2025 b5, PR 2025 b6, reproduzidas pela regra explícita (x = 25%, pp = 20, 2 bimestres) e estáveis nas 9 combinações de x e pp. O informe anterior dizia "2º semestre de 2025" para os três; só o RJ diverge.
- **Tamanho da diferença de conceito** (estados, crescimento real, IPCA mensal período a período, bimestres comparáveis; `outputs/crescimento_conceito_rpps.csv`, script `scripts/crescimento_conceito_rpps.R`):

| Grupo | 2025 vs 2024, receita COM / SEM | 2025, despesa COM / SEM | 2026 b1–b4 vs 2025, receita COM / SEM | 2026, despesa COM / SEM |
|---|---|---|---|---|
| 27 UFs | 2,5% / 3,3% | 4,7% / 8,4% | 4,8% / 5,4% | 8,5% / 10,6% |
| 24 UFs (sem RJ/PR/RS) | 1,9% / 1,9% | 3,9% / 4,0% | 4,8% / 4,7% | 8,3% / 8,7% |
| RJ | 13,0% / 10,6% | 13,0% / 49,5% | 10,6% / 9,1% | 13,8% / 17,3% |
| PR | 0,6% / 2,8% | 7,1% / 24,5% | 1,0% / 1,5% | 8,0% / 25,4% |
| RS | -0,4% / 15,8% | 4,3% / 22,5% | 1,6% / 15,8% | 4,6% / 19,0% |

  Leitura: a diferença de conceito é **3,7 p.p. na despesa dos 27 estados em 2025** e 2,1 p.p. no acumulado de 2026, toda concentrada em RJ, PR e RS (nas outras 24 UFs, 0,2 e 0,4 p.p.). **Achado a investigar no E5.0:** na série sem RPPS a **receita** do RS também muda (+15,8% contra -0,4% com RPPS), o que indica que parte da quebra do RS está em receitas com fonte RPPS; a nota de quebras trata só do pessoal. Despesa = soma das categorias primárias do dicionário; a mesma regra nas duas séries.
- **Origem normativa não confirmada.** A NT 04/2024-RRF (SEFAZ/RS) cita o Parecer SEI nº 1331/2024/MF: a complementação financeira ao déficit do RPPS entra em "inativos e pensionistas" (pessoal), e despesas com fontes RPPS ficam de fora (MDF 14ª ed.). Isso é coerente com o padrão dos dados (gasto passa de fonte RPPS para fonte não RPPS), mas a NT trata da projeção do Plano de Recuperação Fiscal do RS e não menciona mudança no RREO/RGF. Outra candidata: a Portaria STN/MF nº 924/2025, que alterou o MDF 14ª ed. (citada em RGFs de outros estados; não explica o RJ em 2025 b1). Não localizei nota explicativa do RREO/RGF de RJ, PR ou RS de 2025.
- **Dupla contagem na série com RPPS:** o teste de nível (a série com RPPS cresce muito menos que a sem RPPS; a parcela RPPS cai no valor aproximado em que o resto sobe) não mostra dupla contagem; mostra absorção. Não é auditoria de lançamentos.

## 3. Antes de 2015: CONFAZ (D)

**Atualização de 04/11/2026 (16:29, depois do congelamento; motivo: resultado da conferência do download).** O Pedro baixou três extrações (fev, jun e set/2026), guardadas sem alteração em `FISCAL_DADOS/data/raw/confaz/`. Conferência inicial: (i) o arquivo 1997–2023 tem cabeçalhos deslocados uma coluna; (ii) a extração de set/2026 veio sem a coluna de total do ICMS (o total sai pela soma das seções); (iii) os dados só são estáveis até cerca de 4 meses antes de cada extração, com revisões de 6% a 20% nos meses recentes. **Decisão: o CONFAZ não entra no E5 agora.** Fica na lista da Fase 2 (gate E7.1) como "ICMS histórico CONFAZ 1997+ para sazonalidade", a ativar só se o E5 mostrar o ICMS como ponto fraco, com as três ressalvas acima. Os critérios (a) a (d) abaixo ficam como registro do plano de verificação, não a executar agora; os arquivos não foram conferidos por mim.
Só o CONFAZ entra. RREO pré-2015, PAF e RCL 2000–2014 do Tesouro não serão usados.
- O boletim cobre ICMS, IPVA, ITCMD e taxas, e a consulta vai de 1998 em diante. Para o E5 isso é compatível com a razão: **a razão restante/acumulado do ICMS mensal por UF não depende da diferença de conceito**, o que deixa a série longa (1998+) utilizável para ICMS e IPVA, mas não para as outras categorias nem para a despesa.
- **Verificação de meio dia, com o download pelo Pedro no PC da CNI.** O que trazer: os arquivos de dados abertos como baixados, com a data do download no nome e sem sobrescrever (em `FISCAL_DADOS\data\raw\confaz\`), baixados duas vezes em dias distintos para o teste de hash. Critérios fixados antes: (a) mesmo conteúdo nas duas baixas; (b) razão CONFAZ / ICMS bruto do Anexo 3 por UF-ano, 2015–2025; (c) usar o **nível** se a razão ficar entre 0,95 e 1,05 em ≥ 90% dos UF-anos, senão só a **variação** ou a **razão intra-ano**; (d) documentar conceito, início da série, defasagem (`available_at` = dia 9 do mês m+2, prazo legal) e ausência de vintages.
- Reservas: dados abertos trazem em princípio só a versão corrente (backtest com `available_at` legal superestima a informação); ganho de informação em tempo real pequeno (cerca de um mês de ICMS e IPVA).

## 4. Municípios no caminho crítico (E)
Registro: assim que a carga terminar, propor (com prazo) o plano do **E2.2/E2.5 municipal** (dicionário de contas por layout; consolidação estados + municípios sem dupla contagem, com a regra de receita estadual líquida de cota-parte e despesa sem transferência a municípios) e a **atualização incremental dos municípios na rodada mensal** (só o que mudou no extrato de entregas, para a rodada ficar em horas, sob o limite de 2 conexões). Os campos municipais e regionais do crescimento projetado dependem disso.

## 5. 2027 (t+1) (F)
Opcional, depois dos municípios e só se sobrar tempo. Versão mínima: resultado de t em % do PIB aplicado ao PIB de t+1 das premissas, com o erro histórico dessa regra medido no backtest (mesma convenção do P1: backtest com PIB realizado, produção com premissas). Registrado no plano.

## 6. Fase 2 (aprovada; para o gate E7.1, no máximo uma)
1. BSTS (`bsts`) e regressão bayesiana com priori centrada no SRW. Ressalva: só com informação nova (os indicadores do spike-and-slab).
2. MIDAS (IBC-Br, produção industrial, varejo). Ressalva: vintages e revisões.
3. Diagnóstico de previsibilidade do erro do SRW.
4. Teste multi-horizonte de Quaedvlieg (2021) como revisão declarada do protocolo do P1 ("pós-resultado").
5. Mecanismo do m3 por UF (só lado RREO).
6. Intervalos por quantis empíricos ou conformal.
7. Painel com aprendizado de máquina.
8. FPE/FPM pela regra para t+1.
9. ICMS histórico CONFAZ 1997+ para sazonalidade (incluído em 04/11/2026; só se o E5 mostrar o ICMS como ponto fraco; ressalvas na seção 3).

## 7. Pendência da rodada (aprovada)
- Etapa **opcional** = só alimenta sensibilidade ou nota, nunca um número publicado. Hoje: RGF. DCA e Anexo 3 continuam obrigatórios.
- Falha de opcional: `etapas.csv` com "aviso", seção "Avisos" no resumo, saída 0, `status_rodada` do arquivo continua OK.
- O resumo mostra a data do último dado bom do insumo opcional; a rodada vira DEGRADADA se ele ficar defasado por **mais de 2 rodadas seguidas**.
- Testes: opcional falhando mantém OK com aviso; obrigatória falhando mantém DEGRADADA.
- Entra no próximo PR que tocar a rodada.

## Fontes
- CRAN: rstanarm 2.32.2, bsts 0.9.11, BMS 0.3.4 (2015), pEPA 1.2 (compilação).
- Akgun, Pirotte, Urga e Yang (2024), IJF 40(1), 202–228.
- Convênio ICMS 62/2005 e notas do CONFAZ via netcpa.com.br.
- Repositório: `data/dicionario_colunas_estados.csv`, `data/dicionario_contas_estados.csv`, `docs/nota_quebras.md`, `outputs/quebras_pessoal_harmonizado.csv`, `outputs/quebras_pessoal_rgf.csv`.
