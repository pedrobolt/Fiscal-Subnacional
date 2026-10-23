source(file.path("..", "R", "ambiente.R"), chdir = TRUE)

test_that("checar_ambiente lista R e os pacotes essenciais", {
  amb <- checar_ambiente()
  expect_s3_class(amb, "data.frame")
  expect_equal(amb$pacote, c("R", "targets", "testthat", "renv"))
  expect_false(anyNA(amb$versao))
})

test_that("checar_ambiente falha com pacote ausente", {
  expect_error(checar_ambiente("pacoteQueNaoExiste123"), "Pacotes ausentes")
})
