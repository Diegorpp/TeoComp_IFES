{-# LANGUAGE OverloadedStrings #-}
-- Testes interativos para GHCi
--
-- Como executar:
--   cabal repl --repl-options='-XOverloadedStrings'
--   :load test/GHCiTests.hs
--
-- Em seguida avalie cada expressão abaixo e compare com o resultado esperado.
module GHCiTests where

import qualified Data.Map.Strict as Map
import qualified Data.Set        as Set

import Conversion
import Types

-- ---------------------------------------------------------------
-- Fixture: NFAε do exemplo da especificação (README.md)
--
--   q0 --0--> {q0, q1}
--   q0 --ε--> {q1}
--   q1 --1--> {q2}
--   estados finais: {q2}
-- ---------------------------------------------------------------
exampleNfae :: NFAe
exampleNfae = NFAe
  { nfaeAlphabet    = ["0", "1"]
  , nfaeStates      = ["q0", "q1", "q2"]
  , nfaeInitial     = "q0"
  , nfaeFinals      = Set.fromList ["q2"]
  , nfaeTransitions = Map.fromList
      [ (("q0", Symbol "0"), Set.fromList ["q0", "q1"])
      , (("q0", Epsilon),    Set.fromList ["q1"])
      , (("q1", Symbol "1"), Set.fromList ["q2"])
      ]
  }

-- ---------------------------------------------------------------
-- Teste 1: ε-fecho de q0
--
-- q0 tem ε-transição para q1; q1 não tem ε-transições saindo.
-- Resultado esperado: fromList ["q0","q1"]
--
-- > t1_epsilonClosure
-- ---------------------------------------------------------------
t1_epsilonClosure :: Set.Set State
t1_epsilonClosure = epsilonClosure exampleNfae "q0"

-- ---------------------------------------------------------------
-- Teste 2: ε-fecho de q1
--
-- q1 não tem ε-transições saindo.
-- Resultado esperado: fromList ["q1"]
--
-- > t2_epsilonClosureQ1
-- ---------------------------------------------------------------
t2_epsilonClosureQ1 :: Set.Set State
t2_epsilonClosureQ1 = epsilonClosure exampleNfae "q1"

-- ---------------------------------------------------------------
-- Teste 3: NFAε → NFA (remoção de transições epsilon)
--
-- Como ε-fecho(q0) = {q0, q1} e q1 --1--> {q2},
-- q0 deve ganhar a transição (q0, "1") → {q2}.
--
-- > nfaFinals t3_nfaeToNfa
-- fromList ["q2"]
--
-- > Map.lookup ("q0","1") (nfaTransitions t3_nfaeToNfa)
-- Just (fromList ["q2"])
--
-- > Map.lookup ("q0","0") (nfaTransitions t3_nfaeToNfa)
-- Just (fromList ["q0","q1"])
-- ---------------------------------------------------------------
t3_nfaeToNfa :: NFA
t3_nfaeToNfa = nfaeToNfa exampleNfae

-- ---------------------------------------------------------------
-- Teste 4: NFA → DFA (construção de subconjuntos)
--
-- > dfaInitial t4_nfaToDfa
-- "{q0}"
--
-- > Set.member "{q2}" (dfaFinals t4_nfaToDfa)
-- True
--
-- > Map.lookup ("{q0}","1") (dfaTransitions t4_nfaToDfa)
-- Just "{q2}"
-- ---------------------------------------------------------------
t4_nfaToDfa :: DFA
t4_nfaToDfa = nfaToDfa t3_nfaeToNfa

-- ---------------------------------------------------------------
-- Teste 5: Pipeline completo NFAε → NFA → DFA
--
-- > dfaInitial t5_fullPipeline
-- "{q0}"
--
-- > length (dfaStates t5_fullPipeline)
-- 3   -- {q0}, {q0,q1}, {q2} (subconjuntos alcançáveis; {q1,q2} não é alcançável)
-- ---------------------------------------------------------------
t5_fullPipeline :: DFA
t5_fullPipeline = nfaToDfa (nfaeToNfa exampleNfae)

-- ---------------------------------------------------------------
-- Fixture 2: NFA simples sem ε (para testar subset construction isolada)
--
--   s0 --a--> {s0, s1}
--   s1 --b--> {s0}
--   estados finais: {s1}
-- ---------------------------------------------------------------
simpleNfa :: NFA
simpleNfa = NFA
  { nfaAlphabet    = ["a", "b"]
  , nfaStates      = ["s0", "s1"]
  , nfaInitial     = "s0"
  , nfaFinals      = Set.fromList ["s1"]
  , nfaTransitions = Map.fromList
      [ (("s0", "a"), Set.fromList ["s0", "s1"])
      , (("s1", "b"), Set.fromList ["s0"])
      ]
  }

-- ---------------------------------------------------------------
-- Teste 6: NFA puro → DFA
--
-- > dfaInitial t6_simpleDfa
-- "{s0}"
--
-- > Set.member "{s0,s1}" (dfaFinals t6_simpleDfa)
-- True
--
-- > Map.lookup ("{s0}","a") (dfaTransitions t6_simpleDfa)
-- Just "{s0,s1}"
-- ---------------------------------------------------------------
t6_simpleDfa :: DFA
t6_simpleDfa = nfaToDfa simpleNfa

-- ---------------------------------------------------------------
-- Sessão GHCi completa de referência
-- ---------------------------------------------------------------
-- Após ':load test/GHCiTests.hs', execute em sequência:
--
--   t1_epsilonClosure
--   t2_epsilonClosureQ1
--   nfaFinals t3_nfaeToNfa
--   Map.lookup ("q0","1") (nfaTransitions t3_nfaeToNfa)
--   Map.lookup ("q0","0") (nfaTransitions t3_nfaeToNfa)
--   dfaInitial t4_nfaToDfa
--   Set.member "{q2}" (dfaFinals t4_nfaToDfa)
--   Map.lookup ("{q0}","1") (dfaTransitions t4_nfaToDfa)
--   dfaInitial t5_fullPipeline
--   length (dfaStates t5_fullPipeline)
--   dfaInitial t6_simpleDfa
--   Set.member "{s0,s1}" (dfaFinals t6_simpleDfa)
