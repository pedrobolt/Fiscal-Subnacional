# E5 (estados): especificação fixada antes de rodar (4/11/2026)

Implementa o protocolo v4 (`docs/proposta_e62_e5_fase2.md`, seção 2) com a série harmonizada (com RPPS, sem intraorçamentárias de 2023 em diante). **Nenhum modelo foi rodado.** Este arquivo é commitado antes do código e dos resultados; o registro da execução (`experiments/registro.csv`, status `e5_v4`) grava o hash deste commit. Mudança depois do resultado entra como tal, com data. Aprovada em 04/11 (17:41), com a correção da amostra S (seção 9). Pontos que vão além do texto do protocolo estão marcados **[NOVO]** e listados na seção 9 para decisão.

## 1. Alvos e amostras
- **Alvos de aceitação:** receita total e despesa total (harmonizadas), cada uma em três faixas (b1–b2, b3–b4, b5): 6 células. Primário = receita − despesa, por diferença (sem modelo próprio). **[NOVO]** As categorias (ICMS, IPVA, FPE, pessoal, custeio, investimento, demais) são **diagnóstico**: recebem os mesmos candidatos e métricas, sem aceitação própria; a previsão oficial de cada alvo vem do modelo aceito para o total, aplicado ao total diretamente (não à soma das categorias). Motivo: 6 células já têm poder baixo (E5.0); 6 × 7 categorias multiplicam comparações sem ganho de decisão.
- Variável modelada: log da razão r = restante/acumulado no corte, só para séries positivas. Séries de sinal misto (dedução do FUNDEB, linhas RPPS, "intra não alocada") entram em nível, só no B0' (SRW em R$), sem candidatos.
- **Receita:** 2015+, 27 UFs, incluindo UF-bimestres `conceito_original` com marca. Alvos 2018–2025 (8 anos), 214 UF-anos no total; as contagens sem 2020–22 (5 anos, 133 UF-anos) são do E5.0 (`docs/relatorio_e5_0.md`, seção 1); as da amostra S (seção abaixo) saem do CSV na execução. Robustez: sem os UF-bimestres `conceito_original`.
- **Despesa:** 2018+ (D1): alvos 2021–2025 (5 anos), 134 UF-anos (sem 2020–22: 3 anos, 81 UF-anos, E5.0). A reconstrução 2015–17 só entra se a etapa 2 (Anexo 7, depois da carga histórica) passar; nesse caso a despesa 2015+ é rodada como **adendo versionado**, sem alterar os resultados desta especificação.
- Treino: janela expansiva, mínimo de 3 UF-anos válidos anteriores e o ano anterior válido. Em cada corte só entram dados com `available_at` ≤ data do corte (regra do contrato; testes de vazamento existentes). Comparação sempre nas **mesmas células UF-ano-corte** para todos os candidatos e o B0 (interseção).
- **Amostras de avaliação:** (A) completa; (S) **sem 2020–21 no treino e no teste, com 2022 dentro e marcado** (LC 194 via `d_resto`/`d_base`). Sensibilidade adicional, sem peso na aceitação: sem 2020–22. Variantes de robustez: sem o RJ; sem UF-bimestres `conceito_original` (receita); sem RS.

## 2. Candidatos (lista fechada)
Estimados por faixa, com efeito fixo de corte dentro da faixa. Preditores comuns a M1–M4 (**pré-registrados**):
- `x1` = log r(t−1) no mesmo corte; `x2` = log do acumulado real (IPCA, como em 1) de t sobre o de t−1; dummies de quebra (seção 3);
- só despesa: `x3` = (liquidado − pago) e `x4` = (empenhado − liquidado) até o corte, em % da despesa paga do ano anterior (Anexo 6 desde 2018). **[NOVO]** O numerador de 2023 em diante inclui intra (não separável), então 2023 entra com a dummy `d_intra23` nesses dois preditores.
- `x2`, `x3`, `x4` padronizados (média e desvio do treino).

| Id | Descrição |
|---|---|
| B0 | SRW na razão: log r̂(t) = log r(t−1). B0': SRW em R$ (referência cruzada, sem aceitação) |
| M1 | MQO agrupado |
| M2 | MQO com efeito fixo de UF |
| M3 | Bayes empírico: `lme4::lmer` com (1 \| UF) + (1 \| ano); BLUP; ano novo previsto no nível da população |
| M4 | `rstanarm::stan_glmer`, mesma estrutura de M3, prioris da seção 6 |
| M5 | média simples das previsões em log r dos candidatos aceitos entre M1–M4, Ca, Cb |
| Ca (receita total) | previsão atualizada do Anexo 1 menos o viés relativo histórico rolante no mesmo corte (média do painel; variante por UF encolhida só como sensibilidade); o erro de um ano só entra depois do b6 dele. **[NOVO]** r̂ = (P̂ − A)/A com P̂ e A no conceito do Anexo 1, para não misturar conceitos |
| Cb (despesa total) | dotação atualizada × taxa histórica de execução (executado final / dotação atualizada no mesmo corte, anos anteriores); mesma conversão para r̂ |

Se faltar previsão ou dotação do ente em algum UF-ano-corte, Ca/Cb ficam sem previsão ali (marca), sem imputação. BMS só para probabilidade de inclusão dos preditores (descritivo), nunca para combinar previsões. Reporte obrigatório, sem peso na aceitação: erro da LOA e da previsão atualizada de cada ente, marca "ente melhor" e viés médio.

## 3. Dummies de quebra (série com RPPS harmonizada)
Quebra com data b* no ano k: `d_resto` = 1 se ano = k e corte < b* (a quebra cai no restante de t); `d_base` = 1 se ano − 1 = k e corte < b* (a quebra distorce r(t−1)). Quebra desde o b1 do ano k afeta só a variação interanual do acumulado: `d_yoy` = 1 se ano = k.
- RS 2023 (degrau do RPPS no pessoal, b1–b6): `d_yoy`, em despesa e em pessoal.
- RS 2024 (IPE-Saúde, composição): `d_yoy` em pessoal e custeio; total sem efeito.
- LC 194/2022 (marca em 2022 b4–b6): `d_resto` (2022) e `d_base` (2023) em receita total e ICMS.
- Pulso 2020–21 e choques comuns: efeito de ano aleatório (M3, M4); em M1, M2 e B0 ficam sem tratamento (é parte do que a amostra S mede).
- **Sem** degrau RJ/PR/RS 2025+ (E5.0: nenhuma quebra em despesa e receita totais; RJ acompanhado, com variante sem o RJ). Série sem RPPS (sombra): degraus de 2023 (demais receitas e pessoal) e de 2025 (RJ b1, RS b5, PR b6; receita do RS b5 em demais receitas).
- Intra 2023: a harmonização já tira o degrau; sem dummy.

## 4. Métricas e aceitação (por alvo × faixa)
Erro do total anual projetado: e = (T̂ − T)/T, com T̂ = A·(1 + r̂) e T o total do ano (b6), em % do total da própria UF. Reportadas: ME, MAE, RMSE, MASE vs B0, acerto de sinal (sinal do crescimento real projetado vs realizado), em % da UF e agregadas (soma das 27 UFs); RMSE em log r como diagnóstico (a calibração de poder do E5.0 usou o log r).

Um candidato é **aceito** na faixa se, na amostra A, **todas** valem:
1. RMSE ≥ 10% menor que o do B0, e menor em **cada** corte da faixa;
2. melhor que o B0 (erro absoluto menor) em mais de 50% dos pares UF-ano e em mais de 50% dos anos;
3. acerto de sinal não pior; 4. viés: |ME| ≤ |ME(B0)| + 0,1 × RMSE(B0);
5. **[NOVO, aprovado]** bootstrap por blocos de ano (2.000 reamostras, semente 20261104): fração com RMSE do candidato < RMSE do B0 ≥ 0,80;
6. **[NOVO, aprovado]** na amostra S, RMSE não maior que o do B0 (não se exige −10%).
Falhou em 6 → "ressalva" e vai para a sombra. Poder fraco (E5.0: 0,15–0,49 com T = 8): os testes formais (teste S do painel, `pEPA`; C com clusters por região; MCS sobre a perda média por ano) são **informação**; nenhum p-valor decide. Contagem de comparações reportada (6 células × candidatos), sem correção.

**Previsão oficial por alvo × faixa:** M5 se ele próprio passa nos critérios e há ao menos 2 aceitos; senão o aceito de menor RMSE; senão **o B0**. Antes de qualquer decisão, nada de M1–M5 vai para o informe.

## 5. Saída (C7)
Crescimento real projetado no ano = (acumulado observado + restante projetado, ambos deflacionados como em 1) / total do ano anterior deflacionado − 1, para receita e despesa totais e primário por diferença. Restante deflacionado pela convenção do protocolo (IPCA anual das premissas distribuído nos meses restantes). Primeira previsão de produção (2026) só depois do OK ao relatório de resultados.

## 6. Prioris do M4 (versionadas antes de rodar)
Coeficientes normal(0, 1); intercepto normal(0, 1); resíduo exponencial(1); efeitos de UF e de ano `decov(2, 1, 1, 1)`; 4 cadeias × 2.000 iterações; `adapt_delta` 0,95; semente 20261105. Convergência: Rhat < 1,01, ESS > 400, zero divergências, senão a célula fica sem previsão (o M5 usa os demais). Variável resposta: ver ponto 1 da seção 9.

## 7. O que vai para a sombra (rodada mensal, arquivado, não publicado)
- Candidatos não aceitos ou aceitos com ressalva, por alvo × faixa, para avaliação prospectiva.
- Mistura P2 → ponte → P1 (E5.4), com o degrau do gap de RJ/PR/RS.
- Projeção na série sem RPPS (referência da LDO), com os degraus da seção 3.
- Diagnóstico por categoria; despesa 2015+ reconstruída, se vier a existir.
Promoção da sombra a oficial só por nova versão do protocolo, com sua aprovação, e não antes do gate E7.1.

## 8. Execução e reprodutibilidade
Código em `R/models/` e `scripts/e5_*.R`, semente fixa, saídas em `outputs/e5_*.csv`, linhas em `experiments/registro.csv` com o hash do commit da especificação. Pacotes novos no `renv`: `lme4`, `rstanarm`, `BMS`, `pEPA` (todos com binário Windows no CRAN; `pEPA` já confirmado). Municípios fora. Ordem: OK a esta especificação → commit do código → execução → relatório com números só de CSVs.

## 9. Decisões do Pedro sobre os pontos acima (04/11, 17:41)
1. **M4 com a resposta em diferença** (log r(t) − log r(t−1)), encolhendo para o B0: aprovado. M1–M3 são equivalentes nas duas formas.
2. **Aceitação só nos totais; categorias como diagnóstico:** aprovado. No informe, o "destaque para [categoria]" (bloco 5 do texto) vem das contribuições **realizadas** no acumulado do ano (P2 realizado), não de projeções de categoria sem aceitação (registrado no gabarito, `docs/proposta_e62_e5_fase2.md`).
3. **Critérios 5 e 6 da seção 4** (bootstrap ≥ 0,80; RMSE não maior que o do B0 na amostra S): aprovados como estão.
4. **Correção da v4 (04/11, 17:41):** a amostra de robustez S é "sem 2020–21, com 2022 dentro e marcado", conforme a decisão de 28/10; o texto da v4 ("sem 2020–22") divergiu dessa decisão. "Sem 2020–22" fica só como sensibilidade adicional. As contagens do E5.0 para "sem 2020–22" continuam válidas apenas para essa sensibilidade; as da amostra S serão recalculadas na execução.
5. **Métrica em % do total anual da UF:** aprovada (o poder do E5.0 foi calculado em log r).
6. **Ordem:** PR do `renv` (`lme4`, `rstanarm`, `BMS`, `pEPA`) e teste de instalação no Windows da CNI antes do código do E5.

## 10. Escolhas de implementacao (04/11/2026, registradas antes da execucao completa)
Decididas ao escrever o codigo (`R/models/e5.R`, `scripts/e5_dados.R`, `scripts/e5_rodar.R`); nenhuma depende do resultado. Uma rodada de depuracao com M1-M3 (`--rapida`) foi feita antes deste commit e **nao** e resultado oficial: serviu para achar erros de codigo (previsoes com restante negativo viravam NaN; painel vazio) e nao mudou nenhum criterio.
1. **Ca, Cb e pendencias vem do total primario do Anexo 6, nao do Anexo 1.** O Anexo 6 traz, nas mesmas linhas do total primario, previsao atualizada (receita), dotacao atualizada, empenhada, liquidada e paga; o Anexo 1 tem receita total e despesa total nao primarias e conceito diferente. Ca e Cb sao calculados no conceito do Anexo 6 como razao (r) e aplicados ao acumulado harmonizado, como na secao 2. A previsao inicial (LOA) so entra no reporte se a coluna existir no total.
2. **Comparacao par a par com o B0** (celulas UF-ano-corte em que o candidato e o B0 tem previsao), nao a interseccao de todos os candidatos: Ca e Cb faltam em algumas celulas e a interseccao global as descartaria. O `n` de cada comparacao esta nos CSVs.
3. **M5 e avaliado nas mesmas amostras em que os aceitos foram escolhidos** (selecao ex post, otimista; sem selecao aninhada). O numero do M5 e reportado com essa ressalva.
4. **Teste S do painel:** `pEPA::pool_av.S1.test` com perda de erro proporcional ao quadrado (`SPE`), UF nas linhas e anos nas colunas, por corte, so UFs com todos os anos; assume independencia entre UFs (violada por choques comuns), entao e informacao. **Nao rodados nesta etapa:** estatisticas C com clusters regionais e MCS; ficam como pendencia declarada.
5. **Categorias (diagnostico):** amostra A, B0 e M1-M3 (sem M4, Ca e Cb). **Variantes de robustez** (sem RJ, sem RS, sem UF-anos `conceito_original` na receita): amostra A, M1-M3, Ca e Cb (sem M4); reporte de quais criterios mudam, sem recalcular M5.
6. **Dados:** ultima versao baixada de cada demonstrativo (retificacoes posteriores incluidas); nao ha versoes por data no extrato. A defasagem real por corte nao e simulada alem de usar so anos anteriores e o acumulado ate o corte.
7. **Sinal do crescimento real:** o restante projetado e deflacionado pela razao real/nominal do restante realizado (isola a surpresa de inflacao do erro de sinal).
8. **Amostras:** A (todos os anos), S (sem 2020 e 2021 no treino e no teste; 2022 dentro, com `d_resto`/`d_base`), S3 (sem 2020-22, sensibilidade sem peso).
