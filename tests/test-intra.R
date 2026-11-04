library(testthat)
source_utf8("../R/transform/dicionario_contas.R")
source_utf8("../R/transform/intra.R")

mk <- function(conta, col, valores, uf = 11L, ano = 2023L) data.frame(anexo = "RREO-Anexo 01", cod_ibge = uf, exercicio = ano, periodo = seq_along(valores),
                                                                 cod_conta = conta, coluna = col, valor = valores, stringsAsFactors = FALSE)
rreo <- rbind(mk("PessoalEEncargosSociaisIntra", "DESPESAS PAGAS  ATÉ O BIMESTRE (j)", c(10, 25, 45)),       # espaco duplo no rotulo: normalizado
              mk("ReceitasIntraOrcamentariasTotal", "Até o Bimestre (c)", c(5, 12, 20)),
              mk("PessoalEEncargosSociaisIntra", "DESPESAS PAGAS ATÉ O BIMESTRE (j)", c(99), ano = 2022L),    # antes de 2023: ignorado
              mk("PessoalEEncargosSociaisIntra", "DESPESAS EMPENHADAS ATÉ O BIMESTRE (f)", c(1000, 2000, 3000)))  # outra coluna: ignorada

test_that("fluxo_intra converte o acumulado em fluxo e ignora outros anos e colunas", {
  f <- fluxo_intra(rreo)
  p <- f[f$serie == "desp:pessoal", ]
  expect_equal(p$fluxo, c(10, 15, 20)); expect_true(all(p$exercicio == 2023))
  expect_equal(f$fluxo[f$serie == "rec:demais receitas"], c(5, 7, 8)); expect_equal(unique(f$lado[f$serie == "rec:demais receitas"]), "rec")
})

test_that("harmonizar_intra retira a intra so das series validadas e guarda o bruto", {
  f <- fluxo_intra(rreo)
  fl <- data.frame(cod_ibge = 11L, serie = rep(c("desp:pessoal", "desp:custeio", "rec:demais receitas"), each = 3), exercicio = 2023L, periodo = 1:3, valor = c(100, 100, 100, 50, 50, 50, 30, 30, 30))
  h <- harmonizar_intra(fl, f)
  expect_equal(h$valor[h$serie == "desp:pessoal"], c(90, 85, 80)); expect_equal(h$valor_bruto[h$serie == "desp:pessoal"], rep(100, 3))
  expect_equal(h$valor[h$serie == "rec:demais receitas"], c(25, 23, 22))
  expect_equal(h$valor[h$serie == "desp:custeio"], rep(50, 3))                       # nao validada: intacta
  expect_equal(h$valor[h$serie == "desp:pessoal"][1], 90)
  fl2 <- fl; fl2$exercicio <- 2022L; expect_equal(harmonizar_intra(fl2, f)$valor, fl2$valor)   # 2022: sem retirada
})

test_that("total_harmonizado retira toda a intra do lado", {
  f <- fluxo_intra(rreo)
  fl <- data.frame(cod_ibge = 11L, serie = rep(c("desp:pessoal", "desp:custeio"), each = 3), exercicio = 2023L, periodo = 1:3, valor = c(100, 100, 100, 50, 50, 50))
  t <- total_harmonizado(fl, f, "desp")
  expect_equal(t$bruto, c(150, 150, 150)); expect_equal(t$intra, c(10, 15, 20)); expect_equal(t$harmonizado, c(140, 135, 130))
})
