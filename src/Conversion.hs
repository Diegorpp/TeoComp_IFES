{-# LANGUAGE OverloadedStrings #-}
module Conversion
  ( epsilonClosure
  , nfaeToNfa
  , nfaToDfa
  ) where

import Data.Maybe      (fromMaybe)
import Data.Set        (Set)
import qualified Data.Map.Strict as Map
import qualified Data.Set        as Set
import qualified Data.Text       as T

import Types

-- | Computa o ε-fecho de um estado.
-- O ε-fecho é o conjunto de todos os estados alcançáveis a partir de s
-- usando apenas transições epsilon (incluindo o próprio s).
-- Implementado como BFS com worklist até ponto fixo.
epsilonClosure :: NFAe -> State -> Set State
epsilonClosure nfae s0 = go (Set.singleton s0) (Set.singleton s0)
  where
    go visited worklist
      | Set.null worklist = visited
      | otherwise =
          let reached =
                foldMap
                  (\s -> fromMaybe Set.empty $
                     Map.lookup (s, Epsilon) (nfaeTransitions nfae))
                  (Set.toList worklist)
              newStates = Set.difference reached visited
          in  go (Set.union visited newStates) newStates

-- | Converte NFAε em NFA eliminando transições epsilon.
--
-- Para cada estado s e símbolo concreto a:
--   δ_NFA(s, a) = ε-fecho( ∪ { δ_NFAε(t, a) | t ∈ ε-fecho(s) } )
--
-- Um estado s torna-se final se seu ε-fecho intersecta os finais originais.
nfaeToNfa :: NFAe -> NFA
nfaeToNfa nfae = NFA
  { nfaAlphabet    = nfaeAlphabet nfae
  , nfaStates      = nfaeStates nfae
  , nfaInitial     = nfaeInitial nfae
  , nfaFinals      = newFinals
  , nfaTransitions = newTrans
  }
  where
    closure  = epsilonClosure nfae
    alphabet = nfaeAlphabet nfae
    states   = nfaeStates nfae

    -- Estados alcançáveis pelo símbolo a a partir de qualquer estado em ε-fecho(s)
    move s a =
      foldMap
        (\t -> fromMaybe Set.empty $
           Map.lookup (t, Symbol a) (nfaeTransitions nfae))
        (Set.toList (closure s))

    -- δ_NFA(s, a): move em a e fecha sob ε
    newTarget s a = foldMap closure (Set.toList (move s a))

    newTrans = Map.fromList
      [ ((s, a), tgt)
      | s <- states
      , a <- alphabet
      , let tgt = newTarget s a
      , not (Set.null tgt)
      ]

    newFinals =
      Set.filter
        (\s -> not $ Set.null $
           Set.intersection (closure s) (nfaeFinals nfae))
        (Set.fromList states)

-- | Codifica um conjunto de estados NFA como nome de estado do DFA.
-- Exemplo: {"q0","q1"} → "{q0,q1}"
setName :: Set State -> State
setName ss
  | Set.null ss = "{}"
  | otherwise   = "{" <> T.intercalate "," (Set.toAscList ss) <> "}"

-- | Converte NFA em DFA pela construção de subconjuntos (powerset construction).
--
-- Os estados do DFA são subconjuntos alcançáveis dos estados do NFA.
-- Apenas subconjuntos não-vazios alcançáveis são criados
-- (estados mortos são omitidos).
nfaToDfa :: NFA -> DFA
nfaToDfa nfa = DFA
  { dfaAlphabet    = alphabet
  , dfaStates      = map setName (Set.toList allSets)
  , dfaInitial     = setName initSet
  , dfaFinals      = Set.map setName finalSets
  , dfaTransitions = dfaTrans
  }
  where
    alphabet = nfaAlphabet nfa
    initSet  = Set.singleton (nfaInitial nfa)

    -- δ_DFA(S, a) = ∪ { δ_NFA(s, a) | s ∈ S }
    move ss a =
      foldMap
        (\s -> fromMaybe Set.empty $
           Map.lookup (s, a) (nfaTransitions nfa))
        (Set.toList ss)

    -- BFS sobre subconjuntos alcançáveis
    (allSets, dfaTrans) =
      explore (Set.singleton initSet) (Set.singleton initSet) Map.empty

    explore visited worklist trans
      | Set.null worklist = (visited, trans)
      | otherwise =
          let ss      = Set.findMin worklist
              rest    = Set.deleteMin worklist
              targets = [(a, move ss a) | a <- alphabet, not (Set.null (move ss a))]
              entries = [((setName ss, a), setName tgt) | (a, tgt) <- targets]
              newSets =
                Set.fromList
                  [tgt | (_, tgt) <- targets, Set.notMember tgt visited]
              trans'  = foldr (uncurry Map.insert) trans entries
          in  explore
                (Set.union visited newSets)
                (Set.union rest newSets)
                trans'

    finalSets =
      Set.filter
        (\ss -> not $ Set.null $ Set.intersection ss (nfaFinals nfa))
        allSets
