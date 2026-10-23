# Pipeline do projeto. Rodar com: Rscript -e "targets::tar_make()"
library(targets)

# Carrega todas as funções de R/ (subpastas incluídas)
for (arquivo in list.files("R", pattern = "\\.R$", recursive = TRUE, full.names = TRUE)) {
  source(arquivo)
}

list(
  # E1.1: alvo mínimo que confere o ambiente. Será substituído pelas etapas de dados (E1.5, E2).
  tar_target(ambiente, checar_ambiente())
)
