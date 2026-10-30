# E6.1: rodada mensal. Um comando: baixar -> validar -> projetar (P1) -> P2 realizado -> gap -> alertas -> arquivar -> resumo.
# Uso: Rscript scripts/rodada_mensal.R [--data=AAAA-MM-DD] [--sem-download] [--rapida]
#   --sem-download  pula Siconfi, BCB e IBGE (usa o que está em data/raw); a rodada sai DEGRADADA.
#   --rapida        pula conceito único e alertas (usa as saídas de outputs/ já calculadas); a rodada sai DEGRADADA.
# Saída: outputs/rodada/<data>/ (resumo.md, p1.csv, p2_categorias.csv, p2_resultado.csv, gap.csv, alertas_*.csv, etapas.csv, carimbo.txt) e o
# arquivo de previsões emitidas outputs/arquivo/previsoes_emitidas.csv (uma linha por rodada x modelo x esfera x ano-alvo).
# Código de saída: 0 = OK; 2 = DEGRADADA (alguma etapa falhou ou foi pulada); 1 = erro fatal. Rodar no Windows da CNI: ver docs/HANDOVER.md.
# A rodada é sequencial: no máximo 1 conexão por vez ao Siconfi (limite combinado: 2).
args <- commandArgs(TRUE)
opt <- function(nome, padrao = NA_character_) { a <- grep(paste0("^--", nome, "="), args, value = TRUE); if (length(a)) sub(paste0("^--", nome, "="), "", a[1]) else padrao }
sem_download <- "--sem-download" %in% args; rapida <- "--rapida" %in% args
hoje <- as.Date(opt("data", format(Sys.Date())))
dia <- format(hoje)
invisible(Sys.setlocale("LC_COLLATE", "C"))
source("R/utils_io.R", encoding = "UTF-8")
arqs <- list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
arqs <- c(arqs[!grepl("candidatos_p1", arqs)], arqs[grepl("candidatos_p1", arqs)])   # candidatos_p1 depende de ESPEC_RESTANTE
invisible(lapply(arqs, source, encoding = "UTF-8"))

commit <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE, ignore.stderr = TRUE), error = function(e) NA_character_)
sujo <- tryCatch(length(system("git status --porcelain -- R scripts data/dicionario_contas_estados.csv", intern = TRUE, ignore.stderr = TRUE)) > 0, error = function(e) FALSE)
commit <- paste0(commit, if (isTRUE(sujo)) "+sujo" else "")
pasta <- file.path("outputs", "rodada", dia); dir.create(pasta, showWarnings = FALSE, recursive = TRUE)
ctx <- new.env(); ctx$avisos <- character(0)
ultimo <- function(prefixo, cod) { f <- sort(list.files("data/raw", sprintf("^%s_%s_.*\\.json$", prefixo, cod), full.names = TRUE)); if (length(f)) f[length(f)] else NA_character_ }

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
  entes <- ler_entes(baixar_entes("data/raw/rreo", hoje)); est <- listar_estados(entes)
  ano <- as.integer(format(hoje, "%Y"))
  r <- atualizar_rreo(est$cod_ibge, c(ano - 1L, ano), esfera = "E", hoje = hoje)
  atualizar_a3_dca(hoje = hoje)
  ctx$jobs_rreo <- r
  if (isTRUE(attr(r, "falhas") > 0)) stop(attr(r, "falhas"), " ente(s) x ano com falha de rede no RREO; a próxima rodada tenta de novo", call. = FALSE)
}

sub_r <- function(script) { s <- system2("Rscript", script, env = "LC_ALL=C.UTF-8", stdout = FALSE, stderr = FALSE); if (s != 0) stop(script, " terminou com status ", s, call. = FALSE) }
et_cu <- function(ctx) sub_r("scripts/conceito_unico.R")
et_alertas <- function(ctx) { sub_r("scripts/quebras_e28.R"); sub_r("scripts/alertas_priorizados.R") }

# ---- 4. P1: SRW por esfera, faixa do regional e arquivo de previsões (SRW oficial + m3 sombra) --------------------------------
et_p1 <- function(ctx) {
  c1 <- ctx$corte; ano <- c1$ano_alvo; m <- c1$m
  p1 <- p1_srw_esferas(ctx$series, ano, m)
  reg <- p1[p1$esfera == "regional", ]
  iv <- intervalo_p1_regional(ctx$series$regional, ctx$pib, ano, m, reg$previsao_bi)
  cob <- ler_csv("outputs/e42b_cobertura.csv"); cob <- cob[cob$amostra == "publicado (σ com 2020-22), alvos 2008-2025", ]
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
  arquivar_previsoes("outputs/arquivo/previsoes_emitidas.csv", l)
}

# ---- 5. P2 realizado: categorias (com RPPS) e resultado com e sem RPPS (referência da LDO) --------------------------------------
et_p2 <- function(ctx) {
  dic <- ler_dicionario("data/dicionario_contas_estados.csv"); dc <- ler_dicionario("data/dicionario_colunas_estados.csv")
  rreo <- ler_rreo_pasta("data/raw/rreo", "E")
  ano <- as.integer(format(hoje, "%Y"))
  cat_bim <- p2_categorias_bim(fluxos_a6_categorias(rreo, dic, dc), c(ano - 1L, ano))
  gravar_csv(cat_bim, file.path(pasta, "p2_categorias.csv"))
  x <- ler_csv("outputs/conceito_unico_bimestral.csv")
  com <- p2_estados_bim(x[x$exercicio >= 2018, ])[, c("exercicio", "periodo", "n_ufs", "p2")]; names(com)[4] <- "p2_com"
  sem <- p2_sem_rpps_ldo_bim(rreo)[, c("exercicio", "periodo", "p2_com")]; names(sem)[3] <- "p2_sem"
  tot <- merge(com, sem, by = c("exercicio", "periodo"), all.x = TRUE)
  tot <- tot[order(tot$exercicio, tot$periodo), ]
  ctx$p2_tot <- tot[!is.na(tot$p2_com) & tot$exercicio >= ano - 1L, ]
  gravar_csv(ctx$p2_tot, file.path(pasta, "p2_resultado.csv"))
}

# ---- 6. Gap P1 x P2 (regra congelada em docs/contrato.md), com e sem 2020-22 --------------------------------------------------
et_gap <- function(ctx) {
  x <- ler_csv("outputs/conceito_unico_bimestral.csv")
  p2 <- p2_estados_bim(x[x$exercicio >= 2018, ])
  p1 <- p1_estados_bim(ctx$series$estaduais |> (\(s) data.frame(data = s$data, valor = -s$valor_bi * 1000))())
  h <- ler_csv("outputs/quebras_pessoal_harmonizado.csv"); exc <- aggregate(excedente ~ exercicio + periodo, h, sum)
  d <- gap_bimestral(p2, p1, exc); d <- d[!is.na(d$g), ]
  rot <- function(ex) { cb <- classificar_gap(d, "r", ex); ifelse(d$apos_reclass & cb$classe != "excluido", "quebra_conhecida", cb$classe) }
  d$classe_informe <- rot(integer(0)); d$classe_sem_2020_22 <- rot(2020:2022)
  gravar_csv(d[, c("exercicio", "periodo", "p2", "p1", "g", "r", "classe_informe", "classe_sem_2020_22")], file.path(pasta, "gap.csv"))
  ctx$gap <- d
}

# ---- 7. Alertas: lista da aba e contagem ----------------------------------------------------------------------------------------
et_aba <- function(ctx) {
  p <- ler_csv("outputs/alertas_priorizados.csv"); ano <- as.integer(format(hoje, "%Y"))
  p <- p[is.na(p$exercicio) | p$exercicio >= ano - 1L, ]       # a rodada confere os exercicios t e t-1 (o historico antigo e o saldo, nao a rodada)
  ab <- aba_alertas(list(alertas = p))
  gravar_csv(ab$lista, file.path(pasta, "alertas_aba_lista.csv")); gravar_csv(ab$contagem, file.path(pasta, "alertas_aba_contagem.csv"))
  ctx$alertas <- list(lista = nrow(ab$lista), contagem = sum(ab$contagem$n))
}

# ---- Execução ----------------------------------------------------------------------------------------------------------------------
pula <- function(nome, motivo) etapa_pulada(nome, motivo)
etapas <- rbind(
  rodar_etapa("bcb", et_bcb, ctx))
if (!exists("series", envir = ctx)) { cat("Erro fatal: sem série do BCB.\n"); writeLines(etapas$msg, file.path(pasta, "resumo.md")); quit(status = 1) }
etapas <- rbind(etapas,
  rodar_etapa("pib", et_pib, ctx),
  if (sem_download) pula("siconfi", "--sem-download") else rodar_etapa("siconfi", et_siconfi, ctx),
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
txt <- resumo_rodada(dia, st, etapas, ctx$p1, ctx$iv, ctx$txt_cob, ctx$gap, ctx$alertas, if (!is.null(ctx$p2_tot)) utils::tail(ctx$p2_tot, 4))
writeLines(txt, file.path(pasta, "resumo.md"), useBytes = TRUE)
cat(txt)
quit(status = codigo_saida(st$status))
