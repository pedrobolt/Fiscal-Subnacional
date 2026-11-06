# Consolidação do RREO bruto em tabela longa (E2.1/E2.4). Sem somar contas, sem interpolar, sem reclassificar.

#' Lê a versão vigente (a mais recente) de cada demonstrativo de uma esfera em `pasta` e empilha
#' (uma linha por conta x coluna). Acrescenta: `tipo_demonstrativo` ("RREO" ou "RREO Simplificado"),
#' `arquivo` (caminho relativo a `pasta`), `baixado_em` (UTC) da versão usada e `baixado_em_fonte`
#' ("nome", "log" ou "mtime"; ver `datas_versoes`).
#' Arquivos vazios (ente sem declaração) não geram linhas; a ausência aparece em cobertura_rreo().
ler_rreo_pasta <- function(pasta = dados("data/raw/rreo"), esfera = "E") {
  vigentes <- rreo_vigentes(pasta, esfera)
  if (length(vigentes) == 0) return(data.frame())
  datas <- datas_versoes(vigentes, pasta)
  datas$arquivo <- vigentes
  partes <- lapply(vigentes, function(a) {
    d <- ler_rreo(a)
    if (nrow(d) == 0) return(NULL)
    d$tipo_demonstrativo <- if (grepl("_simpl(_s[0-9]{8}T[0-9]{6}Z)?\\.json\\.gz$", a)) "RREO Simplificado" else "RREO"
    d$arquivo <- substring(a, nchar(pasta) + 2)   # relativo a `pasta`
    k <- match(a, datas$arquivo)
    d$baixado_em <- datas$baixado_em[k]
    d$baixado_em_fonte <- datas$fonte[k]
    d
  })
  do.call(rbind, partes)
}

#' Arquivos vigentes (versao mais recente de cada demonstrativo) de uma esfera, em ordem estavel (por nome-base). character(0) se nao ha.
rreo_vigentes <- function(pasta = dados("data/raw/rreo"), esfera = "E") {
  arqs <- list.files(file.path(pasta, esfera), pattern = "\\.json\\.gz$", recursive = TRUE, full.names = TRUE)
  if (length(arqs) == 0) return(character(0))
  base <- sub(paste0(PADRAO_SUFIXO_SNAPSHOT, "(\\.json\\.gz)$"), "\\1", arqs)
  unname(vapply(split(arqs, base), function(x) { sn <- sort(x[grepl(PADRAO_SUFIXO_SNAPSHOT, x)]); if (length(sn)) sn[length(sn)] else x[1] }, character(1)))
}

RREO_CACHE_VERSAO <- 1L
.rreo_memo <- new.env()      # mesmo objeto para as etapas que rodam no mesmo processo

#' `ler_rreo_pasta()` com cache em disco (E6.1, desempenho). Le uma vez por rodada e grava em `cache` (RDS em data/processed/) a tabela e o
#' manifesto usado (arquivo relativo, tamanho, mtime). Nas leituras seguintes, redecodifica so os arquivos novos ou alterados (tamanho ou mtime
#' diferentes) e descarta os que deixaram de ser vigentes. O resultado e identico ao de `ler_rreo_pasta()` (mesmas linhas, ordem e colunas;
#' `baixado_em` e recalculado a cada chamada porque depende do log). `FISCAL_SEM_CACHE=1` ou `forcar = TRUE` ignoram o cache.
ler_rreo_cache <- function(pasta = dados("data/raw/rreo"), esfera = "E", cache = dados(file.path("data", "processed", paste0("rreo_cache_", esfera, ".rds"))), forcar = FALSE, aviso = TRUE) {
  if (forcar || identical(Sys.getenv("FISCAL_SEM_CACHE"), "1")) return(ler_rreo_pasta(pasta, esfera))
  vig <- rreo_vigentes(pasta, esfera)
  if (length(vig) == 0) return(data.frame())
  man <- data.frame(arquivo = substring(vig, nchar(pasta) + 2), tamanho = file.size(vig), mtime = as.numeric(file.mtime(vig)), stringsAsFactors = FALSE)
  chave <- paste(normalizePath(pasta, mustWork = FALSE), esfera)
  mesma <- function(a, b) !is.null(a) && nrow(a) == nrow(b) && identical(a$arquivo, b$arquivo) && identical(a$tamanho, b$tamanho) && identical(a$mtime, b$mtime)
  memo <- .rreo_memo[[chave]]
  tab <- NULL; velho <- NULL
  if (!is.null(memo) && mesma(memo$manifesto, man)) tab <- memo$tabela
  else {
    c0 <- if (file.exists(cache)) tryCatch(readRDS(cache), error = function(e) NULL, warning = function(w) NULL)
    if (is.list(c0) && identical(c0$versao, RREO_CACHE_VERSAO) && identical(c0$esfera, esfera) && is.data.frame(c0$tabela)) velho <- c0
    ok <- if (is.null(velho)) character(0) else { m <- velho$manifesto; k <- match(man$arquivo, m$arquivo); man$arquivo[!is.na(k) & man$tamanho == m$tamanho[k] & man$mtime == m$mtime[k]] }
    novos <- setdiff(man$arquivo, ok)
    if (aviso) cat(sprintf("RREO %s: %d arquivos vigentes, %d a decodificar (cache: %s)\n", esfera, nrow(man), length(novos), if (is.null(velho)) "ausente" else "valido"))
    manter <- if (is.null(velho)) NULL else velho$tabela[velho$tabela$arquivo %in% ok, ]
    partes <- list(manter)
    if (length(novos)) {
      cheios <- vig[match(novos, man$arquivo)]
      partes <- c(partes, lapply(cheios, function(a) {
        d <- ler_rreo(a); if (nrow(d) == 0) return(NULL)
        d$tipo_demonstrativo <- if (grepl("_simpl(_s[0-9]{8}T[0-9]{6}Z)?\\.json\\.gz$", a)) "RREO Simplificado" else "RREO"
        d$arquivo <- substring(a, nchar(pasta) + 2); d
      }))
    }
    tab <- do.call(rbind, partes[!vapply(partes, is.null, NA)]); if (is.null(tab)) tab <- data.frame()
    if (nrow(tab)) { tab <- tab[order(match(tab$arquivo, man$arquivo)), ]; rownames(tab) <- NULL }
    if (length(novos) || is.null(velho) || nrow(velho$manifesto) != nrow(man) || !identical(sort(velho$manifesto$arquivo), sort(man$arquivo))) {
      dir.create(dirname(cache), showWarnings = FALSE, recursive = TRUE); tmp <- paste0(cache, ".tmp", Sys.getpid())
      tryCatch({ saveRDS(list(versao = RREO_CACHE_VERSAO, esfera = esfera, manifesto = man, tabela = tab), tmp); file.rename(tmp, cache) }, error = function(e) if (file.exists(tmp)) file.remove(tmp))
    }
    assign(chave, list(manifesto = man, tabela = tab), envir = .rreo_memo)
  }
  if (!nrow(tab)) return(tab)
  datas <- datas_versoes(vig, pasta); k <- match(tab$arquivo, man$arquivo)
  tab$baixado_em <- datas$baixado_em[k]; tab$baixado_em_fonte <- datas$fonte[k]
  tab
}

#' Ids dos 27 entes estaduais a partir do arquivo de entes mais recente já baixado (sem rede).
ids_estados_local <- function(pasta = dados("data/raw/rreo")) {
  arqs <- sort(list.files(pasta, pattern = "^_entes_.*\\.json$", full.names = TRUE))
  if (length(arqs) == 0) stop("Sem arquivo de entes em ", pasta, ": rode baixar_rreo_estados().", call. = FALSE)
  listar_estados(ler_entes(arqs[length(arqs)]))$cod_ibge
}
