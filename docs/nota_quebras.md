# Nota de quebras (E2.8)

Inventário das quebras de série conhecidas nos dados do RREO, do Anexo 3 e da DCA dos estados, com causa, tratamento e limitações. Números em `outputs/quebras_e28.csv` (gerado por `scripts/quebras_e28.R`; git-ignored).

## 1. Tabela

| Quebra | UFs | Período | Tamanho | Tratamento |
|---|---|---|---|---|
| Anexo 6 vazio na API | RS | 2018 b1–b5 | 5 bimestres | Fluxos NA (nunca zero); total anual vem do b6; bimestres em `conceito_original`; agregado rotulado "parcial" |
| RPPS separado no Anexo 6 (layout 2023+) | 27 | 2023 em diante | RPPS/receita: mediana 7,5%, máximo 25,8% | Ver 3.2 |
| Reclassificação de pessoal no RREO | RJ | 2025 b1 em diante | até 6,97 bi/bim. (30,3% da despesa) | Ver 3.3 |
| idem | PR | 2025 b6 em diante | até 9,05 bi/bim. (38,2%) | idem |
| idem | RS | 2025 b5 em diante | até 7,41 bi/bim. (40,6%) | idem |
| Fator bruto/líquido do Anexo 3 | UF × imposto | anual | 128 quebras (> 2%); 50 de 108 UF-impostos com ao menos 1 | Flag `flag_quebra_fator`; ano corrente menos confiável; não bloqueia |
| Flags do conceito único | várias | — | 186 `conceito_original`; 6 `custeio_nao_positivo`; 12 `quebra_na_troca_de_conceito` | Flags automáticos, sem correção manual |

O início da reclassificação foi medido nos dados (excedente de pessoal do RREO sobre o crescimento do RGF > 20 p.p.). Isso **corrige** a redação anterior do contrato ("2º sem. 2025"): só o PR e o RS começam no 2º semestre; o RJ começa em 2025 b1. Todas as três persistem em 2026.

## 2. Causas

- **RS 2018:** a API devolve 0 linhas para o Anexo 6 b1–b5, embora o extrato mostre entrega. Causa não esclarecida; o layout de 2018 vale para todos os entes, então não se atribui a ele. Fica como limitação.
- **RPPS 2023:** o layout 2023+ do Anexo 6 passa a separar o RPPS (linhas "sem RPPS"). Antes, o tratamento do RPPS não é verificável por UF (E3.6).
- **RJ/PR/RS 2025:** despesa de pessoal sobe de forma que o RGF (Executivo, liquidado) não acompanha; o salto não é compensado por outra categoria do RREO, então muda a despesa total e o primário publicado (ex.: PR 2025 b6, −10,97 bi contra −1,74 bi em 2024).
- **Fator do Anexo 3:** troca de regime de dedução (FUNDEB, cota-parte) e de plano de contas entre layouts; 22 das 163 trocas de conceito ainda geram quebra anual do fator.

## 3. Regra de uso no E5 (ordem aprovada em 29/10/2026)

Harmonizar quando possível (RPPS separável desde 2023) → dummy de quebra (com robustez excluindo a UF) → excluir só em último caso. Para RJ/PR/RS a harmonização pela proporção do RGF não é o primeiro passo (ver 3.3). A dummy vale enquanto a quebra durar: pulso para quebras pontuais; degrau para mudanças que persistem. Se a UF reverter, o alerta (b) detecta e o degrau termina ali.

1. **RS 2018:** sem harmonização possível; fluxos NA; categorias do P2 só desde 2019, de qualquer modo.
2. **RPPS:** usar os totais "sem RPPS" do layout 2023+ como referência. Só as categorias demais receitas e pessoal são afetadas e a separação por categoria não existe na série anterior; logo, nessas duas categorias o RPPS fica em dummy de degrau 2023+, e o total e o primário são harmonizados.
3. **RJ/PR/RS (decisão de 29/10/2026, ordem diferente da geral):** **não** harmonizar o primário, que é a variável-alvo, pela proporção do RGF, porque o RGF cobre só o Executivo e em base liquidada, e a proporção é uma estimativa com erro do mesmo tamanho do ajuste. Usar: (i) degrau na despesa total e no primário, de 1 a partir do início de cada UF, inclusive na projeção de 2026; (ii) categoria pessoal harmonizada com linha própria de excedente (`outputs/quebras_pessoal_harmonizado.csv`); (iii) harmonização pela proporção do RGF apenas como sensibilidade; (iv) robustez excluindo as três UFs.

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
