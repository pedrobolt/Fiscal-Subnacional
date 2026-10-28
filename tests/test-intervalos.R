library(testthat)
source("../R/evaluation/torneio.R")
source("../R/evaluation/intervalos.R")

test_that("suavização 1-2-1 com extremos refletidos: constante não muda; pico é espalhado", {
  expect_equal(suavizar_121(rep(5, 6)), rep(5, 6))
  v <- c(0, 0, 8, 0, 0)
  expect_equal(suavizar_121(v), c(0, 2, 4, 2, 0))
  expect_equal(suavizar_121(c(4, 0, 0, 0)), c((0 + 8 + 0) / 4, 1, 0, 0))   # v[0] = v[2] = 0
  expect_equal(suavizar_121(c(0, 0, 0, 4)), c(0, 0, 1, (0 + 8 + 0) / 4))   # v[n+1] = v[n-1] = 0
})

test_that("isotônica não crescente: resultado monótono, igual ao dado se já monótono, média nos blocos violados", {
  expect_equal(isotonica_nao_crescente(c(9, 7, 4, 1)), c(9, 7, 4, 1))
  r <- isotonica_nao_crescente(c(5, 2, 6, 1)); expect_true(all(diff(r) <= 1e-12)); expect_equal(r, c(5, 4, 4, 1))
  expect_equal(sum(isotonica_nao_crescente(c(1, 3, 2))), 6)
})

erros_sint <- function(anos = 2000:2025, cortes = 1:11, semente = 4) {
  set.seed(semente); d <- expand.grid(ano = anos, corte = cortes)
  d$erro <- stats::rnorm(nrow(d), 0, 10 - 0.6 * d$corte); d$previsao <- 100; d$realizado <- d$previsao - d$erro; d
}

test_that("σ rolante usa só anos < alvo: alterar erros do alvo e posteriores não muda σ; sem histórico suficiente, NA", {
  e <- erros_sint(); s1 <- sigma_publicado(e, 2015)
  e2 <- e; e2$erro[e2$ano >= 2015] <- e2$erro[e2$ano >= 2015] * 100
  expect_equal(sigma_publicado(e2, 2015), s1)
  expect_true(all(is.na(sigma_publicado(e, 2005))))                      # só 5 anos de erro (2000–2004) < 8
  expect_false(anyNA(sigma_publicado(e, 2008)))                           # 8 anos: 2000–2007
  expect_true(all(diff(s1) <= 1e-12))                                     # não cresce com o corte
})

test_that("excluir 2020–22 muda σ; σ com pandemia é o pior caso quando os erros da pandemia são maiores", {
  e <- erros_sint(); e$erro[e$ano %in% 2020:2022] <- e$erro[e$ano %in% 2020:2022] * 5
  expect_true(all(sigma_publicado(e, 2024) >= sigma_publicado(e, 2024, excluir = 2020:2022)))
  expect_gt(sigma_publicado(e, 2024)[1], sigma_publicado(e, 2024, excluir = 2020:2022)[1])
})

test_that("intervalo 80%: ±1,2816σ; cobertura de erros normais com σ correto fica perto de 80%", {
  expect_equal(Z80, 1.2815516, tolerance = 1e-6)
  iv <- intervalo_80(100, 10); expect_equal(c(iv$inf, iv$sup), 100 + c(-1, 1) * Z80 * 10)
  set.seed(1); e <- erros_sint(anos = 2000:2300, semente = 1)               # amostra grande para a cobertura
  r <- intervalos_backtest(e, 2100:2300)
  expect_equal(mean(r$dentro_com), 0.8, tolerance = 0.03)
})

test_that("Wilson 90%: 8/10 a 90%: centro e semi-amplitude calculados à mão (0,7361 ± 0,1953)", {
  w <- wilson(8, 10); expect_equal(unname(w), c(0.5408, 0.9314), tolerance = 1e-3)
  expect_equal(unname(wilson(0, 10)[1]), 0, tolerance = 1e-9); expect_true(is.na(wilson(0, 0)[1]))
})

test_that("cobertura por faixa: n = pares e n = anos; 80% dentro do Wilson quando a cobertura observada é 80%", {
  iv <- expand.grid(ano = 2008:2027, corte = 1:11); iv$dentro_com <- (iv$ano %% 5) != 0
  c <- cobertura_faixas(iv, "dentro_com")
  expect_equal(nrow(c), 3); expect_true(all(c$contem_80)); expect_equal(c$cobertura, rep(0.8, 3))
  expect_equal(c$pares, c(80, 80, 60)); expect_equal(c$anos, rep(20, 3))
})

test_that("escala em % do PIB: com PIB constante coincide com R$; com PIB crescente o σ acompanha o PIB do alvo", {
  e <- erros_sint(); e$pib <- 1000
  a <- intervalos_backtest(e, 2010:2020); b <- intervalos_backtest(e, 2010:2020, escala = "pib")
  expect_equal(b$sigma_com, a$sigma_com); expect_equal(b$dentro_com, a$dentro_com)
  e2 <- erros_sint(); e2$pib <- 1000 * 1.1^(e2$ano - 2000); e2$erro <- e2$erro * e2$pib / 1000   # erro proporcional ao PIB
  e2$previsao <- 100; e2$realizado <- e2$previsao - e2$erro
  p <- intervalos_backtest(e2, 2010:2020, escala = "pib")
  # identidade: σ publicado = σ dos erros em fração do PIB x PIB do alvo
  ep <- e2; ep$erro <- e2$erro / e2$pib
  for (t in c(2012, 2018)) {
    esperado <- sigma_publicado(ep, t) * e2$pib[e2$ano == t & e2$corte == 1]
    expect_equal(p$sigma_com[p$ano == t], esperado)
  }
  # com erro crescendo com o PIB, o σ em % do PIB é maior que o σ em R$ (que defasa o crescimento) nos anos finais
  rb <- intervalos_backtest(e2, 2015:2020)
  expect_gt(mean(p$sigma_com[p$ano >= 2015] / rb$sigma_com[match(paste(p$ano, p$corte)[p$ano >= 2015], paste(rb$ano, rb$corte))]), 1)
})

test_that("σ em % do PIB só usa erros de anos anteriores ao alvo", {
  e <- erros_sint(); e$pib <- 1000 * 1.1^(e$ano - 2000)
  a <- intervalos_backtest(e, 2015, escala = "pib")
  e2 <- e; k <- e2$ano >= 2015; e2$erro[k] <- e2$erro[k] * 50; e2$pib[e2$ano > 2015] <- e2$pib[e2$ano > 2015] * 9
  b <- intervalos_backtest(e2, 2015, escala = "pib")
  expect_equal(a$sigma_com, b$sigma_com)
})

test_that("texto de divulgação: 80% só se o Wilson por ano contém 80%; senão cobertura empírica", {
  cob <- data.frame(faixa = c("1-4", "5-8"), contem_80_anos = c(TRUE, FALSE), cobertura_anos = c(0.8, 0.55), anos = 18)
  t <- texto_divulgacao(cob)
  expect_equal(t$texto[1], "Intervalo de 80%"); expect_equal(t$texto[2], "Contém o resultado em 55% dos anos-alvo (n = 18)")
})
