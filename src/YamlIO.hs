{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}

module YamlIO
  ( SomeAutomaton(..)
  , readAutomaton
  , writeDfa
  , writeNfa
  ) where

import Data.Aeson       (FromJSON(..), ToJSON(..), Value(..), withObject,
                         genericToJSON, defaultOptions, Options(..), (.:))
import Data.Aeson.Types (Parser, typeMismatch)
import Data.Char        (isUpper, toLower)
import Data.Scientific  (floatingOrInteger)
import Data.Text        (Text)
import Data.Yaml        (decodeFileEither, encodeFile, prettyPrintParseException)
import GHC.Generics     (Generic)
import qualified Data.Map.Strict as Map
import qualified Data.Set        as Set
import qualified Data.Text       as T

import Types

-- ---------------------------------------------------------------
-- Registros intermediários que espelham a estrutura YAML exata
-- ---------------------------------------------------------------

data RawTransition = RawTransition
  { rtFrom   :: Text
  , rtSymbol :: Text
  , rtTo     :: [Text]
  } deriving (Show, Generic)

data RawAutomaton = RawAutomaton
  { raType         :: Text
  , raAlphabet     :: [Text]
  , raStates       :: [Text]
  , raInitialState :: Text
  , raFinalStates  :: [Text]
  , raTransitions  :: [RawTransition]
  } deriving (Show, Generic)

-- Aceita tanto String quanto Number como Text.
-- Necessário porque YAML interpreta '0' e '1' sem aspas como inteiros.
parseText :: Value -> Parser Text
parseText (String t) = pure t
parseText (Number n) = pure $ case (floatingOrInteger n :: Either Double Integer) of
  Right i -> T.pack (show i)
  Left  d -> T.pack (show d)
parseText v = typeMismatch "String or Number" v

instance FromJSON RawTransition where
  parseJSON = withObject "RawTransition" $ \o ->
    RawTransition
      <$> (o .: "from"   >>= parseText)
      <*> (o .: "symbol" >>= parseText)
      <*> (o .: "to"     >>= mapM parseText)

instance FromJSON RawAutomaton where
  parseJSON = withObject "RawAutomaton" $ \o ->
    RawAutomaton
      <$> (o .: "type"          >>= parseText)
      <*> (o .: "alphabet"      >>= mapM parseText)
      <*> (o .: "states"        >>= mapM parseText)
      <*> (o .: "initial_state" >>= parseText)
      <*> (o .: "final_states"  >>= mapM parseText)
      <*>  o .: "transitions"

-- Converte camelCase para snake_case após remover o prefixo do record.
-- Exemplo: "InitialState" → "initial_state"
camelToSnake :: String -> String
camelToSnake []     = []
camelToSnake (c:cs) = toLower c : go cs
  where
    go []     = []
    go (x:xs)
      | isUpper x = '_' : toLower x : go xs
      | otherwise =           x    : go xs

raOptions :: Options
raOptions = defaultOptions { fieldLabelModifier = camelToSnake . drop 2 }

rtOptions :: Options
rtOptions = defaultOptions { fieldLabelModifier = camelToSnake . drop 2 }

instance ToJSON RawTransition where toJSON = genericToJSON rtOptions
instance ToJSON RawAutomaton  where toJSON = genericToJSON raOptions

-- ---------------------------------------------------------------
-- Tipo de despacho
-- ---------------------------------------------------------------

-- | Autômato lido do YAML sem conversão prévia.
data SomeAutomaton = ADfa DFA | ANfa NFA | ANfae NFAe

-- ---------------------------------------------------------------
-- Construção das estruturas internas a partir do raw
-- ---------------------------------------------------------------

toSymbol :: Text -> Symbol
toSymbol "epsilon" = Epsilon
toSymbol t         = Symbol t

rawToNfae :: RawAutomaton -> NFAe
rawToNfae ra = NFAe
  { nfaeAlphabet    = raAlphabet ra
  , nfaeStates      = raStates ra
  , nfaeInitial     = raInitialState ra
  , nfaeFinals      = Set.fromList (raFinalStates ra)
  , nfaeTransitions =
      foldr
        (\rt m -> Map.insertWith Set.union
            (rtFrom rt, toSymbol (rtSymbol rt))
            (Set.fromList (rtTo rt)) m)
        Map.empty
        (raTransitions ra)
  }

rawToNfa :: RawAutomaton -> NFA
rawToNfa ra = NFA
  { nfaAlphabet    = raAlphabet ra
  , nfaStates      = raStates ra
  , nfaInitial     = raInitialState ra
  , nfaFinals      = Set.fromList (raFinalStates ra)
  , nfaTransitions =
      foldr
        (\rt m ->
          if rtSymbol rt == "epsilon"
            then m  -- ignora epsilon em arquivos declarados como NFA
            else Map.insertWith Set.union
                   (rtFrom rt, rtSymbol rt)
                   (Set.fromList (rtTo rt)) m)
        Map.empty
        (raTransitions ra)
  }

rawToDfa :: RawAutomaton -> DFA
rawToDfa ra = DFA
  { dfaAlphabet    = raAlphabet ra
  , dfaStates      = raStates ra
  , dfaInitial     = raInitialState ra
  , dfaFinals      = Set.fromList (raFinalStates ra)
  , dfaTransitions =
      foldr
        (\rt m -> case rtTo rt of
            (t:_) -> Map.insert (rtFrom rt, rtSymbol rt) t m
            []    -> m)
        Map.empty
        (raTransitions ra)
  }

-- ---------------------------------------------------------------
-- Serialização de volta para raw
-- ---------------------------------------------------------------

dfaToRaw :: DFA -> RawAutomaton
dfaToRaw dfa = RawAutomaton
  { raType         = "dfa"
  , raAlphabet     = dfaAlphabet dfa
  , raStates       = dfaStates dfa
  , raInitialState = dfaInitial dfa
  , raFinalStates  = Set.toAscList (dfaFinals dfa)
  , raTransitions  =
      [ RawTransition from sym [to]
      | ((from, sym), to) <- Map.toAscList (dfaTransitions dfa)
      ]
  }

nfaToRaw :: NFA -> RawAutomaton
nfaToRaw nfa = RawAutomaton
  { raType         = "nfa"
  , raAlphabet     = nfaAlphabet nfa
  , raStates       = nfaStates nfa
  , raInitialState = nfaInitial nfa
  , raFinalStates  = Set.toAscList (nfaFinals nfa)
  , raTransitions  =
      [ RawTransition from sym (Set.toAscList tos)
      | ((from, sym), tos) <- Map.toAscList (nfaTransitions nfa)
      ]
  }

-- ---------------------------------------------------------------
-- API pública
-- ---------------------------------------------------------------

-- | Lê um arquivo YAML e retorna o autômato tipado.
-- O campo `type` é normalizado para minúsculas antes do despacho.
readAutomaton :: FilePath -> IO (Either String SomeAutomaton)
readAutomaton path = do
  result <- decodeFileEither path
  return $ case result of
    Left err  -> Left (prettyPrintParseException err)
    Right raw ->
      case T.toLower (T.strip (raType raw)) of
        "dfa"  -> Right (ADfa  (rawToDfa  raw))
        "nfa"  -> Right (ANfa  (rawToNfa  raw))
        "nfae" -> Right (ANfae (rawToNfae raw))
        other  -> Left $ "Tipo de autômato desconhecido: " ++ T.unpack other

-- | Escreve um DFA em formato YAML.
writeDfa :: FilePath -> DFA -> IO ()
writeDfa path = encodeFile path . dfaToRaw

-- | Escreve um NFA em formato YAML.
writeNfa :: FilePath -> NFA -> IO ()
writeNfa path = encodeFile path . nfaToRaw
