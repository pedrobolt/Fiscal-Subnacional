# Relatorio E5 (estados): resultados da especificacao fixada (04/11/2026)

Especificacao aprovada: `docs/e5_especificacao.md` (PR #66, commit 10aa7b6; secao 10 de escolhas de implementacao no b116f6b). Codigo: PR do E5. Numeros de `outputs/e5_*.csv` (gerados por `scripts/e5_rodar.R`, `scripts/e5_relatorio.R` e este script); linhas em `experiments/registro.csv` (status `e5_v4`). Erros em % do total anual da UF; B0 = SRW na razao. **Nada foi para o informe**: a decisao de adotar e do Pedro.

## 1. Decisao pelas regras fixadas

Previsao oficial por serie e faixa (M5 se passa e ha 2 ou mais aceitos; senao o aceito de menor RMSE; senao o B0). RMSE em % do total anual, amostra A.

| serie | faixa | aceitos | oficial | RMSE_B0 | RMSE_oficial | reducao_% |
|---|---|---|---|---|---|---|
| despesa total | b1_b2 | nenhum | B0 | 12,18 | 12,18 | 0 |
| despesa total | b3_b4 | nenhum | B0 | 5,24 | 5,24 | 0 |
| despesa total | b5 | M3 | M3 | 7,35 | 2,80 | 62 |
| receita total | b1_b2 | nenhum | B0 | 8,29 | 8,29 | 0 |
| receita total | b3_b4 | M1+M2+M3+M4 | M5 | 5,83 | 4,40 | 24 |
| receita total | b5 | M1+M3+M4 | M5 | 3,99 | 2,85 | 29 |

**3 das 6 celulas ficam com o B0** (nenhum candidato aceito). Receita total: aceitos nas faixas b3-b4 e b5; despesa total: so o M3 em b5.

## 2. Criterios por candidato (amostra A; razao_S = RMSE/RMSE do B0 na amostra S)

| serie | faixa | modelo | n | razao_RMSE | pares_UF_ano | anos | sinal | vies | boot | razao_S | status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| despesa total | b1_b2 | Cb | 268 | 0,990 | 0,44 | 0,40 | falha | falha | 0,54 | 1,043 | sombra |
| despesa total | b1_b2 | M1 | 268 | 0,572 | 0,65 | 1,00 | falha | ok | 1,00 | 0,486 | sombra |
| despesa total | b1_b2 | M2 | 268 | 0,609 | 0,65 | 1,00 | falha | ok | 1,00 | 0,593 | sombra |
| despesa total | b1_b2 | M3 | 268 | 0,589 | 0,61 | 1,00 | falha | ok | 1,00 | 0,503 | sombra |
| despesa total | b1_b2 | M4 | 54 | 0,395 | 0,81 | 1,00 | ok | ok |  NA |   NA | - |
| despesa total | b3_b4 | Cb | 268 | 1,585 | 0,26 | 0,00 | falha | falha | 0,00 | 1,826 | sombra |
| despesa total | b3_b4 | M1 | 268 | 0,741 | 0,49 | 1,00 | falha | ok | 1,00 | 0,817 | sombra |
| despesa total | b3_b4 | M2 | 268 | 0,880 | 0,51 | 1,00 | falha | ok | 1,00 | 0,941 | sombra |
| despesa total | b3_b4 | M3 | 268 | 0,828 | 0,47 | 1,00 | falha | ok | 1,00 | 0,882 | sombra |
| despesa total | b5 | Cb | 134 | 0,919 | 0,22 | 0,40 | falha | falha | 0,66 | 0,884 | sombra |
| despesa total | b5 | M1 | 134 | 0,431 | 0,46 | 1,00 | ok | ok | 1,00 | 0,661 | sombra |
| despesa total | b5 | M2 | 134 | 0,442 | 0,50 | 1,00 | ok | ok | 1,00 | 0,699 | sombra |
| despesa total | b5 | M3 | 134 | 0,381 | 0,51 | 1,00 | ok | ok | 1,00 | 0,622 | aceito |
| despesa total | b5 | M4 | 81 | 0,609 | 0,56 | 1,00 | ok | ok | 1,00 |   NA | ressalva_sombra |
| despesa total | b5 | M5 | 134 | 0,381 | 0,51 | 1,00 | ok | ok | 1,00 | 0,622 | aceito |
| receita total | b1_b2 | Ca | 428 | 1,290 | 0,35 | 0,50 | falha | falha | 0,02 | 1,321 | sombra |
| receita total | b1_b2 | M1 | 428 | 0,785 | 0,53 | 0,88 | falha | ok | 1,00 | 0,797 | sombra |
| receita total | b1_b2 | M2 | 428 | 0,763 | 0,57 | 1,00 | falha | ok | 1,00 | 0,791 | sombra |
| receita total | b1_b2 | M3 | 428 | 0,741 | 0,59 | 1,00 | falha | ok | 1,00 | 0,763 | sombra |
| receita total | b1_b2 | M4 | 216 | 0,623 | 0,69 | 1,00 | ok | ok | 1,00 |   NA | ressalva_sombra |
| receita total | b3_b4 | Ca | 428 | 1,753 | 0,26 | 0,12 | falha | falha | 0,00 | 1,766 | sombra |
| receita total | b3_b4 | M1 | 428 | 0,733 | 0,67 | 0,88 | ok | ok | 1,00 | 0,693 | aceito |
| receita total | b3_b4 | M2 | 428 | 0,830 | 0,58 | 0,88 | ok | ok | 0,95 | 0,821 | aceito |
| receita total | b3_b4 | M3 | 428 | 0,762 | 0,61 | 0,88 | ok | ok | 1,00 | 0,751 | aceito |
| receita total | b3_b4 | M4 | 270 | 0,671 | 0,68 | 1,00 | ok | ok | 1,00 | 0,593 | aceito |
| receita total | b3_b4 | M5 | 428 | 0,755 | 0,61 | 0,88 | ok | ok | 1,00 | 0,729 | aceito |
| receita total | b5 | Ca | 207 | 2,610 | 0,20 | 0,00 | falha | falha | 0,00 | 2,499 | sombra |
| receita total | b5 | M1 | 214 | 0,710 | 0,56 | 0,75 | ok | ok | 0,97 | 0,885 | aceito |
| receita total | b5 | M2 | 214 | 0,955 | 0,48 | 0,38 | falha | falha | 0,55 | 1,237 | sombra |
| receita total | b5 | M3 | 214 | 0,723 | 0,54 | 0,75 | ok | ok | 0,96 | 0,906 | aceito |
| receita total | b5 | M4 | 108 | 0,609 | 0,64 | 1,00 | ok | ok | 1,00 | 0,591 | aceito |
| receita total | b5 | M5 | 214 | 0,714 | 0,55 | 0,75 | ok | ok | 0,97 | 0,894 | aceito |

Criterios: RMSE >= 10% menor em cada corte da faixa; > 50% dos pares UF-ano e dos anos; sinal e vies nao piores; bootstrap por ano >= 0,80; razao_S <= 1. `n` = celulas UF-ano-corte comparadas com o B0.

## 3. M4 (bayesiano): convergencia e comparacao nas mesmas celulas

Das 93 estimacoes do M4 (serie x amostra x faixa x ano-alvo), 27 convergiram pelo criterio fixado (Rhat < 1,01, ESS > 400, zero divergencias), 60 nao convergiram e 6 tiveram treino curto. Entre as que falharam, 40 tinham Rhat < 1,01 e ESS > 400 e falharam **so por divergencias** (de 0 a 310 por estimacao); mediana de divergencias 5. Pela regra, a celula fica sem previsao.

Consequencia: o M4 so tem previsao em parte dos anos, e seus criterios (e o M5, que o inclui onde existe) sao calculados em celulas diferentes das de M1-M3. Comparacao nas **mesmas celulas do M4** (RMSE em %; pos-resultado, descritivo):

| serie | faixa | celulas_M4 | anos_M4 | B0 | M1 | M2 | M3 | M4 |
|---|---|---|---|---|---|---|---|---|
| receita total | b1_b2 | 216/428 | 4/8 | 7,14 | 4,77 | 4,80 | 4,45 | 4,45 |
| receita total | b3_b4 | 270/428 | 5/8 | 5,79 | 3,94 | 4,27 | 3,93 | 3,89 |
| receita total | b5 | 108/214 | 4/8 | 3,34 | 2,00 | 2,50 | 2,06 | 2,04 |
| despesa total | b1_b2 | 54/268 | 1/5 | 10,40 | 3,73 | 5,23 | 4,17 | 4,11 |
| despesa total | b5 | 81/134 | 3/5 | 3,69 | 2,39 | 2,37 | 2,25 | 2,24 |

Nas celulas em que converge, o M4 e parecido com o M3 (a priori em diferenca encolhe para o B0, como aprovado); nao ha evidencia de que traga ganho adicional, e a cobertura baixa impede aceita-lo como candidato comparavel.

## 4. Previsoes dos entes (Anexo 6; reporte sem peso na aceitacao)

| serie | faixa | oficial | n | vies_ente_% | RMSE_ente | RMSE_oficial | ente_melhor |
|---|---|---|---|---|---|---|---|
| receita total | b1_b2 | B0 | 428 | -8,36 | 11,62 | 8,29 | nao |
| receita total | b3_b4 | M5 | 428 | -7,15 | 10,61 | 4,40 | nao |
| receita total | b5 | M5 | 214 | -5,07 | 8,93 | 2,85 | nao |
| despesa total | b1_b2 | B0 | 268 | -4,65 | 10,80 | 12,18 | sim |
| despesa total | b3_b4 | B0 | 268 | 2,29 | 7,42 | 5,24 | nao |
| despesa total | b5 | M3 | 134 | 7,92 | 10,27 | 2,80 | nao |

Receita: previsao atualizada contra a receita realizada do ano (viés negativo = o ente subestima). Despesa: dotacao atualizada contra a despesa em caixa final. `ente_melhor` compara o erro bruto do ente com o do modelo oficial da faixa (na despesa b1-b2 o oficial e o B0). A LOA (previsao inicial) nao esta no total primario do Anexo 6; ficou sem reporte. Ca e Cb ficam pior que o B0 em todas as faixas.

## 5. Variantes de robustez (amostra A; M1-M3, Ca, Cb; sem M4)

| variante | comparacoes | passam_variante | passam_principal | mudam |
|---|---|---|---|---|
| sem_conceito_original | 24 | 7 | 6 | 5 |
| sem_RJ | 24 | 6 | 6 | 0 |
| sem_RS | 24 | 6 | 6 | 2 |

Mudancas de veredito (variante contra principal) por candidato e faixa estao em `outputs/e5_variantes.csv`.

## 6. Descritivos pos-resultado (nao entram na aceitacao)

**Ablacao do M1** (RMSE %, mesmas celulas): so `x1` + efeito de corte contra o conjunto completo de preditores.

| serie | faixa | so_x1 | completo |
|---|---|---|---|
| despesa total | b1_b2 | 10,80 | 6,97 |
| despesa total | b3_b4 | 4,18 | 3,88 |
| despesa total | b5 | 5,31 | 3,17 |
| receita total | b1_b2 | 7,18 | 6,51 |
| receita total | b3_b4 | 4,27 | 4,27 |
| receita total | b5 | 2,83 | 2,83 |

Na receita em b3-b4 e b5 o ganho sobre o B0 vem de `x1` com coeficiente menor que 1 (reversao a media da razao entre UFs) e dos efeitos de corte, nao dos demais preditores; em b1-b2, `x2` (crescimento do acumulado) responde por parte do ganho. Na despesa o ganho vem de `x2` em b1-b2 e b3-b4 e de `x3` e `x4` (pendencias) em b5.

**PIP do BMS** (amostra sem 2020-21): preditores com PIP >= 0,5 por serie e faixa estao em `outputs/e5_pip_bms.csv`; ex.: despesa total, `x2` e `d_intra23` tem PIP 1,00 em b1-b2.

**Teste S1 do painel (pEPA, informacao):** 30 de 40 comparacoes M1-M5 contra o B0 com p < 0,05 a favor do candidato; o Ca e o Cb aparecem com estatistica negativa (pior que o B0). Assume independencia entre UFs, o que e fragil com choques comuns.

## 7. Desvios, limitacoes e o que nao foi feito

- Escolhas de implementacao 1-8 em `docs/e5_especificacao.md`, secao 10 (Anexo 6 em lugar do Anexo 1 para Ca, Cb e pendencias; comparacao par a par; M5 ex post; etc.).
- **M4 com cobertura baixa** (secao 3). O criterio de zero divergencias, aplicado literalmente, inviabiliza a comparacao do M4 com os demais.
- **Nao rodados:** estatisticas C com clusters regionais e MCS (pendencia declarada); variante por UF encolhida do Ca; M4 nas categorias e nas variantes.
- A rodada de depuracao `--rapida` (M1-M3) anterior ao commit final nao foi usada como resultado.
- A amostra tem 8 anos-alvo (receita) e 5 (despesa); os veredictos de ganho de 25% a 60% no RMSE sao em poucos anos e sob choques comuns. Os anos individuais estao em `outputs/e5_por_ano.csv`.

## 8. Para o Pedro decidir

1. **M4:** manter o criterio literal (M4 praticamente fora) ou versionar uma mudanca antes de nova rodada (por exemplo `adapt_delta` maior ou priori mais informativa nos efeitos de grupo); a mudanca seria declarada como pos-resultado.
2. **Criterio de sinal (3):** na receita b1-b2, M2 e M3 reduzem o RMSE em cerca de 24% a 26% e passam todos os demais criterios, mas o acerto de sinal fica menos de 1 p.p. abaixo do B0 (M1: 5 p.p.); na despesa b1-b2 a falha e maior (acerto de 0,69 a 0,70 contra 0,77). O criterio e estrito (>=) e a metrica e binaria; nao alterei.
3. **Uso:** adotar o M5 (receita b3-b4 e b5) e o M3 (despesa b5) para o informe, mantendo o B0 nas demais celulas? Os numeros de 2026 so saem depois do seu OK; nao calculei previsao de producao.
4. **Sombra:** o que nao foi aceito segue para a sombra conforme a especificacao, secao 7.

