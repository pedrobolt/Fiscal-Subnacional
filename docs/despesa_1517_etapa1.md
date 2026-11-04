# Despesa em caixa 2015–17: etapa 1, sem download (4/11/2026)

Critério e variantes: `scripts/despesa_1517_etapa1.R` e `docs/proposta_e62_e5_fase2.md`, 2.3. Números de `outputs/despesa1517_etapa1_{ufano,ano,resumo}.csv` (UF-ano no b6, 2018–2025, 27 UFs, 216 UF-anos). Diferenças em % do caixa do Anexo 6 (paga + restos a pagar processados pagos + RPNP pagos).

## Resultado

| Comparação | UF-anos dentro de 1% | Mediana da diferença |
|---|---|---|
| Variante A (fixada antes: pessoal, outras correntes, investimentos, inversões, com intraorçamentárias) contra a **paga** do A6 | 38,0% | 4,51% |
| Variante B (A sem inversões) contra a paga do A6 | 25,5% | 3,67% |
| Variante C (**declarada depois de ver A e B**: como A, mas sem intraorçamentárias até 2022) contra a paga do A6 | 94,0% | 0,00% |
| Variante A contra o **caixa** do A6 (sem RP pagos) | 9,3% | -1,22% |

Por ano, % de UF-anos dentro de 1% (A / C): 2018 14,8 / 85,2; 2019 7,4 / 88,9; 2020 0 / 100; 2021 0 / 100; 2022 0 / 96,3; 2023 88,9 / 88,9; 2024 92,6 / 92,6; 2025 100 / 100.

## Leitura

1. **Os anexos concordam na mesma base.** O Anexo 1 e o Anexo 6 batem em 2023–2025 com as intraorçamentárias, e em 2018–2022 só sem elas: o total da despesa primária do Anexo 6 passou a incluir as intraorçamentárias em 2023 (a magnitude das intra ainda não está em CSV; será medida no E5.0). Isso é uma quebra de nível de conceito **no próprio Anexo 6**, de todas as UFs, em 2023; a variante C reproduz o Anexo 6 e é a que vale para a reconstrução. A escolha de C é posterior ao resultado e está marcada assim; A, fixada antes, **não passa** sozinha no critério.
2. **Os restos a pagar pagos não cabem na tolerância.** A diferença entre a paga e o caixa do Anexo 6 tem mediana entre 3,8% e 5,9% do caixa por ano. A reconstrução só com as pagas do Anexo 1 fica fora do critério de 1%; os RP pagos têm de entrar.
3. **Consequência para 2015–17:** a etapa 2 (Anexo 7, ou RP pagos de outra fonte) é necessária e continua depois da carga histórica, com no máximo 2 conexões. Antes, falta checar se as colunas "Em AAAA" do Anexo 6 de 2015–17 trazem o pagamento de RP, o que dispensaria o Anexo 7.
4. **Pendente para o E5:** o degrau de 2023 na despesa total (intraorçamentárias) em todas as UFs, que se soma ao degrau do RPPS; a mudança de conceito do Anexo 6 em 2023 precisa entrar nas dummies do E5 e na harmonização, e não foi tratada na nota de quebras. Não foi testado se o degrau aparece no primário do BCB.
