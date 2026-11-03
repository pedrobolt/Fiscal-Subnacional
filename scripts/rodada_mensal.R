# E6.1: rodada mensal. Ponto de entrada (somente ASCII): carrega o carregador UTF-8 e o corpo da rodada.
# Uso: Rscript scripts/rodada_mensal.R [--oficial] [--data=AAAA-MM-DD] [--sem-download] [--rapida]   (opcoes e saidas: scripts/rodada_mensal_corpo.R)
# O corpo tem acentos e e lido como UTF-8 por carregar_r(): Rscript le o arquivo de entrada na codificacao nativa (Windows, code page != 65001).
source("R/utils_io.R", encoding = "UTF-8")
carregar_r("scripts/rodada_mensal_corpo.R")
