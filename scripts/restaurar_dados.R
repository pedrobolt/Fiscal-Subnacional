# Carga inicial do bruto do RREO a partir de um GitHub Release (dados públicos do Siconfi).
# Uso: Rscript scripts/restaurar_dados.R <arquivo.tar.gz> <manifesto.csv>
#   1) baixe os dois arquivos do Release (página Releases do repositório, ou `gh release download <tag>`)
#   2) rode este script na raiz do repositório: extrai em data/raw/rreo/ e confere tamanho e MD5 de todos os arquivos.
# Depois da carga, baixar_rreo*() só busca o que falta (arquivo existente nunca é rebaixado).
source("_targets.R")
args <- commandArgs(TRUE)
if (length(args) < 2) stop("Uso: Rscript scripts/restaurar_dados.R <arquivo.tar.gz> <manifesto.csv>")
dir.create("data/raw", showWarnings = FALSE, recursive = TRUE)
utils::untar(args[1], exdir = "data/raw", tar = "internal")
man <- utils::read.csv(fileEncoding = "UTF-8", args[2], stringsAsFactors = FALSE)
atual <- manifesto_arquivos("data/raw/rreo")
m <- merge(man, atual, by = "arquivo", all.x = TRUE, suffixes = c("", "_atual"))
falta <- m$arquivo[is.na(m$md5_atual)]
difere <- m$arquivo[!is.na(m$md5_atual) & m$md5 != m$md5_atual]
cat("Arquivos no manifesto:", nrow(man), "| ausentes:", length(falta), "| com MD5 diferente:", length(difere), "\n")
if (length(falta) + length(difere) > 0) stop("Carga inconsistente: refaça o download do Release.")
cat("Carga conferida.\n")
