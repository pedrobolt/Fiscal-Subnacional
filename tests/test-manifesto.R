library(testthat)
source_utf8("../R/download/snapshots.R")
source_utf8("../R/quality/manifesto.R")

test_that("manifesto lista arquivos com md5 e resume por esfera e ano", {
  p <- tempfile(); dir.create(file.path(p, "M", "2025"), recursive = TRUE); dir.create(file.path(p, "E", "2024"), recursive = TRUE)
  writeLines("a", file.path(p, "M", "2025", "1_b6_a01.json.gz"))
  writeLines("bb", file.path(p, "M", "2025", "2_b6_a01.json.gz"))
  writeLines("c", file.path(p, "E", "2024", "3_b6_a01.json.gz"))
  write.csv(fileEncoding = "UTF-8", data.frame(momento = c("2026-10-23 10:00:00", "2026-10-23 11:00:00")), file.path(p, "_log.csv"), row.names = FALSE)
  m <- manifesto_arquivos(p)
  expect_equal(nrow(m), 4)
  expect_equal(m$md5[m$arquivo == "M/2025/1_b6_a01.json.gz"], unname(tools::md5sum(file.path(p, "M/2025/1_b6_a01.json.gz"))))
  r <- resumo_manifesto(m, p, commit = "abc", invalidos = 0L)
  expect_equal(r$arquivos_json_gz, 3)
  expect_equal(r$contagem_por_esfera_ano$M$`2025`, 2)
  expect_equal(r$coleta_fim, "2026-10-23T14:00:00Z")   # log antigo (hora local -03) convertido a UTC
})
