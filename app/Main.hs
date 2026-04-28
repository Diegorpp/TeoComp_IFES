module Main where

import Pipeline           (convertToDfa)
import System.Environment (getArgs)
import System.Exit        (exitFailure)
import YamlIO             (readAutomaton, writeDfa)

main :: IO ()
main = do
  args <- getArgs
  case args of
    [inputFile, outputFile] -> do
      result <- readAutomaton inputFile
      case result of
        Left err -> do
          putStrLn $ "Erro ao ler o arquivo: " ++ err
          exitFailure
        Right someAut -> do
          let dfa = convertToDfa someAut
          writeDfa outputFile dfa
          putStrLn $ "Convertido com sucesso → " ++ outputFile
    _ -> do
      putStrLn "Uso: cabal run automata-converter -- <entrada.yaml> <saida.yaml>"
      exitFailure
