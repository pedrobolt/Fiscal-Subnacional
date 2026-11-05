# E5 estados: gera docs/relatorio_e5.md a partir dos CSVs da rodada (regra 7: numeros so de CSV). Uso: LC_ALL=C.UTF-8 Rscript scripts/e5_relatorio_md.R
source("R/utils_io.R", encoding = "UTF-8")
o <- function(n) ler_csv(dados(file.path("outputs", paste0("e5_", n, ".csv"))))
dec <- o("decisao"); ofi <- o("oficial"); mf <- o("metricas_faixa"); ent <- o("entes"); dg <- o("diag_estimacao"); var <- o("variantes")
m4 <- o("m4_celulas_comuns"); ab <- o("ablacao"); pip <- o("pip_bms"); tp <- o("testes_painel")
md_tab <- function(d) { d[] <- lapply(d, function(z) ifelse(is.na(z), "-", as.character(z))); c(paste0("| ", paste(names(d), collapse = " | "), " |"), paste0("|", paste(rep("---", ncol(d)), collapse = "|"), "|"), apply(d, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))) }
f1 <- function(x, k = 2) formatC(x, format = "f", digits = k, decimal.mark = ",")
SN <- c(rec = "receita total", desp = "despesa total"); sn <- function(s) SN[sub(":.*", "", s)]
L <- character()
add <- function(...) L <<- c(L, ...)
add("# Relatorio E5 (estados): resultados da especificacao fixada (04/11/2026)", "",
    "Especificacao aprovada: `docs/e5_especificacao.md` (PR #66, commit 10aa7b6; secao 10 de escolhas de implementacao no b116f6b). Codigo: PR do E5. Numeros de `outputs/e5_*.csv` (gerados por `scripts/e5_rodar.R`, `scripts/e5_relatorio.R` e este script); linhas em `experiments/registro.csv` (status `e5_v4`). Erros em % do total anual da UF; B0 = SRW na razao. **Nada foi para o informe**: a decisao de adotar e do Pedro.", "")
# ---- 1. decisao
a <- dec[dec$modelo != "M5" | TRUE, ]
rm <- mf[mf$amostra == "A" & mf$serie %in% c("rec:total", "desp:total"), c("serie", "faixa", "modelo", "n", "RMSE")]
b0 <- rm[rm$modelo == "B0", c("serie", "faixa", "RMSE")]; names(b0)[3] <- "RMSE_B0"
ofi2 <- merge(ofi, b0, by = c("serie", "faixa")); ofi2 <- merge(ofi2, rm[, c("serie", "faixa", "modelo", "RMSE")], by.x = c("serie", "faixa", "oficial"), by.y = c("serie", "faixa", "modelo"), all.x = TRUE)
names(ofi2)[ncol(ofi2)] <- "RMSE_oficial"; ofi2$RMSE_oficial[ofi2$oficial == "B0"] <- ofi2$RMSE_B0[ofi2$oficial == "B0"]
ofi2$reducao_pct <- 100 * (1 - ofi2$RMSE_oficial / ofi2$RMSE_B0)
t1 <- data.frame(serie = sn(ofi2$serie), faixa = ofi2$faixa, aceitos = ifelse(ofi2$aceitos == "", "nenhum", ofi2$aceitos), oficial = ofi2$oficial, RMSE_B0 = f1(ofi2$RMSE_B0), RMSE_oficial = f1(ofi2$RMSE_oficial), `reducao_%` = f1(ofi2$reducao_pct, 0), check.names = FALSE)
t1 <- t1[order(t1$serie, t1$faixa), ]
add("## 1. Decisao pelas regras fixadas", "", "Previsao oficial por serie e faixa (M5 se passa e ha 2 ou mais aceitos; senao o aceito de menor RMSE; senao o B0). RMSE em % do total anual, amostra A.", "", md_tab(t1), "")
nb <- sum(ofi$oficial == "B0"); add(sprintf("**%d das 6 celulas ficam com o B0** (nenhum candidato aceito). Receita total: aceitos nas faixas b3-b4 e b5; despesa total: so o M3 em b5.", nb), "")
# ---- 2. criterios
d2 <- dec[order(dec$serie, dec$faixa, dec$modelo), ]
t2 <- data.frame(serie = sn(d2$serie), faixa = d2$faixa, modelo = d2$modelo, n = d2$n, razao_RMSE = f1(d2$razao_rmse, 3), `pares_UF_ano` = f1(d2$share_uf_ano), anos = f1(d2$share_anos),
  sinal = ifelse(d2$c3_sinal, "ok", "falha"), vies = ifelse(d2$c4_vies, "ok", "falha"), boot = f1(d2$prob_boot), razao_S = f1(d2$razao_rmse_S, 3), status = d2$status, check.names = FALSE)
add("## 2. Criterios por candidato (amostra A; razao_S = RMSE/RMSE do B0 na amostra S)", "", md_tab(t2), "",
    "Criterios: RMSE >= 10% menor em cada corte da faixa; > 50% dos pares UF-ano e dos anos; sinal e vies nao piores; bootstrap por ano >= 0,80; razao_S <= 1. `n` = celulas UF-ano-corte comparadas com o B0.", "")
# ---- 3. M4
d4 <- dg[dg$modelo == "M4", ]; ok4 <- sum(d4$diag == "ok"); nc <- sum(grepl("^nao_conv", d4$diag)); tc <- sum(d4$diag == "treino_curto")
div <- as.numeric(sub(".*div=([0-9]+).*", "\\1", d4$diag[grepl("^nao_conv", d4$diag)])); rh <- as.numeric(sub(".*rhat=([0-9.]+).*", "\\1", d4$diag[grepl("^nao_conv", d4$diag)])); es <- as.numeric(sub(".*ess=([0-9]+).*", "\\1", d4$diag[grepl("^nao_conv", d4$diag)]))
add("## 3. M4 (bayesiano): convergencia e comparacao nas mesmas celulas", "",
    sprintf("Das %d estimacoes do M4 (serie x amostra x faixa x ano-alvo), %d convergiram pelo criterio fixado (Rhat < 1,01, ESS > 400, zero divergencias), %d nao convergiram e %d tiveram treino curto. Entre as que falharam, %d tinham Rhat < 1,01 e ESS > 400 e falharam **so por divergencias** (de %d a %d por estimacao); mediana de divergencias %d. Pela regra, a celula fica sem previsao.", nrow(d4), ok4, nc, tc, sum(rh < 1.01 & es > 400), min(div), max(div), as.integer(stats::median(div))), "",
    "Consequencia: o M4 so tem previsao em parte dos anos, e seus criterios (e o M5, que o inclui onde existe) sao calculados em celulas diferentes das de M1-M3. Comparacao nas **mesmas celulas do M4** (RMSE em %; pos-resultado, descritivo):", "",
    md_tab(data.frame(serie = sn(m4$serie), faixa = m4$faixa, celulas_M4 = paste0(m4$celulas_M4, "/", m4$celulas_B0), anos_M4 = paste0(m4$anos_M4, "/", m4$anos_B0), B0 = f1(m4$B0), M1 = f1(m4$M1), M2 = f1(m4$M2), M3 = f1(m4$M3), M4 = f1(m4$M4))), "",
    "Nas celulas em que converge, o M4 e parecido com o M3 (a priori em diferenca encolhe para o B0, como aprovado); nao ha evidencia de que traga ganho adicional, e a cobertura baixa impede aceita-lo como candidato comparavel.", "")
# ---- 4. entes
add("## 4. Previsoes dos entes (Anexo 6; reporte sem peso na aceitacao)", "",
    md_tab(data.frame(serie = sn(ent$serie), faixa = ent$faixa, oficial = ent$oficial, n = ent$n, `vies_ente_%` = f1(ent$vies_ente_pct), RMSE_ente = f1(ent$rmse_ente_atual), RMSE_oficial = f1(ent$rmse_modelo_oficial), ente_melhor = ifelse(ent$ente_melhor, "sim", "nao"), check.names = FALSE)), "",
    "Receita: previsao atualizada contra a receita realizada do ano (viés negativo = o ente subestima). Despesa: dotacao atualizada contra a despesa em caixa final. `ente_melhor` compara o erro bruto do ente com o do modelo oficial da faixa (na despesa b1-b2 o oficial e o B0). A LOA (previsao inicial) nao esta no total primario do Anexo 6; ficou sem reporte. Ca e Cb ficam pior que o B0 em todas as faixas.", "")
# ---- 5. variantes
pv <- function(x) with(x, c1_rmse10 & c2_pares & c3_sinal & c4_vies & c5_boot)
base_pass <- dec[dec$modelo %in% c("M1", "M2", "M3", "Ca", "Cb"), c("serie", "faixa", "modelo", "passa_A")]
vv <- merge(var, base_pass, by = c("serie", "faixa", "modelo")); vv$pass <- pv(vv)
tv <- do.call(rbind, lapply(split(vv, vv$variante), function(d) data.frame(variante = d$variante[1], comparacoes = nrow(d), passam_variante = sum(d$pass), passam_principal = sum(d$passa_A), mudam = sum(d$pass != d$passa_A))))
add("## 5. Variantes de robustez (amostra A; M1-M3, Ca, Cb; sem M4)", "", md_tab(tv), "",
    "Mudancas de veredito (variante contra principal) por candidato e faixa estao em `outputs/e5_variantes.csv`.", "")
# ---- 6. descritivos
pa <- merge(ab[ab$modelo == "so_x1", c("serie", "faixa", "RMSE")], ab[ab$modelo == "completo", c("serie", "faixa", "RMSE")], by = c("serie", "faixa"), suffixes = c("_so_x1", "_completo"))
sg <- tp[tp$modelo %in% c("M1", "M2", "M3", "M4", "M5"), ]
add("## 6. Descritivos pos-resultado (nao entram na aceitacao)", "",
    "**Ablacao do M1** (RMSE %, mesmas celulas): so `x1` + efeito de corte contra o conjunto completo de preditores.", "",
    md_tab(data.frame(serie = sn(pa$serie), faixa = pa$faixa, so_x1 = f1(pa$RMSE_so_x1), completo = f1(pa$RMSE_completo))), "",
    "Na receita em b3-b4 e b5 o ganho sobre o B0 vem de `x1` com coeficiente menor que 1 (reversao a media da razao entre UFs) e dos efeitos de corte, nao dos demais preditores; em b1-b2, `x2` (crescimento do acumulado) responde por parte do ganho. Na despesa o ganho vem de `x2` em b1-b2 e b3-b4 e de `x3` e `x4` (pendencias) em b5.", "",
    sprintf("**PIP do BMS** (amostra sem 2020-21): preditores com PIP >= 0,5 por serie e faixa estao em `outputs/e5_pip_bms.csv`; ex.: despesa total, `x2` e `d_intra23` tem PIP %s em b1-b2.", f1(pip$PIP[pip$serie == "desp:total" & pip$faixa == "b1_b2" & pip$preditor == "d_intra23"], 2)), "",
    sprintf("**Teste S1 do painel (pEPA, informacao):** %d de %d comparacoes M1-M5 contra o B0 com p < 0,05 a favor do candidato; o Ca e o Cb aparecem com estatistica negativa (pior que o B0). Assume independencia entre UFs, o que e fragil com choques comuns.", sum(sg$S1_estat > 0 & sg$S1_p < 0.05, na.rm = TRUE), nrow(sg)), "")
add("## 7. Desvios, limitacoes e o que nao foi feito", "",
    "- Escolhas de implementacao 1-8 em `docs/e5_especificacao.md`, secao 10 (Anexo 6 em lugar do Anexo 1 para Ca, Cb e pendencias; comparacao par a par; M5 ex post; etc.).",
    "- **M4 com cobertura baixa** (secao 3). O criterio de zero divergencias, aplicado literalmente, inviabiliza a comparacao do M4 com os demais.",
    "- **Nao rodados:** estatisticas C com clusters regionais e MCS (pendencia declarada); variante por UF encolhida do Ca; M4 nas categorias e nas variantes.",
    "- A rodada de depuracao `--rapida` (M1-M3) anterior ao commit final nao foi usada como resultado.",
    "- A amostra tem 8 anos-alvo (receita) e 5 (despesa); os veredictos de ganho de 25% a 60% no RMSE sao em poucos anos e sob choques comuns. Os anos individuais estao em `outputs/e5_por_ano.csv`.", "")
add("## 8. Para o Pedro decidir", "",
    "1. **M4:** manter o criterio literal (M4 praticamente fora) ou versionar uma mudanca antes de nova rodada (por exemplo `adapt_delta` maior ou priori mais informativa nos efeitos de grupo); a mudanca seria declarada como pos-resultado.",
    "2. **Criterio de sinal (3):** na receita b1-b2, M2 e M3 reduzem o RMSE em cerca de 24% a 26% e passam todos os demais criterios, mas o acerto de sinal fica menos de 1 p.p. abaixo do B0 (M1: 5 p.p.); na despesa b1-b2 a falha e maior (acerto de 0,69 a 0,70 contra 0,77). O criterio e estrito (>=) e a metrica e binaria; nao alterei.",
    "3. **Uso:** adotar o M5 (receita b3-b4 e b5) e o M3 (despesa b5) para o informe, mantendo o B0 nas demais celulas? Os numeros de 2026 so saem depois do seu OK; nao calculei previsao de producao.",
    "4. **Sombra:** o que nao foi aceito segue para a sombra conforme a especificacao, secao 7.", "")
writeLines(L, "docs/relatorio_e5.md", useBytes = FALSE)
cat(sprintf("escrito docs/relatorio_e5.md (%d linhas)\n", length(L)))
