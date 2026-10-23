library(testthat)
source("../R/quality/consistencia_sgs.R")

mk <- function(v) data.frame(data = as.Date("2020-01-01") + 31 * 0:2, valor = v)

test_that("aceita soma com diferença de arredondamento", {
  expect_silent(checar_soma_regional(mk(c(10, 20, 30)), mk(c(1, 2, 3)), mk(c(11.01, 22, 33))))
})

test_that("falha se a soma divergir além da tolerância", {
  expect_error(checar_soma_regional(mk(c(10, 20, 30)), mk(c(1, 2, 3)), mk(c(11, 25, 33))), "diferem")
})

test_that("falha se as datas forem diferentes", {
  r <- mk(c(11, 22, 33)); r$data[3] <- r$data[3] + 1
  expect_error(checar_soma_regional(mk(c(10, 20, 30)), mk(c(1, 2, 3)), r), "datas")
})

test_that("aceita 4642 com datas anteriores às de 4643/4644", {
  reg <- data.frame(data = as.Date("2019-12-01") + c(0, 31 * 1:3), valor = c(5, 11, 22, 33))
  expect_silent(checar_soma_regional(mk(c(10, 20, 30)), mk(c(1, 2, 3)), reg))
})
