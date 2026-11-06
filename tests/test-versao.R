library(testthat)
source_utf8("../R/utils_io.R"); source_utf8("../R/pipeline/rodada.R")
git_ok <- nzchar(Sys.which("git"))
novo <- function() { d <- tempfile("proj"); dir.create(d); normalizePath(d) }
git <- function(d, ...) system2("git", c("-C", shQuote(d), "-c", "user.email=t@t", "-c", "user.name=t", ...), stdout = TRUE, stderr = FALSE)

test_that("sem git: VERSAO com hash vale; literal, ausente ou invalido nao identificam", {
  d <- novo(); writeLines(strrep("ab12", 10), file.path(d, "VERSAO")); v <- versao_codigo(d, usar_git = FALSE)
  expect_equal(v$commit, "ab12ab1"); expect_equal(v$fonte, "VERSAO"); expect_false(v$sujo)
  writeLines("$Format:%H$", file.path(d, "VERSAO")); expect_true(is.na(versao_codigo(d, usar_git = FALSE)$commit))
  writeLines("xyz", file.path(d, "VERSAO")); expect_true(is.na(versao_codigo(d, usar_git = FALSE)$commit))
  file.remove(file.path(d, "VERSAO")); expect_true(is.na(versao_codigo(d, usar_git = FALSE)$commit))
})

test_that("com git: usa o commit, marca sujo e ignora repositorio de uma pasta acima", {
  skip_if(!git_ok)
  d <- novo(); git(d, "init", "-q"); dir.create(file.path(d, "R")); writeLines("x <- 1", file.path(d, "R", "a.R")); git(d, "add", "-A"); git(d, "commit", "-q", "-m", "m")
  v <- versao_codigo(d); expect_equal(v$fonte, "git"); expect_equal(v$commit, git(d, "rev-parse", "--short", "HEAD")); expect_false(v$sujo)
  writeLines("x <- 2", file.path(d, "R", "a.R")); expect_true(versao_codigo(d)$sujo)
  sub <- file.path(d, "pasta_extraida"); dir.create(sub); expect_true(is.na(versao_codigo(normalizePath(sub))$commit))    # zip extraido dentro de outro repo: nao herda o commit dele
})

test_that("git archive preenche o VERSAO (export-subst) e a rodada identifica o commit sem .git", {
  skip_if(!git_ok || !nzchar(Sys.which("tar")))
  d <- novo(); git(d, "init", "-q"); writeLines("$Format:%H$", file.path(d, "VERSAO")); writeLines("VERSAO export-subst", file.path(d, ".gitattributes")); git(d, "add", "-A"); git(d, "commit", "-q", "-m", "m")
  z <- tempfile(fileext = ".tar"); git(d, "archive", "-o", shQuote(z), "HEAD"); e <- novo(); system2("tar", c("-xf", shQuote(z), "-C", shQuote(e)))
  v <- versao_codigo(e); expect_equal(v$fonte, "VERSAO"); expect_equal(v$commit, substr(git(d, "rev-parse", "HEAD"), 1, 7))
})

test_that("--oficial recusa sem commit identificado; teste e commit identificado passam", {
  sem <- list(commit = NA_character_, fonte = NA_character_, sujo = FALSE); com <- list(commit = "abc1234", fonte = "git", sujo = FALSE)
  expect_match(recusa_sem_commit(sem, TRUE), "--oficial exige identificar o commit"); expect_null(recusa_sem_commit(sem, FALSE)); expect_null(recusa_sem_commit(com, TRUE))
})
