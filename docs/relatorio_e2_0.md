# E2.0 — Piloto do RREO municipal: cobertura, custo e recomendação

Data: 23/10/2026. Dados: RREO 6º bimestre de 2025 e 2019, Anexos 1 (receita realizada, "Até o Bimestre (c)") e 6 (resultado primário), todos os 5.569 municípios (o DF entra como estado). Valores em R$ correntes. Código: `scripts/coleta_municipal.R`, `scripts/curvas_cobertura.R`, `scripts/amostra_extrato.R`.

## Limites da API e custo medido
- 2 conexões (máximo autorizado): 26.089 chamadas em 5,0 h de coleta ativa = **1,44 chamada/s**; 7 erros transitórios (todos resolvidos por nova tentativa), sem bloqueio. Pilotos: 1 conexão 0,85/s (273 chamadas, 0 erros); 2 conexões ~1,7/s (287 chamadas, 1 erro).
- Amostras: exploratória de 8 municípios (descobriu o RREO Simplificado); piloto A, 200 municípios (1 conexão); piloto B, outros 200 (2 conexões, sem sobreposição com A).
- Sem download em massa do RREO no Tesouro Transparente (só API).
- ~125 MB compactados (186 MB em disco) para 30.421 arquivos (estados 2015–2026 e municípios 2025/2019).
- **RREO Simplificado**: 41% dos municípios em 2025 (2.294) e 37% em 2019 (2.067) entregam o tipo `RREO Simplificado`; é preciso consultar os dois tipos. Em amostra de 120 Simplificados por ano, 119 entregam **os seis bimestres** (2025 e 2019): **não há ausência estrutural nos bimestres 1, 2, 4 e 5** (hipótese descartada).

## Curva de cobertura (municípios ordenados por receita, dentro da UF)
Número de municípios necessários para explicar a fração da receita municipal (soma dos N por UF; entre parênteses, ranking nacional único):

| Receita explicada | 2025 | 2019 | Sobreposição dos N maiores por UF, 2025 × 2019 |
|---|---|---|---|
| 70% | 1.205 (820) | 1.056 (647) | 91,5% |
| 80% | 1.967 (1.527) | 1.814 (1.306) | 91,9% |
| 90% | 3.205 (2.760) | 3.076 (2.561) | 93,7% |

Municípios com dados: 5.526 (2025) e 5.539 (2019). A receita é pouco concentrada: para 80% são necessários 36% dos municípios. O ranking é estável (~92% de sobreposição).

Parcela do resultado primário (RREO) capturada pelos N maiores em receita (ranking nacional, valor absoluto): 2025: 66% / 76% / 87%; 2019: 72% / 81% / 90% (para 70/80/90% da receita). O primário líquido tem captura instável (UFs com soma líquida perto de zero passam de 100%). Números do primário são indicativos: a extração do primário do RREO não foi validada (Anexo 6 de 2025 usa `ResultadoPrimarioSemRPPSAcimaDaLinha` e o de 2019, layout anterior, `RREO6ResultadoPrimarioEstadosMunicipios`; faltam 22 municípios em 2025 e 135 em 2019; ponte com o BCB na E3.6).

## Municípios sem dados (tamanho da imputação)
- 2025: 43 municípios (0,77%), 0,61% da população; maiores: Foz do Iguaçu (PR, 297 mil), Magé (RJ, 244 mil), Gurupi (TO), Acará (PA), Lábrea (AM).
- 2019: 30 municípios (0,54%), 0,18% da população; maiores: Muaná (PA), Itapemirim (ES), Joaçaba (SC).
- Imputação desse grupo é pequena frente à da expansão. A lista completa sai de `sem_dados()` (`outputs/`, não versionado).

## Grupo Simplificado (peso no agregado)
| | Municípios | População | Receita | Primário (líquido / abs.) |
|---|---|---|---|---|
| 2025 | 2.294 (41%) | 12,6% | 14,8% | 17,2% / 18,4% |
| 2019 | 2.067 (37%) | 11,0% | 12,0% | 10,5% / 11,3% |

Por UF (2025, participação na receita): MS 47,8%, MG 39,2%, RS 38,7%, PR 37,1%, MA 35,9%, ES 33,7%; 12 das 26 UFs passam de 10%; SP 2,8%; BA 0,1%. O grupo precisa de verificação própria de contas por UF (o Simplificado é um demonstrativo reduzido), não de tratamento de ausência.

## Extrato de entregas (`/tt/extrato_entregas`, por ente × ano)
- Campos: `entregavel`, `periodo`, `periodicidade`, `status_relatorio` (HO = homologado, RE = retificado), `data_status`, `forma_envio`, `tipo_relatorio` (P padrão, S simplificado). Dá o tipo de RREO por ente × ano e evita a chamada vazia.
- **Guarda só o último status** (uma linha por ente × ano × período); não há histórico de retificações. `data_status` é a data de homologação para HO e a data da **retificação** para RE: nesses casos a primeira entrega não é observável. Em amostras de Simplificados, 10,6% (2025) e 6,4% (2019) das linhas do RREO estavam retificadas.
- Consequência para o `available_at` (E2.7): `data_status` quando HO; para RE, prazo legal (fim do bimestre + 30 dias) + atraso mediano dos homologados da mesma UF × período (regra aprovada em 24/10/2026; o prazo legal puro vazaria informação). Valores usados são a versão mais recente (retificada).

## Recomendação: censo completo (aprovada pelo Pedro em 24/10/2026)
A decisão se apoia em dois pontos: o custo da rodada é aceitável e o censo elimina a camada de expansão (e as hipóteses e a imputação que ela exigiria).
- **Custo da rodada**: censo ≈ 13,0 mil chamadas por bimestre (A1 + A6, com a segunda tentativa do Simplificado) ≈ **2,5 h** com 2 conexões; N maiores (80%) ≈ 4,6 mil chamadas ≈ 0,9 h. A economia é de ~1,6 h por bimestre. A checagem de entregas (extrato) soma ~5,6 mil chamadas (~1,1 h) por rodada.
- **Sem camada de expansão**: o agregado municipal vem da soma dos municípios observados, com imputação só para os que não entregam (0,6–0,8% dos municípios, 0,2–0,6% da população), documentada como no E2.2. O Simplificado é tratado como grupo com verificação própria de contas.
- **Carga inicial** (única): censo 2015–2026 ≈ 913 mil chamadas ≈ **7,3 dias** de API a 1,44/s (descontando o já feito e usando o tipo de relatório do 6º bimestre para evitar a segunda tentativa nos demais, ≈ 772 mil chamadas ≈ 6,2 dias). Ordem aprovada: (1) 6º bimestre de todos os anos; (2) demais bimestres do mais recente para o mais antigo (2023 em diante primeiro).
