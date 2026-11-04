# E6.1: rodada mensal. Um comando: baixar -> validar -> projetar (P1) -> P2 realizado -> gap -> alertas -> arquivar -> resumo.
# Uso: Rscript scripts/rodada_mensal.R [--data=AAAA-MM-DD] [--sem-download] [--rapida]
#   --oficial       rodada oficial: grava em outputs/rodada e no arquivo de previsões emitidas. Sem esta opção a rodada é de TESTE e grava em
#                   outputs/teste/ (arquivo de previsões incluído). Não vale com --sem-download nem --rapida.
#   --sem-download  pula Siconfi, BCB e IBGE (usa o que está em data/raw); a rodada sai DEGRADADA.
#   --rapida        pula conceito único e alertas (usa as saídas de outputs/ já calculadas); a rodada sai DEGRADADA.
# Dados sob a raiz FISCAL_DADOS (padrão: a pasta do repositório); ver docs/HANDOVER.md, 3h.
# Saída: outputs/rodada/<data>/ (resumo.md, p1.csv, p2_categorias.csv, p2_resultado.csv, gap.csv, alertas_*.csv, etapas.csv, carimbo.txt) e o
# arquivo de previsões emitidas outputs/arquivo/previsoes_emitidas.csv (uma linha por rodada x modelo x esfera x ano-alvo).
# Código de saída: 0 = OK; 2 = DEGRADADA (alguma etapa falhou ou foi pulada); 1 = erro fatal. Rodar no Windows da CNI: ver docs/HANDOVER.md.
# A rodada é sequencial: no máximo 1 conexão por vez ao Siconfi (limite combinado: 2).
args <- commandArgs(TRUE)
opt <- function(nome, padrao = NA_character_) { a <- grep(paste0("^--", nome, "="), args, value = TRUE); if (length(a)) sub(paste0("^--", nome, "="), "", a[1]) else padrao }
sem_download <- "--sem-download" %in% args; rapida <- "--rapida" %in% args; oficial <- "--oficial" %in% args
if (oficial && (sem_download || rapida)) { cat("Erro: --oficial exige a rodada completa (sem --sem-download nem --rapida).\n"); quit(status = 1) }
hoje <- as.Date(opt("data", format(Sys.Date())))
dia <- format(hoje)
invisible(Sys.setlocale("LC_COLLATE", "C"))
# (R/utils_io.R ja carregado pelo ponto de entrada)
arqs <- list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
arqs <- c(arqs[!grepl("candidatos_p1", arqs)], arqs[grepl("candidatos_p1", arqs)])   # candidatos_p1 depende de ESPEC_RESTANTE
carregar_r(arqs)

commit <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE, ignore.stderr = TRUE), error = function(e) NA_character_)
sujo <- tryCatch(length(system("git status --porcelain -- R scripts data/dicionario_contas_estados.csv", intern = TRUE, ignore.stderr = TRUE)) > 0, error = function(e) FALSE)
commit <- paste0(commit, if (isTRUE(sujo)) "+sujo" else "")
cam <- caminhos_rodada(dia, oficial); pasta <- cam$pasta; dir.create(pasta, showWarnings = FALSE, recursive = TRUE)
ctx <- new.env(); ctx$avisos <- character(0)
ultimo <- function(prefixo, cod) { f <- sort(list.files(dados("data/raw"), sprintf("^%s_%s_.*\\.json$", prefixo, cod), full.names = TRUE)); if (length(f)) f[length(f)] else NA_character_ }

# ---- 1. BCB: SGS 4642 (regional), 4643 (estaduais), 4644 (municipais) ------------------------------------------------------
et_bcb <- function(ctx) {
  erros <- character(0)
  if (!sem_download) for (cod in SGS_PRIMARIO) tryCatch(baixar_sgs(cod, SGS_INICIO_DOWNLOAD, hoje, hoje = hoje), error = function(e) erros <<- c(erros, sprintf("SGS %d: %s", cod, conditionMessage(e))))
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
  l <- ctx$linhas_arquivo; l$status_rodada <- ctx$status_prelim
  arquivar_previsoes(cam$arquivo, l)
}

# ---- 5. P2 realizado: categorias (com RPPS) e resultado com e sem RPPS (referência da LDO) --------------------------------------
et_p2 <- function(ctx) {
  dic <- ler_dicionario("data/dicionario_contas_estados.csv"); dc <- ler_dicionario("data/dicionario_colunas_estados.csv")
  rreo <- ler_rreo_pasta(dados("data/raw/rreo"), "E")
  ano <- as.integer(format(hoje, "%Y"))
  cat_bim <- p2_categorias_bim(fluxos_a6_categorias(rreo, dic, dc), c(ano - 1L, ano))
  gravar_csv(cat_bim, file.path(pasta, "p2_categorias.csv"))
  x <- ler_csv(dados("outputs/conceito_unico_bimestral.csv"))
  com <- p2_estados_bim(x[x$exercicio >= 2018, ])[, c("exercicio", "periodo", "n_ufs", "p2")]; names(com)[4] <- "p2_com"
  sem <- p2_sem_rpps_ldo_bim(rreo)[, c("exercicio", "periodo", "p2_com")]; names(sem)[3] <- "p2_sem"
  tot <- merge(com, sem, by = c("exercicio", "periodo"), all.x = TRUE)
  tot <- tot[order(tot$exercicio, tot$periodo), ]
  ctx$p2_tot <- tot[!is.na(tot$p2_com) & tot$exercicio >= ano - 1L, ]
  gravar_csv(ctx$p2_tot, file.path(pasta, "p2_resultado.csv"))
}

# ---- 6. Gap P1 x P2 (regra congelada em docs/contrato.md), com e sem 2020-22 --------------------------------------------------
et_gap <- function(ctx) {
  x <- ler_csv(dados("outputs/conceito_unico_bimestral.csv"))
  p2 <- p2_estados_bim(x[x$exercicio >= 2018, ])
  p1 <- p1_estados_bim(ctx$series$estaduais |> (\(s) data.frame(data = s$data, valor = -s$valor_bi * 1000))())
  h <- ler_csv(dados("outputs/quebras_pessoal_harmonizado.csv")); exc <- aggregate(excedente ~ exercicio + periodo, h, sum)
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
  rodar_etapa("gap", et_gap, ctx),
  rodar_etapa("aba_alertas", et_aba, ctx))
ctx$status_prelim <- status_rodada(etapas, ctx$avisos)$status      # o arquivo guarda o status das etapas anteriores a ele
etapas <- rbind(etapas, rodar_etapa("arquivo", et_arquivo, ctx))
st <- status_rodada(etapas, ctx$avisos)
gravar_csv(etapas[, c("etapa", "estado", "msg")], file.path(pasta, "etapas.csv"))
writeLines(c(sprintf("carimbo: %s", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")), sprintf("commit: %s", commit), paste0(etapas$etapa, ": ", etapas$segundos, " s")), file.path(pasta, "carimbo.txt"))
txt <- resumo_rodada(dia, st, etapas, ctx$p1, ctx$iv, ctx$txt_cob, ctx$gap, ctx$alertas, if (!is.null(ctx$p2_tot)) utils::tail(ctx$p2_tot, 4), oficial)
writeLines(txt, file.path(pasta, "resumo.md"), useBytes = TRUE)
cat(txt)
quit(status = codigo_saida(st$status))
