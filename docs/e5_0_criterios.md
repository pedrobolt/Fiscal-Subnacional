# E5.0: critérios fixados antes de computar (4/11/2026)

Escopo aprovado pelo Pedro em 04/11 (14:59): anos-alvo e UF-anos efetivos por escolha; teste de despesa total e primário com RPPS de RJ/PR/RS em 2025; quebra de receita do RS na série sem RPPS; calibração de poder. **Nenhum modelo do E5 é rodado**; a única previsão calculada é o benchmark B0 (SRW na razão restante/acumulado), necessário para os erros históricos da calibração de poder. Este arquivo é commitado antes do script e dos resultados; mudança depois do resultado entra como tal.

## 1. Anos-alvo e UF-anos efetivos
- Dados: fluxos do Anexo 6 por categoria (`fluxos_a6_categorias`), série **com RPPS**, acumulados por cumsum no ano. Restante no corte b = total do ano (b6) − acumulado até b, b = 1..5.
- Uma célula (UF, ano, categoria, corte) é **válida** se o acumulado e o restante são > 0 e o b6 existe. Um UF-ano-categoria é **válido** se os 5 cortes são válidos.
- **Ano-alvo** de uma UF-categoria: UF-ano válido com pelo menos 3 UF-anos válidos anteriores (treino mínimo 3, qualquer posição) e o ano anterior válido (o SRW usa r(t−1)).
- Escolhas: (R1) receita 2015+; (R2) receita 2019+; (D1) despesa 2018+ (sem reconstrução). A despesa com reconstrução 2015+ não é contável sem a etapa 2 (Anexo 7); só se reporta a aritmética já feita.
- Reporta: anos-alvo, UF-anos efetivos (todos; sem 2020–22 como alvo) por categoria e agregados receita total e despesa total; motivo de perda (não positivo, b6 ausente, treino curto).

## 2. Teste de quebra em despesa total e primário com RPPS de RJ/PR/RS, 2025 (decide a retirada do degrau)
- Séries (COM RPPS): despesa total = soma das categorias desp:*; receita total = soma das rec:*; **primário** = receita total − despesa total (fluxo do bimestre); pessoal COM como controle negativo e pessoal SEM como controle positivo.
- Métrica por UF e bimestre b de 2024 b1 a 2026 b4: yoy do fluxo contra o mesmo bimestre do ano anterior. Para despesa e receita: **desvio = yoy da UF − mediana do yoy das outras 24 UFs** (exclui RJ/PR/RS da mediana) no mesmo bimestre. Para o primário: **Δm = (primário/receita total) do bimestre − o mesmo bimestre do ano anterior**, em p.p., e desvio = Δm da UF − mediana de Δm das 24 UFs.
- **Há quebra** se, em pelo menos 2 bimestres consecutivos a partir de 2025 b1, desvio ≥ 20 p.p. (despesa e receita, mesmo valor de `RECLASS_PP`) ou |desvio| ≥ 10 p.p. (primário); o início é o primeiro bimestre da corrida.
- **Taxa de falsos positivos:** a mesma regra aplicada a todas as 27 UFs na janela 2024 b1 a 2026 b4 (mesmas janelas de 2 bimestres), e a quantidade de UFs fora de RJ/PR/RS com quebra é reportada. Se mais de 10% das 24 UFs aparecerem, a regra é considerada pouco específica e o resultado de RJ/PR/RS é lido junto com isso.
- **Decisão (para o Pedro):** nenhuma quebra em despesa total e primário das três UFs → o degrau sai da série COM (decisão de 04/11). Qualquer quebra → o degrau fica naquela variável e a UF segue para a análise.

## 3. Receita do RS na série sem RPPS
- Compara, por categoria de receita e bimestre de 2023 a 2026, o fluxo do RS nas séries COM e SEM (diferença = contas de receita "com fontes RPPS"), e a participação dessa diferença na receita COM. Reporta em que categoria e a partir de quando; sem teste de hipótese.

## 4. Calibração de poder
- Erro B0: e = log r̂ − log r, com r̂ = r(t−1) no mesmo corte, por UF-ano-categoria-corte, nas categorias e agregados da seção 1; reporta RMSE por corte.
- Simulação (2.000 réplicas por cenário, semente fixa 20261104): sorteia T anos com reposição do conjunto de anos-alvo válidos (mantendo todas as UFs do ano); e_B = erros sorteados; e_C = 0,9 × σ_B × (ρ × e_B/σ_B + √(1−ρ²) × z), com z = erro B0 de outro UF-ano sorteado e padronizado; ρ ∈ {0,5; 0,8}. Isso dá RMSE de C 10% menor que o de B por construção.
- Teste: diferencial de perda d = e_B² − e_C² médio **por ano** (cluster de ano), estatística t com T−1 graus de liberdade, unilateral a 5%. **Poder** = fração de réplicas que rejeita. T ∈ {3, 4, 5, 8, 12}.
- Regra de leitura (já fixada em 04/11): poder < 50% com o T efetivo → os testes entram como informação e a decisão fica por magnitude e bootstrap por ano.
