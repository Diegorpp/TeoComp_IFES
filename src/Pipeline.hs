module Pipeline
  ( convertToDfa
  ) where

import Conversion (nfaeToNfa, nfaToDfa)
import Types
import YamlIO     (SomeAutomaton(..))

-- | Converte qualquer tipo de autômato para DFA.
--
-- NFAε passa pelas duas etapas de conversão (nfaeToNfa >=> nfaToDfa).
-- NFA passa apenas pela construção de subconjuntos.
-- DFA é retornado sem alteração.
convertToDfa :: SomeAutomaton -> DFA
convertToDfa (ANfae nfae) = nfaToDfa (nfaeToNfa nfae)
convertToDfa (ANfa  nfa)  = nfaToDfa nfa
convertToDfa (ADfa  dfa)  = dfa
