# E6.1: rodada mensal. Um comando: baixar -> validar -> projetar (P1) -> P2 realizado -> gap -> alertas -> arquivar -> resumo.
# Uso: Rscript scripts/rodada_mensal.R [--data=AAAA-MM-DD] [--sem-download] [--rapida]
#   --oficial       rodada oficial: grava em outputs/rodada e no arquivo de previsões emitidas. Sem esta opção a rodada é de TESTE e grava em
#                   outputs/teste/ (arquivo de previsões incluído). Não vale com --sem-download nem --rapida.
#   --sem-download  pula Siconfi, BCB e IBGE (usa o que está em data/raw); a rodada sai DEGRADADA.
#   --rapida        pula conceito único e alertas (usa as saídas de outputs/ já calculadas); a rodada sai DEGRADADA.
# Dados sob a raiz FISCAL_DADOS (padrão: a pasta do repositório); ver docs/HANDOVER.md, 3h.
# Saída: outputs/rodada/<data>/ (resumo.md, informe.xlsx, informe_interno.xlsx, informe_texto.md, p1.csv, p2_categorias.csv, p2_resultado.csv, gap.csv, alertas_*.csv, etapas.csv, carimbo.txt) e o
# arquivo de previsões emitidas outputs/arquivo/previsoes_emitidas.csv (uma linha por rodada x modelo x esfera x ano-alvo).
# Código de saída: 0 = OK; 2 = DEGRADADA (alguma etapa falhou ou foi pulada); 1 = erro fatal. Rodar no Windows da CNI: ver docs/HANDOVER.md.
# A rodada é sequencial: no máximo 1 conexão por vez ao Siconfi (limite combinado: 2).
args <- commandArgs(TRUE)
opt <- function(nome, padrao = NA_character_) { a <- grep(paste0("^--", nome, "="), args, value = TRUE); if (length(a)) sub(paste0("^--", nome, "="), "", a[1]) else padrao }
sem_download <- "--sem-download" %in% args; rapida <- "--rapida" %in% args; oficial <- "--oficial" %in% args
if ("--sem-cache" %in% args) Sys.setenv(FISCAL_SEM_CACHE = "1")      # ignora o cache do RREO (conferencia: o resultado deve ser identico)
if (oficial && (sem_download || rapida)) { cat("Erro: --oficial exige a rodada completa (sem --sem-download nem --rapida).\n"); quit(status = 1) }
hoje <- as.Date(opt("data", format(Sys.Date())))
dia <- format(hoje)
invisible(Sys.setlocale("LC_COLLATE", "C"))
# (R/utils_io.R ja carregado pelo ponto de entrada)
arqs <- list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
arqs <- c(arqs[!grepl("candidatos_p1", arqs)], arqs[grepl("candidatos_p1", arqs)])   # candidatos_p1 depende de ESPEC_RESTANTE
carregar_r(arqs)

versao <- versao_codigo(".")
msg <- recusa_sem_commit(versao, oficial); if (!is.null(msg)) { cat(msg, "\n"); quit(status = 1) }
commit <- if (is.na(versao$commit)) NA_character_ else paste0(versao$commit, if (isTRUE(versao$sujo)) "+sujo" else "")
cam <- caminhos_rodada(dia, oficial); pasta <- cam$pasta; dir.create(pasta, showWarnings = FALSE, recursive = TRUE)
ctx <- new.env(); ctx$avisos <- character(0)
ultimo <- function(prefixo, cod) { f <- sort(list.files(dados("data/raw"), sprintf("^%s_%s_.*\\.json$", prefixo, cod), full.names = TRUE)); if (length(f)) f[length(f)] else NA_character_ }

# ---- 1. BCB: SGS 4642 (regional), 4643 (estaduais), 4644 (municipais) ------------------------------------------------------
et_bcb <- function(ctx) {
  erros <- character(0)
  if (!sem_download) for (cod in SGS_PRIMARIO) tryCatch(baixar_sgs(cod, SGS_INICIO_DOWNLOAD, hoje, hoje = hoje), error = function(e) erros <<- c(erros, sprintf("SGS %d: %s", cod, conditionMessage(e))))
  if (!sem_download) tryCatch(baixar_sgs(433, as.Date("2014-01-01"), hoje, hoje = hoje), error = function(e) ctx$avisos <- c(ctx$avisos, paste("SGS 433 (IPCA, deflator do P2 projetado): download falhou, usa o arquivo local:", conditionMessage(e))))
  arqs <- vapply(unname(SGS_PRIMARIO), function(c) ultimo("bcb_sgs", c), ""); names(arqs) <- c("regional", "estaduais", "municipais")
  if (anyNA(arqs)) stop("sem arquivo local do SGS: ", paste(names(arqs)[is.na(arqs)], collapse = ", "), call. = FALSE)
  ctx$series <- lapply(arqs, function(a) { s <- ler_sgs(a); primario_bi(s[s$data >= SGS_INICIO_ANALISE, ]) })
  ctx$arq_sgs <- arqs
  ctx$corte <- corte_efetivo(ctx$series$regional)      # corte do DADO (trava a)
  if (length(erros)) stop("download falhou, P1 sai com o último dado local (mês ", ctx$corte$m, "/", ctx$corte$ano_alvo, "): ", paste(erros, collapse = " | "), call. = FALSE)
}

# ---- 2. PIB: IBGE (anos fechados) e premissas.yml (PIB nominal do ano-alvo) ---------------------------------------------------
et_pib <- function(ctx) {
  ano <- ctx$corte$ano_alvo
  arq <- if (sem_download) c(anual = ultimo("ibge_pib", "6784"), trimestral = ultimo("ibge_pib", "1846")) else tryCatch(baixar_pib_ibge(hoje = hoje), error = function(e) {
    ctx$avisos <- c(ctx$avisos, paste("IBGE/SIDRA indisponível, PIB do último arquivo local:", conditionMessage(e))); c(anual = ultimo("ibge_pib", "6784"), trimestral = ultimo("ibge_pib", "1846")) })
  pib <- pib_ibge_anual(arq[["anual"]], arq[["trimestral"]])[, c("ano", "pib_bi")]
  prem <- tryCatch(ler_premissas(ano_t = ano), error = function(e) NULL)
  ctx$prem <- prem
  pib <- pib[pib$ano < ano, ]
  if (!is.null(prem)) { ctx$pib_fonte <- paste("premissas.yml", prem$versao); pib <- rbind(pib, data.frame(ano = ano, pib_bi = prem$anos$pib_nominal[prem$anos$ano == ano])) }
  else { ctx$pib_fonte <- "aproximado (4 últimos trimestres do IBGE)"; ctx$avisos <- c(ctx$avisos, "premissas.yml ausente ou incompleta para o ano-alvo: faixa e m3 usam o PIB aproximado, não oficial")
         pib <- rbind(pib, data.frame(ano = ano, pib_bi = pib_ultimos_4_trimestres(arq[["trimestral"]])$pib_bi)) }
  ctx$pib <- pib
}

# ---- 3. Siconfi: RREO dos estados (t e t-1), Anexo 3 e DCA ---------------------------------------------------------------------
et_siconfi <- function(ctx) {
  entes <- ler_entes(baixar_entes(dados("data/raw/rreo"), hoje)); est <- listar_estados(entes)
  ano <- as.integer(format(hoje, "%Y"))
  r <- atualizar_rreo(est$cod_ibge, c(ano - 1L, ano), esfera = "E", hoje = hoje)
  atualizar_a3_dca(hoje = hoje)
  baixar_rgf_estados(2015:ano, hoje = hoje)          # RGF (pessoal) usado pelo alerta de reclassificacao; incremental
  ctx$jobs_rreo <- r
  if (isTRUE(attr(r, "falhas") > 0)) stop(attr(r, "falhas"), " ente(s) x ano com falha de rede no RREO; a próxima rodada tenta de novo", call. = FALSE)
}

sub_r <- function(script) {      # subprocesso: Rscript do mesmo R (no Windows o Rscript pode nao estar no PATH); saida so vai ao disco se falhar
  rs <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  env <- if (.Platform$OS.type == "windows") character(0) else "LC_ALL=C.UTF-8"
  out <- suppressWarnings(system2(rs, shQuote(script), env = env, stdout = TRUE, stderr = TRUE))
  st <- attr(out, "status"); if (is.null(st)) st <- 0L
  if (st != 0) {
    writeLines(utils::tail(out, 40), file.path(pasta, paste0("erro_", sub("\\.R$", "", basename(script)), ".txt")), useBytes = TRUE)
    stop(script, " terminou com status ", st, ": ", paste(utils::tail(out[nzchar(out)], 2), collapse = " | "), call. = FALSE)
  }
}
et_rbl <- function(ctx) sub_r("scripts/receita_bruta_liquida.R")      # fatores e receita mensal bruta/liquida (insumo dos alertas (c))
et_cu <- function(ctx) sub_r("scripts/conceito_unico.R")
et_alertas <- function(ctx) { sub_r("scripts/quebras_e28.R"); sub_r("scripts/alertas_priorizados.R") }

# ---- 4. P1: SRW por esfera, faixa do regional e arquivo de previsões (SRW oficial + m3 sombra) --------------------------------
et_p1 <- function(ctx) {
  c1 <- ctx$corte; ano <- c1$ano_alvo; m <- c1$m
  p1 <- p1_srw_esferas(ctx$series, ano, m)
  reg <- p1[p1$esfera == "regional", ]
  iv <- intervalo_p1_regional(ctx$series$regional, ctx$pib, ano, m, reg$previsao_bi)
  # cobertura congelada do protocolo (E4.2b): versionada no repositorio, nao e regerada a cada rodada nem mora na raiz de dados
  cob <- ler_csv(file.path("data", "protocolo", "e42b_cobertura.csv"))
  cob <- cob[grepl("^publicado", cob$amostra) & grepl("alvos 2008-2025$", cob$amostra), ]    # intervalo publicado, todos os alvos (o rotulo traz sigma)
  txt <- texto_cobertura(cob, m)
  m3 <- NA_real_
  if (m < 12) {
    fontes <- list(bcb = ctx$series$regional, bcb_est = ctx$series$estaduais, bcb_mun = ctx$series$municipais, pib = ctx$pib)
    m3 <- tryCatch(CANDIDATOS_P1_BASE$m3(montar_info(fontes, ano, m), ano, m), error = function(e) NA_real_)
  }
  ctx$p1 <- p1; ctx$iv <- iv; ctx$txt_cob <- txt; ctx$m3 <- m3
  gravar_csv(cbind(p1, faixa_intervalo_inf = c(iv$inf, NA, NA)[match(p1$esfera, c("regional", "estaduais", "municipais"))],
                   faixa_intervalo_sup = c(iv$sup, NA, NA)[match(p1$esfera, c("regional", "estaduais", "municipais"))]), file.path(pasta, "p1.csv"))
  vint <- sub("^.*_([0-9]{8})\\.json$", "\\1", ctx$arq_sgs[["regional"]])
  base <- data.frame(data_rodada = dia, ano_alvo = ano, corte_m = m, ultimo_dado = format(c1$ultimo), vintage_bcb = vint,
                     pib_ano_alvo_bi = ctx$pib$pib_bi[ctx$pib$ano == ano], commit = commit, stringsAsFactors = FALSE)
  srw <- cbind(base[rep(1, nrow(p1)), ], modelo = "srw_brl", esfera = p1$esfera, previsao_bi = p1$previsao_bi,
               intervalo_inf_bi = ifelse(p1$esfera == "regional", iv$inf, NA_real_), intervalo_sup_bi = ifelse(p1$esfera == "regional", iv$sup, NA_real_), oficial = TRUE)
  sombra <- cbind(base, modelo = "m3", esfera = "regional", previsao_bi = m3, intervalo_inf_bi = NA_real_, intervalo_sup_bi = NA_real_, oficial = FALSE)
  ctx$linhas_arquivo <- rbind(srw, sombra)
}

# ---- 4b. Arquivo de previsões emitidas: grava com o status da rodada (a avaliação prospectiva pode filtrar por ele) -----------------
et_arquivo <- function(ctx) {
  if (is.null(ctx$linhas_arquivo)) stop("sem previsões desta rodada para arquivar", call. = FALSE)
  cols <- setdiff(ARQUIVO_COLUNAS, "status_rodada"); l <- ctx$linhas_arquivo[, cols]
  if (!is.null(ctx$linhas_p2)) l <- rbind(l, ctx$linhas_p2[, cols])
  l$status_rodada <- ctx$status_prelim
  l$status_rodada <- ctx$status_prelim
  arquivar_previsoes(cam$arquivo, l)
}

# ---- 5. P2 realizado: categorias (com RPPS) e resultado com e sem RPPS (referência da LDO) --------------------------------------
et_p2 <- function(ctx) {
  dic <- ler_dicionario("data/dicionario_contas_estados.csv"); dc <- ler_dicionario("data/dicionario_colunas_estados.csv")
  rreo <- ler_rreo_cache(dados("data/raw/rreo"), "E")
  ano <- as.integer(format(hoje, "%Y"))
  # Conceito consolidado (decisao de 04/11/2026, docs/contrato.md): com RPPS, sem intraorcamentarias de 2023 em diante; a serie bruta fica como referencia.
  ctx$intra <- fluxo_intra(rreo)
  fl <- fluxos_a6_categorias(rreo, dic, dc)
  fh <- harmonizar_fluxos(fl, ctx$intra)
  checar_identidade_intra(fh[fh$exercicio %in% c(ano - 1L, ano), ], fl[fl$exercicio %in% c(ano - 1L, ano), ], ctx$intra)   # falha a etapa se categorias + nao alocada != total
  dic_sem <- dic; dic_sem$papel[dic_sem$anexo == "RREO-Anexo 06" & dic_sem$rpps %in% "incluido"] <- "memo_rpps"
  ctx$p2_ins <- list(fh = fh, fl = fl, fs = fluxos_a6_categorias(rreo, dic_sem, dc), rreo = rreo, dic = dic, dc = dc)
  cat_bim <- p2_categorias_bim(fh, c(ano - 1L, ano))
  gravar_csv(cat_bim, file.path(pasta, "p2_categorias.csv"))
  gravar_csv(p2_categorias_bim(fl, c(ano - 1L, ano)), file.path(pasta, "p2_categorias_bruto.csv"))
  x <- ler_csv(dados("outputs/conceito_unico_bimestral.csv"))
  xh <- harmonizar_conceito_unico(x[x$exercicio >= 2018, ], ctx$intra); ctx$xh <- xh
  com <- p2_estados_bim(xh)[, c("exercicio", "periodo", "n_ufs", "p2")]; names(com)[4] <- "p2_com"
  bru <- p2_estados_bim(transform(xh, rec_total = rec_total_bruto, primario_a6 = primario_a6_bruto))[, c("exercicio", "periodo", "p2")]; names(bru)[3] <- "p2_com_bruto"
  sem <- p2_sem_rpps_ldo_bim(rreo)[, c("exercicio", "periodo", "p2_com")]; names(sem)[3] <- "p2_sem"
  tot <- merge(merge(com, bru, by = c("exercicio", "periodo"), all.x = TRUE), sem, by = c("exercicio", "periodo"), all.x = TRUE)
  tot <- tot[order(tot$exercicio, tot$periodo), ]
  ctx$p2_tot <- tot[!is.na(tot$p2_com) & tot$exercicio >= ano - 1L, ]
  gravar_csv(ctx$p2_tot, file.path(pasta, "p2_resultado.csv"))
}

# ---- 5b. P2 projetado (E5): modelo adotado por serie e faixa (data/protocolo/e5_adocao.csv); os demais candidatos vao ao arquivo como sombra --------------
et_p2_proj <- function(ctx) {
  if (is.null(ctx$p2_ins)) stop("sem os fluxos do P2 (etapa p2 falhou)", call. = FALSE)
  ano <- ctx$corte$ano_alvo; f_ipca <- ultimo("bcb_sgs", "433")
  if (is.na(f_ipca)) stop("sem arquivo local do SGS 433 (IPCA)", call. = FALSE)
  sgs <- ler_sgs(f_ipca); ip <- if (!is.null(ctx$prem)) ctx$prem$anos$ipca[ctx$prem$anos$ano == ano] else NA_real_
  if (length(ip) != 1 || is.na(ip)) { ctx$avisos <- c(ctx$avisos, "premissas.yml sem IPCA do ano-alvo: restante do ano deflacionado pelo IPCA dos ultimos 12 meses (nao oficial)"); ip <- prod(1 + utils::tail(sgs$valor, 12) / 100) - 1 }
  adocao <- e5_ler_adocao(); i <- ctx$p2_ins
  r <- e5_projecao_rodada(i$fh, i$fl, i$fs, i$rreo, i$dic, i$dc, sgs, ip, ano, adocao)
  if (is.null(r)) { ctx$avisos <- c(ctx$avisos, sprintf("P2 projetado: sem bimestre utilizavel em %d (ano fechado ou UFs incompletas)", ano)); return(invisible(NULL)) }
  ctx$p2_proj <- r; r$premissa_ipca <- ip
  sal <- e5_salto_troca(r, adocao); ctx$p2_salto <- sal
  gravar_csv(r$cresc, file.path(pasta, "p2_projecao.csv")); gravar_csv(e5_primario(r$cresc[!grepl("^prev_", r$cresc$modelo), ]), file.path(pasta, "p2_projecao_primario.csv"))
  gravar_csv(r$uf[!grepl("^prev_", r$uf$modelo), ], file.path(pasta, "p2_projecao_uf.csv"))
  if (!is.null(sal)) gravar_csv(sal, file.path(pasta, "p2_projecao_salto.csv"))
  cc <- r$cresc[r$cresc$conceito == "consolidado" & !grepl("^prev_", r$cresc$modelo), ]
  c1 <- ctx$corte; vint <- sub("^.*_([0-9]{8})\\.json$", "\\1", ctx$arq_sgs[["regional"]])
  ctx$linhas_p2 <- data.frame(data_rodada = dia, modelo = paste0("p2_", sub("^[a-z]+:", "", cc$serie), "_", cc$modelo), esfera = ifelse(cc$serie == "rec:total", "estados_receita", "estados_despesa"), ano_alvo = ano, corte_m = 2L * r$corte,
    ultimo_dado = format(c1$ultimo), vintage_bcb = vint, pib_ano_alvo_bi = ctx$pib$pib_bi[ctx$pib$ano == ano], previsao_bi = cc$That_bi, intervalo_inf_bi = NA_real_, intervalo_sup_bi = NA_real_, oficial = cc$oficial, commit = commit, stringsAsFactors = FALSE)
}

# ---- 6. Gap P1 x P2 (regra congelada em docs/contrato.md), com e sem 2020-22 --------------------------------------------------
et_gap <- function(ctx) {
  if (is.null(ctx$xh)) stop("gap exige o P2 harmonizado (etapa p2)", call. = FALSE)
  p2 <- p2_estados_bim(ctx$xh)                                                 # conceito consolidado (decisao de 04/11/2026)
  p2_bruto <- p2_estados_bim(transform(ctx$xh, rec_total = rec_total_bruto, primario_a6 = primario_a6_bruto))
  p1 <- p1_estados_bim(ctx$series$estaduais |> (\(s) data.frame(data = s$data, valor = -s$valor_bi * 1000))())
  h <- ler_csv(dados("outputs/quebras_pessoal_harmonizado.csv")); exc <- aggregate(excedente ~ exercicio + periodo, h, sum)
  db <- gap_bimestral(p2_bruto, p1, exc); db <- db[!is.na(db$g), c("exercicio", "periodo", "p2", "p1", "g", "r")]
  gravar_csv(db, file.path(pasta, "gap_bruto.csv"))                             # referencia: gap com as intra de 2023 em diante
  d <- gap_bimestral(p2, p1, exc); d <- d[!is.na(d$g), ]
  rot <- function(ex) { cb <- classificar_gap(d, "r", ex); ifelse(d$apos_reclass & cb$classe != "excluido", "quebra_conhecida", cb$classe) }
  d$classe_informe <- rot(integer(0)); d$classe_sem_2020_22 <- rot(2020:2022)
  gravar_csv(d[, c("exercicio", "periodo", "p2", "p1", "g", "r", "classe_informe", "classe_sem_2020_22")], file.path(pasta, "gap.csv"))
  ctx$gap <- d
}

# ---- 7. Alertas: lista da aba e contagem ----------------------------------------------------------------------------------------
et_aba <- function(ctx) {
  ano <- as.integer(format(hoje, "%Y"))
  p <- ler_csv(dados("outputs/alertas_priorizados.csv"))
  p <- p[is.na(p$exercicio) | p$exercicio >= ano - 1L, ]       # a rodada confere os exercicios t e t-1 (o historico antigo e saldo, nao a rodada)
  ult <- bimestre_referencia(hoje)                                                   # prazo legal vencido antes da data da rodada
  x <- ler_csv(dados("outputs/conceito_unico_bimestral.csv")); x <- x[!is.na(x$rec_total), ]
  nb <- aggregate(periodo ~ cod_ibge + exercicio, x, length); ra <- aggregate(rec_total ~ cod_ibge + exercicio, x, sum)
  ra <- merge(ra, nb[nb$periodo == 6L, c("cod_ibge", "exercicio")])                      # so anos completos da UF
  ok <- names(which(table(ra$exercicio) == 27L)); ra <- ra[ra$exercicio %in% as.integer(ok), ]   # e so exercicios com as 27 UFs
  peso <- peso_receita_uf(ra, p$cod_ibge, p$exercicio)
  ab <- aba_alertas_rodada(list(alertas = p), ult, peso)
  gravar_csv(ab$lista, file.path(pasta, "alertas_aba_lista.csv")); gravar_csv(ab$contagem, file.path(pasta, "alertas_aba_contagem.csv"))
  n <- function(g) c(lista = sum(ab$lista$grupo == g), contagem = sum(ab$contagem$n[ab$contagem$grupo == g]))
  ctx$alertas <- list(lista_ultimo = n("ultimo")[["lista"]], contagem_ultimo = n("ultimo")[["contagem"]],
                      lista_revisao = n("revisao")[["lista"]], contagem_revisao = n("revisao")[["contagem"]], ultimo = ult)
}

# ---- 8. Informe (E6.2): planilha e texto, so de outputs da rodada e do arquivo de previsoes ---------------------------------------------------------
et_informe <- function(ctx) {
  if (is.null(ctx$p1)) stop("informe exige o P1 (etapa p1)", call. = FALSE)
  ano <- ctx$corte$ano_alvo; p1 <- ctx$p1; k <- match(p1$esfera, c("regional", "estaduais", "municipais"))
  p1$faixa_intervalo_inf <- c(ctx$iv$inf, NA, NA)[k]; p1$faixa_intervalo_sup <- c(ctx$iv$sup, NA, NA)[k]
  lido <- function(n) tryCatch(ler_csv(file.path(pasta, n)), error = function(e) NULL)
  ind <- tryCatch(e5_ipca_bim(ler_sgs(ultimo("bcb_sgs", "433"))), error = function(e) NULL)
  fh_tot <- if (!is.null(ctx$p2_ins)) e5_com_totais(ctx$p2_ins$fh) else NULL
  base_ant <- NULL
  if (!is.null(fh_tot) && !is.null(ctx$p2_proj)) {
    b <- ctx$p2_proj$corte; x <- fh_tot[fh_tot$exercicio == ano - 1L & fh_tot$serie %in% c("rec:total", "desp:total"), ]
    A <- aggregate(valor ~ cod_ibge + serie, x[x$periodo <= b, ], sum); T <- aggregate(valor ~ cod_ibge + serie, x, sum)
    base_ant <- merge(setNames(A, c("cod_ibge", "serie", "A")), setNames(T, c("cod_ibge", "serie", "T")))
  }
  arq <- if (file.exists(cam$arquivo)) ler_csv(cam$arquivo, colClasses = c(data_rodada = "character", vintage_bcb = "character", ultimo_dado = "character", commit = "character")) else NULL
  rm <- tryCatch(ler_csv(file.path("data", "protocolo", "e5_rmse_agregado.csv"), colClasses = c(membros = "character")), error = function(e) NULL); if (!is.null(rm)) rm$membros[is.na(rm$membros)] <- ""
  rel <- tryCatch(ler_csv(file.path("data", "protocolo", "p1_rmse_relativo.csv")), error = function(e) NULL)
  stn <- tryCatch(carregar_stn(), error = function(e) NULL)
  I <- list(p1_rel = rel, stn = stn, dia = dia, oficial = oficial, status = ctx$status_prelim, commit = commit, corte = ctx$corte, bim_ref = ctx$alertas$ultimo, prem = ctx$prem, p1 = p1, iv = ctx$iv, txt_cob = ctx$txt_cob, pib = ctx$pib, series = ctx$series,
            gap = ctx$gap[, c("exercicio", "periodo", "p2", "p1", "g", "r", "classe_informe", "classe_sem_2020_22")], p2_tot = ctx$p2_tot, p2_cat = if (!is.null(lido("p2_categorias.csv"))) informe_p2(lido("p2_categorias.csv"), ind, ano) else NULL,
            alertas_lista = lido("alertas_aba_lista.csv"), alertas_contagem = lido("alertas_aba_contagem.csv"), proj = ctx$p2_proj, rmse = rm, arquivo = arq, fh_tot = fh_tot, base_ant = base_ant)
  escrever_informe(I, file.path(pasta, "informe.xlsx"), file.path(pasta, "informe_texto.md"), file.path(pasta, "informe_interno.xlsx"))
}

# ---- Execução ----------------------------------------------------------------------------------------------------------------------
pula <- function(nome, motivo) etapa_pulada(nome, motivo)
etapas <- rbind(
  rodar_etapa("bcb", et_bcb, ctx))
if (!exists("series", envir = ctx)) { cat("Erro fatal: sem série do BCB.\n"); writeLines(etapas$msg, file.path(pasta, "resumo.md")); quit(status = 1) }
etapas <- rbind(etapas,
  rodar_etapa("pib", et_pib, ctx),
  if (sem_download) pula("siconfi", "--sem-download") else rodar_etapa("siconfi", et_siconfi, ctx),
  if (rapida) pula("receita_bruta_liquida", "--rapida") else rodar_etapa("receita_bruta_liquida", et_rbl, ctx),
  if (rapida) pula("conceito_unico", "--rapida") else rodar_etapa("conceito_unico", et_cu, ctx),
  if (rapida) pula("alertas", "--rapida") else rodar_etapa("alertas", et_alertas, ctx),
  rodar_etapa("p1", et_p1, ctx),
  rodar_etapa("p2", et_p2, ctx),
  rodar_etapa("p2_projecao", et_p2_proj, ctx),
  rodar_etapa("gap", et_gap, ctx),
  rodar_etapa("aba_alertas", et_aba, ctx))
ctx$status_prelim <- status_rodada(etapas, ctx$avisos)$status      # o arquivo guarda o status das etapas anteriores a ele
etapas <- rbind(etapas, rodar_etapa("arquivo", et_arquivo, ctx))
etapas <- rbind(etapas, rodar_etapa("informe", et_informe, ctx))
st <- status_rodada(etapas, ctx$avisos)
gravar_csv(etapas[, c("etapa", "estado", "msg")], file.path(pasta, "etapas.csv"))
writeLines(c(sprintf("carimbo: %s", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")), sprintf("commit: %s", commit), sprintf("fonte_commit: %s", versao$fonte), paste0(etapas$etapa, ": ", etapas$segundos, " s")), file.path(pasta, "carimbo.txt"))
txt <- resumo_rodada(dia, st, etapas, ctx$p1, ctx$iv, ctx$txt_cob, ctx$gap, ctx$alertas, if (!is.null(ctx$p2_tot)) utils::tail(ctx$p2_tot, 4), oficial, ctx$p2_proj, ctx$p2_salto)
writeLines(txt, file.path(pasta, "resumo.md"), useBytes = TRUE)
cat(txt)
quit(status = codigo_saida(st$status))
