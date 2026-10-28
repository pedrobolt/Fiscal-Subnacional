# Nota do P1 — resultado primário dos governos regionais (E4.3)

Versão de 28/10/2026. Nota curta; o protocolo completo está em `docs/contrato.md` ("Protocolo do P1") e o histórico das decisões em `docs/STATUS.md`.

## 1. O que se projeta
O resultado primário do ano corrente (t) de estados e municípios somados, no conceito do Banco Central (SGS 4642; 4643 estados; 4644 municípios), em R$ bilhões, superávit positivo. A previsão é refeita a cada divulgação mensal do BCB (corte m = 1 a 11: dados até o mês m). O P2 (receitas e despesas pelo RREO) e a ponte entre os conceitos ficam para o E5; o gap P1 × P2 é sempre mostrado.

## 2. Modelo escolhido: SRW em R$
Total previsto = acumulado do ano até o corte + resultado do mesmo período restante do ano anterior (janela 1). Vale nas três faixas de corte (jan–abr, mai–ago, set–nov). Erro típico (RMSE por faixa, R$ bi, alvos 2007–2025 sem 2020–22): 13,2 nos cortes 1–4, 8,2 nos cortes 5–8 e 6,7 nos cortes 9–11.

## 3. Como foi escolhido
Torneio único (28/10/2026, commit `ba5ccf3`), lista fechada de K = 8 (a base e sete desafiantes), regra congelada antes: o desafiante precisa, na faixa, reduzir o RMSE em pelo menos 10%, ser melhor em mais da metade dos anos-alvo, passar no teste de Diebold-Mariano com correção de Holm (α = 0,10), e não piorar acerto de sinal nem viés; nas amostras com e sem 2020–22. As previsões regeneradas reproduzem as do PR #25 (198 de 198 linhas).

| Desafiante | RMSE vs base, cortes 1–4 | 5–8 | 9–11 |
|---|---|---|---|
| SRW em % do PIB | +5% | +2% | +5% |
| acumulado j=5 | +55% | +75% | −26% |
| m2 | +27% | +25% | −7% |
| m3 | +28% | +15% | −41% |
| E4.1 (m3 por componente) | +40% | +35% | −20% |
| FPE/FPM (m3 + g) | +44% | +27% | −28% |
| combinação | +19% | +15% | −26% |

Nenhum foi aceito. O FPE/FPM é comparado com a base nos anos em que tem previsão (14, 12 e 11 anos-alvo sem 2020–22 nas três faixas, por lacunas da STN). A meta da LDO saiu da lista antes ("não viável no P1": série só para estados, 2015–2025; ver `docs/STATUS.md`). O m3 nos cortes 9–11 ficou perto: RMSE −41%, melhor em 81% dos anos-alvo e acerto de sinal de 96% contra 92%, mas o DM não foi significativo (p bruto 0,13; ajustado 0,90, com 16 anos-alvo e 7 testes) e o viés dele (−0,20 bi contra 0,07 da base) violou um critério sem tolerância. Foi falta de poder e um critério de viés rígido, não uma rejeição forte do m3; a regra não foi alterada. O FPE/FPM não acrescenta nada ao m3 (diagnóstico). Decompor em estados e municípios piora a previsão.

## 4. Intervalos
O intervalo paramétrico de 80% com σ em R$ foi reprovado (cobertura de 46% a 50% dos anos-alvo, 2008–2025, abaixo de 80% nas três faixas) e não é divulgado. Por decisão do Pedro, uma única alternativa foi avaliada, **declarada como mudança de protocolo pós-resultado**: σ sobre os erros do SRW em % do PIB (rolante, suavizado entre cortes, pior caso com 2020–22), multiplicado pelo PIB do ano. Avaliada uma vez, nos alvos 2008–2025:

| Faixa | O intervalo contém o resultado em | Wilson 90% por ano |
|---|---|---|
| cortes 1–4 | 58% dos anos-alvo (n = 18) | [39%; 75%] |
| cortes 5–8 | 60% dos anos-alvo (n = 18) | [41%; 76%] |
| cortes 9–11 | 74% dos anos-alvo (n = 18), compatível com 80% | [55%; 87%] |

**Linguagem de divulgação (uniforme, decisão de 28/10/2026):** em todas as faixas se divulga a cobertura observada ("contém o resultado em X% dos anos-alvo"), nunca "intervalo de 80%". Na faixa 9–11 acrescenta-se "compatível com 80%", porque o Wilson contém 80%; isso é falta de evidência contra, não calibração demonstrada.

**Sensibilidade, só informação (a regra não muda):** sem os alvos 2020–22 a cobertura é de cerca de 70% nas três faixas (70%, 70% e 73%), e o Wilson por ano contém 80% nas três. O resultado depende bastante de 2020–22.

σ de produção para 2026, em % do PIB (com 2020–22 / sem 2020–22): corte 1: 0,247 / 0,206; corte 4: 0,222 / 0,158; corte 8: 0,131 / 0,096; corte 11: 0,077 / 0,074. A faixa publicada usa a primeira coluna.

## 5. Limitações
- Dezenove anos de dados (alvos 2007–2025; 16 sem 2020–22): o poder dos testes é baixo, e por isso um modelo melhor pode não passar na regra.
- No backtest o PIB do ano é o realizado e as séries do BCB e do RREO são as versões atuais (revisadas); em produção o PIB vem das premissas. O intervalo não inclui a incerteza do PIB nem a de revisões.
- 2020–22 pesam: com elas, a cobertura é menor e o erro maior. Foram mantidas na amostra principal e reportadas sem.
- O FPE/FPM foi avaliado sem 2023–24 (lacunas na base da STN); o leitor trata set/2024 (escala) e a parcela "FPM 1%" desde jul/2025.
- A regra de aceitação congelada tem um critério de viés sem tolerância; no P2 ele terá tolerância.

## 6. Modelo-sombra e o que vem depois
O m3 é calculado e arquivado em cada rodada ao lado do SRW (E6.3), sem ser publicado, para avaliação prospectiva; o mesmo vale para a mistura P2 → ponte → P1 (E5.4). Mudança de protocolo só com evidência prospectiva, declarada como nova. Sem ajuste de julgamento no número nesta fase: divergências com o mercado vão no texto do informe, e o ajuste é reavaliado no gate E7.1.

## 7. Reprodutibilidade
Código: `R/models/candidatos_p1.R`, `R/evaluation/torneio.R`, `R/evaluation/intervalos.R`; scripts `scripts/torneio_e4.R` e `scripts/intervalos_e42_pib.R`. Todas as previsões do torneio estão em `experiments/registro.csv` (commit `ba5ccf3`). O teste automático de vazamento perturba o futuro de todas as fontes e falha se alguma previsão mudar.
