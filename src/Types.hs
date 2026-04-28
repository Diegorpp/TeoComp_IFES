module Types
  ( State
  , Symbol(..)
  , NFAe(..)
  , NFA(..)
  , DFA(..)
  ) where

import Data.Map.Strict (Map)
import Data.Set        (Set)
import Data.Text       (Text)

-- | Identificador de um estado do autômato.
type State = Text

-- | Símbolo de transição: concreto ou epsilon.
-- Usar um ADT (em vez de Text puro) impede que ε apareça
-- estaticamente nas transições de NFA e DFA.
data Symbol = Symbol Text | Epsilon
  deriving (Show, Eq, Ord)

-- | NFAε: aceita transições epsilon e múltiplos destinos por movimento.
data NFAe = NFAe
  { nfaeAlphabet    :: [Text]
  , nfaeStates      :: [State]
  , nfaeInitial     :: State
  , nfaeFinals      :: Set State
  , nfaeTransitions :: Map (State, Symbol) (Set State)
  } deriving (Show, Eq)

-- | NFA: sem transições epsilon, ainda não-determinístico.
data NFA = NFA
  { nfaAlphabet    :: [Text]
  , nfaStates      :: [State]
  , nfaInitial     :: State
  , nfaFinals      :: Set State
  , nfaTransitions :: Map (State, Text) (Set State)
  } deriving (Show, Eq)

-- | DFA: determinístico — cada (estado, símbolo) mapeia para exatamente um estado.
data DFA = DFA
  { dfaAlphabet    :: [Text]
  , dfaStates      :: [State]
  , dfaInitial     :: State
  , dfaFinals      :: Set State
  , dfaTransitions :: Map (State, Text) State
  } deriving (Show, Eq)
