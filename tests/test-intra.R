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

# ---- linha "intraorcamentarias nao alocadas" e identidade -------------------------------------------------------------------------------------
mk_intra <- function(conta, col, acum, ano = 2023L) mk(conta, col, acum, ano = ano)
rreo2 <- rbind(mk_intra("PessoalEEncargosSociaisIntra", "DESPESAS PAGAS ATÉ O BIMESTRE (j)", c(10, 25, 45)),
               mk_intra("OutrasDespesasCorrentesIntra", "DESPESAS PAGAS ATÉ O BIMESTRE (j)", c(1, 3, 6)),
               mk_intra("InvestimentosIntra", "DESPESAS PAGAS ATÉ O BIMESTRE (j)", c(0, 2, 2)),
               mk_intra("ReceitasIntraOrcamentariasTotal", "Até o Bimestre (c)", c(5, 12, 20)))
fl2 <- rbind(
  data.frame(cod_ibge = 11L, serie = rep(c("desp:pessoal", "desp:custeio", "desp:investimento", "desp:demais despesas de capital", "rec:ICMS", "rec:demais receitas"), each = 6),
             exercicio = rep(c(2022L, 2023L), each = 3, times = 6), periodo = rep(1:3, 12),
             valor = c(rep(100, 6), rep(50, 6), rep(20, 6), rep(5, 6), rep(300, 6), rep(40, 6))))

test_that("categorias + 'intra nao alocada' = total harmonizado, exatamente, em todos os anos", {
  f <- fluxo_intra(rreo2)
  fh <- harmonizar_fluxos(fl2, f)
  n <- fh[grepl("nao alocada", fh$serie), ]
  expect_true(all(n$valor <= 0))
  d23 <- n[n$serie == "desp:intra nao alocada" & n$exercicio == 2023L, ]
  expect_equal(d23$valor, -c(1 + 0, 2 + 2, 3 + 0))                                  # custeio (1,2,3) + investimento (0,2,0), em fluxo
  expect_true(all(n$valor[n$exercicio == 2022L] == 0)); expect_true(all(n$valor[n$serie == "rec:intra nao alocada"] == 0))
  ch <- checar_identidade_intra(fh, fl2, f)
  expect_lt(ch$max_abs, 1e-9)
  # pessoal sai da categoria; custeio e investimento ficam brutos
  expect_equal(fh$valor[fh$serie == "desp:pessoal" & fh$exercicio == 2023L], c(90, 85, 80)); expect_equal(fh$valor[fh$serie == "desp:custeio" & fh$exercicio == 2023L], rep(50, 3))
  # se uma categoria validada estiver ausente em algum bimestre, a identidade falha (nao passa em silencio)
  fl3 <- fl2[!(fl2$serie == "desp:pessoal" & fl2$exercicio == 2023L & fl2$periodo == 2L), ]
  expect_error(checar_identidade_intra(harmonizar_fluxos(fl3, f), fl3, f), "Identidade")
})
