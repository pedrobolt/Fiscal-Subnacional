# Nota de quebras (E2.8)

Inventário das quebras de série conhecidas nos dados do RREO, do Anexo 3 e da DCA dos estados, com causa, tratamento e limitações. Números em `outputs/quebras_e28.csv` (gerado por `scripts/quebras_e28.R`; git-ignored).

## 1. Tabela

| Quebra | UFs | Período | Tamanho | Tratamento |
|---|---|---|---|---|
| Anexo 6 vazio na API | RS | 2018 b1–b5 | 5 bimestres | Fluxos NA (nunca zero); total anual vem do b6; bimestres em `conceito_original`; agregado rotulado "parcial" |
| RPPS separado no Anexo 6 (layout 2023+) | 27 | 2023 em diante | RPPS/receita: mediana 7,5%, máximo 25,8% | Ver 3.2 |
| Mudança de fonte de recursos no pessoal (RPPS → fonte não RPPS), **só na série sem RPPS** | RJ | 2025 b1 em diante | ver seção 6 | Ver 3.3 e seção 6 |
| idem | PR | 2025 b6 em diante | ver seção 6 | idem |
| idem | RS | 2025 b5 em diante | ver seção 6 | idem |
| Entrada das contas "com fontes RPPS" no pessoal, **série com RPPS** | RS | 2023 b1–b6 | ver seção 6 | Degrau na série com RPPS (seção 6) |
| Contribuições patronais ao IPE-Saúde saem de pessoal para outras despesas correntes | RS | 2024 em diante | R$ 827 milhões até 2023 (NT 04/2024-RRF, SEFAZ/RS) | Queda de pessoal sem efeito no total; considerar na comparação de pessoal entre exercícios |
| Fator bruto/líquido do Anexo 3 | UF × imposto | anual | 128 quebras (> 2%); 50 de 108 UF-impostos com ao menos 1 | Flag `flag_quebra_fator`; ano corrente menos confiável; não bloqueia |
| Flags do conceito único | várias | — | 186 `conceito_original`; 6 `custeio_nao_positivo`; 12 `quebra_na_troca_de_conceito` | Flags automáticos, sem correção manual |

**Correção de 04/11/2026 (seção 6):** as datas acima valem para a série **sem RPPS**; elas estavam digitadas no script e agora saem de uma regra explícita, que as reproduz. Na série **com RPPS** (oficial desde o #52) **não há quebra de pessoal** em RJ/PR/RS em 2025: é uma troca de fonte de recursos dentro do mesmo gasto. O texto anterior desta nota tratava como alteração do total, e as magnitudes da tabela (até 6,97, 9,05 e 7,41 bi por bimestre; 30–41% da despesa) saíram do cálculo antigo e foram retiradas. A redação anterior do contrato ("2º sem. 2025" para os três) só diverge no RJ, que começa em 2025 b1.

## 2. Causas

- **RS 2018:** a API devolve 0 linhas para o Anexo 6 b1–b5, embora o extrato mostre entrega. Causa não esclarecida; o layout de 2018 vale para todos os entes, então não se atribui a ele. Fica como limitação.
- **RPPS 2023:** o layout 2023+ do Anexo 6 passa a separar o RPPS (linhas "sem RPPS"). Antes, o tratamento do RPPS não é verificável por UF (E3.6).
- **RJ/PR/RS 2025:** o pessoal **sem RPPS** sobe de forma que o RGF (Executivo, liquidado) não acompanha, e a parcela do pessoal com fontes RPPS cai no mesmo valor aproximado (seção 6). Leitura: o gasto passou a ser registrado com fonte não RPPS (por exemplo, a complementação financeira do Tesouro ao déficit do RPPS, tratada como "inativos e pensionistas" no Parecer SEI nº 1331/2024/MF, conforme a NT 04/2024-RRF da SEFAZ/RS). **A origem normativa não está confirmada:** a NT só trata da projeção do Plano de Recuperação Fiscal do RS; não encontrei nota explicativa do RREO/RGF de RJ, PR ou RS de 2025 que explique a mudança.
- **Fator do Anexo 3:** troca de regime de dedução (FUNDEB, cota-parte) e de plano de contas entre layouts; 22 das 163 trocas de conceito ainda geram quebra anual do fator.

## 3. Regra de uso no E5 (ordem aprovada em 29/10/2026)

Harmonizar quando possível (RPPS separável desde 2023) → dummy de quebra (com robustez excluindo a UF) → excluir só em último caso. Para RJ/PR/RS a harmonização pela proporção do RGF não é o primeiro passo (ver 3.3). A dummy vale enquanto a quebra durar: pulso para quebras pontuais; degrau para mudanças que persistem. Se a UF reverter, o alerta (b) detecta e o degrau termina ali.

1. **RS 2018:** sem harmonização possível; fluxos NA; categorias do P2 só desde 2019, de qualquer modo.
2. **RPPS:** usar os totais "sem RPPS" do layout 2023+ como referência. Só as categorias demais receitas e pessoal são afetadas e a separação por categoria não existe na série anterior; logo, nessas duas categorias o RPPS fica em dummy de degrau 2023+, e o total e o primário são harmonizados.
3. **RJ/PR/RS (decisão de 29/10/2026, ordem diferente da geral; revista em 04/11/2026: vale só para a série sem RPPS, ver seção 6):** **não** harmonizar o primário, que é a variável-alvo, pela proporção do RGF, porque o RGF cobre só o Executivo e em base liquidada, e a proporção é uma estimativa com erro do mesmo tamanho do ajuste. Usar: (i) degrau na despesa total e no primário, de 1 a partir do início de cada UF, inclusive na projeção de 2026; (ii) categoria pessoal harmonizada com linha própria de excedente (`outputs/quebras_pessoal_harmonizado.csv`); (iii) harmonização pela proporção do RGF apenas como sensibilidade; (iv) robustez excluindo as três UFs.

## 4. Detecção automática na rodada mensal

Alertas em tabela única (`tipo, subtipo, cod_ibge, serie, exercicio, periodo, valor, limite, detalhe`), que vão para a aba de alertas do Excel do E6; não bloqueiam a projeção.

- **(a)** conta ou coluna do RREO/Anexo 3 sem correspondência no dicionário. Histórico: 0.
- **(b)** variação contra o mesmo bimestre do ano anterior: |Δ − mediana(Δ histórico)| > 4 × MAD do Δ da própria UF e > 1% da receita da UF (mínimo de 3 Δ no histórico). No histórico acusa 1.618 saltos em 214 UF-anos, incluindo as quebras conhecidas (RPPS: 227 em 2023, 27 UFs; pessoal RJ/PR/RS 2025).
- **(b) × RGF:** quando o salto de pessoal vem com RREO − RGF > 20 p.p. no crescimento anual, emite `reclassificacao_pessoal`. É extensão do alerta (b) declarada no contrato; no histórico, 128 UF-bimestres com suspeita de 1.233 comparáveis, 27 deles também em (b).
- **(c)** troca de regime, fator instável, defasado ou ausente, `conceito_original`, `custeio_nao_positivo`, `quebra_na_troca_de_conceito`.
- **(d)** entrega atrasada (> 30 dias do prazo) ou retificação, pelo extrato.

### Status e prioridade
`marcar_conhecidas()` marca as quebras da tabela 1 como `conhecida` (RPPS 2023 em pessoal e demais receitas; reclassificação RJ/PR/RS com Δ > 0 a partir do início; RS 2018 b1–b5; flags do conceito único; quebras anuais do fator até 2025) e elas não disparam de novo; o restante é `nova`. `priorizar_alertas()` ordena as novas por |Δ|/receita da UF (alerta (b)) e devolve o resumo por tipo e status. Resultado sobre o histórico (`outputs/alertas_resumo.csv`, `alertas_novos_por_rodada.csv`, `scripts/alertas_priorizados.R`): ver STATUS.

## 5. Limitações

- 128 saltos brutos de pessoal (10,4%) exigem triagem; o cruzamento com o RGF reduz a revisão, mas só existe para pessoal.
- O alerta (b) usa MAD sobre história curta (mín. 3 Δ): UFs de série curta ou volátil geram falsos positivos.
- RGF: Executivo, liquidado; compara crescimento, não nível.
- A conexão do alerta à rodada mensal e ao Excel é feita no E6.1/E6; aqui o módulo (`R/quality/alertas.R`) está testado com dados sintéticos.

## 6. Regra de início da reclassificação de pessoal (fixada em 04/11/2026, antes de computar)

Motivo: as datas de início de RJ/PR/RS (RJ 2025 b1, RS 2025 b5, PR 2025 b6) estavam digitadas em `scripts/quebras_e28.R` e em `INICIO_RECLASSIFICACAO`, e não saíam de uma regra. A regeneração (`scripts/reclassificacao_e28b.R`) substitui isso por uma regra explícita, aplicada às 27 UFs e a **duas versões** da série de pessoal do Anexo 6: **sem RPPS** (contas "com fontes RPPS" fora, como na nota de 29/10) e **com RPPS** (série oficial desde o #52).

**Regra (parâmetros em `R/quality/reclassificacao.R`, fixados antes de ver o resultado):**
1. Pessoal do RREO (fluxo do bimestre, conceito original do Anexo 6) contra o **mesmo bimestre do ano anterior**: variação ≥ **25%**.
2. **Sem salto correspondente no RGF**: variação do RREO menos a do RGF (Executivo, soma dos 2 meses do bimestre) ≥ **20 p.p.**
3. **Persistência**: as condições 1 e 2 valem em pelo menos **2 bimestres consecutivos** (a corrida atravessa a virada de ano). Bimestre sem RGF ou sem variação não sinaliza e quebra a corrida.
4. **Início** = primeiro bimestre da corrida. Só as corridas que começam em **2024 b1 ou depois** são candidatas a "reclassificação de 2025"; as anteriores são reportadas como informação.
5. Magnitude da corrida: variação média do RREO e do RGF e **excedente** (pessoal do RREO menos o esperado pela variação do RGF) em R$ e em % da despesa primária dos mesmos bimestres.
6. Sensibilidade declarada, sem mudar a regra: x ∈ {15%, 25%, 40%}, pp ∈ {10, 20, 30}, persistência ∈ {2, 3}; o início de RJ/PR/RS é reportado em cada combinação.

Mudança de qualquer parâmetro depois de ver o resultado entra no STATUS como "mudança pós-resultado".

### 6.1 Resultado da regeneração (04/11/2026; bruto do RREO baixado em 03/11, RGF Anexo 1; saídas `outputs/reclass_*.csv`)

**Corridas na janela (início em 2024 b1 ou depois), por versão da série de pessoal.** Excedente = pessoal do RREO menos o esperado pela variação do RGF, somado nos bimestres da corrida.

| Versão | UF | Início | Fim | Bimestres | RREO (var. média) | RGF (var. média) | Excedente (R$ bi) | % da despesa |
|---|---|---|---|---|---|---|---|---|
| Sem RPPS | PI | 2024 b3 | 2024 b4 | 2 | 39% | 10% | 0.56 | 8.3% |
| Sem RPPS | RJ | 2025 b1 | 2025 b3 | 3 | 61% | 4% | 8.85 | 21.3% |
| Sem RPPS | RJ | 2025 b5 | 2025 b6 | 2 | 125% | 14% | 13.81 | 28.5% |
| Sem RPPS | PR | 2025 b6 | 2026 b4 | 5 | 68% | 8% | 15.45 | 20.8% |
| Sem RPPS | RS | 2025 b5 | 2026 b1 | 3 | 82% | 15% | 11.39 | 24.2% |
| Com RPPS | PI | 2024 b3 | 2024 b4 | 2 | 34% | 10% | 0.62 | 8.2% |

**Série com RPPS, corridas fora da janela que importam ao E5:**
- RS 2023 b1 a 2023 b6 (6 bimestres): RREO 61% contra RGF 8%, excedente de R$ 17.90 bi (24.5% da despesa). Não aparece na série sem RPPS.
- Outras corridas anteriores a 2024 (ambas as versões) estão em `outputs/reclass_runs_{sem,com}.csv` e são só informativas.

**Pessoal por fonte, R$ bi (RJ, PR, RS).** Com RPPS = sem RPPS + fontes RPPS.

| UF | Período | Sem RPPS | Fontes RPPS | Com RPPS |
|---|---|---|---|---|
| RJ | 2024 (ano) | 34.80 | 27.31 | 62.11 |
| RJ | 2025 (ano) | 61.08 | 6.98 | 68.06 |
| RJ | 2025 b1-b4 | 32.91 | 4.68 | 37.59 |
| RJ | 2026 b1-b4 | 40.80 | 3.53 | 44.33 |
| PR | 2024 (ano) | 26.11 | 14.66 | 40.77 |
| PR | 2025 (ano) | 37.04 | 6.21 | 43.25 |
| PR | 2025 b1-b4 | 16.88 | 9.42 | 26.29 |
| PR | 2026 b1-b4 | 24.79 | 3.62 | 28.41 |
| RS | 2024 (ano) | 34.23 | 19.26 | 53.50 |
| RS | 2025 (ano) | 48.12 | 9.85 | 57.97 |
| RS | 2025 b1-b4 | 23.51 | 12.21 | 35.72 |
| RS | 2026 b1-b4 | 29.59 | 7.35 | 36.94 |

- RJ 2025/2024: sem RPPS +76%, com RPPS +10%; fontes RPPS -20.33 bi.
- PR 2025/2024: sem RPPS +42%, com RPPS +6%; fontes RPPS -8.45 bi.
- RS 2025/2024: sem RPPS +41%, com RPPS +8%; fontes RPPS -9.41 bi.

**Sensibilidade (grade 3 × 3 × 2 declarada na regra).** Na série sem RPPS o início de RJ, PR e RS é o mesmo (2025 b1, b6 e b5) nas 9 combinações de x e pp com persistência 2; ver `outputs/reclass_grade_sem.csv` para a persistência 3. Na série com RPPS, só RJ aparece (2024 b6) e só na combinação mais frouxa (x = 15%, pp = 10).

### 6.2 Conclusões

1. **A hipótese do Pedro se confirma na direção.** O salto de +41% a +75% do pessoal (informe anterior) é da série **sem RPPS**; na série com RPPS o pessoal de RJ/PR/RS cresce de forma normal em 2025. A queda das fontes RPPS compensa a alta do resto: é troca de fonte dentro do mesmo gasto, e não aumento do gasto.
2. **Sem sinal de dupla contagem** na série com RPPS: se a complementação do Tesouro fosse contada como pessoal e o benefício pago com fonte RPPS também, a série com RPPS subiria quase tanto quanto a série sem RPPS, e não sobe (tabela acima). É um teste de nível por UF, não uma auditoria de lançamentos.
3. **Datas:** RJ 2025 b1, RS 2025 b5 e PR 2025 b6 estavam certas **para a série sem RPPS** e agora saem de uma regra. Leitura, não testada: no PR (2025 b6) e no RS (2025 b5) o salto fica concentrado num bimestre (acima de 100%), o que sugere ajuste retroativo dentro do ano, em que a mudança de fonte entra no acumulado e o fluxo do bimestre absorve o que veio antes.
4. **Por que os arquivos de 30/10 não reproduziam:** os valores de `outputs/quebras_pessoal_rgf.csv` do diretório de trabalho (30/10) coincidem com a série com RPPS (RS 2025 b5: variação de 8%; PR 2025 b6: 4%), enquanto a nota media a série sem RPPS; é a explicação mais simples, mas não verifiquei a data de geração contra a versão do dicionário. As datas da nota estavam certas para a série sem RPPS; a nota estava incompleta ao não dizer que valem só para ela, e as magnitudes antigas (30–41% da despesa) saíram de um cálculo que não reproduzi.
5. **Novos achados:** (i) **RS 2023** na série com RPPS: as contas "com fontes RPPS" entram no pessoal e há degrau; (ii) **PI 2024 b3–b4** aparece nas duas versões (RREO +34% a +39% contra RGF +10%), fora de RJ/PR/RS e sem relação com RPPS: fica como alerta novo, sem análise; (iii) a origem normativa da troca de fonte em 2025 **não está confirmada**.

### 6.3 O que muda nas dummies do E5

| Série | Antes (29/10) | Agora |
|---|---|---|
| Com RPPS (oficial) | degrau RJ/PR/RS de 2025 em diante em pessoal, despesa total e primário | **sai** em pessoal (sem quebra). Despesa total e primário com RPPS: **a verificar** antes de retirar (o teste desta seção é só de pessoal). |
| Com RPPS (oficial) | sem dummy específica de RS | **entra** degrau de RS em 2023 (ou pulso, a decidir no E5.0) nas séries que incluem pessoal |
| Sem RPPS (referência da LDO) | degrau RJ/PR/RS de 2025 em diante | **mantém**, com as datas acima |
| Harmonização pela proporção do RGF | sensibilidade | sensibilidade, só para a série sem RPPS |

`INICIO_RECLASSIFICACAO` (usada por `marcar_conhecidas()` nos alertas) continua com as datas da série sem RPPS e marca como "conhecida" alertas de pessoal da série com RPPS que não têm essa quebra; na rodada de 03/11 isso atingiu 3 alertas. **Correção proposta, sem código até aprovação:** restringir o rótulo à série sem RPPS.
