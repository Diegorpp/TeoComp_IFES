# Haskell

## Caracteristicas

Funções puramente matematicas
Dados são imutaveis
Nenhum ou pouco "side-effect"
Declarativo

Possui processamento "Lazy": Só executa quando necessário

## Funções

name arg1 arg2 ... argn = <expr>

## types

name :: <type>

## Let bindings and Where

Let vc define primeiro e põe a expressão final depois, o Where voce põe a expressão final no inicio e depois declara os elementos.

Exemplo:

```haskell
in_range min max x =
    let in_lower_bound = min <= x
        in_upper_bound = max >= x
    in
    in_lower_bound && in_upper_bound

in_range_w min max x = ilb && iub
    where
        ilb = min <= x
        iub = max >= x
```

## If Statement

```haskell
in_range min max x = 
    if ilb then uib else False
    where
        ilb = min <= x
        iub = max >= x
```

## infix functions

```haskell
ghci> :t (+)
(+) :: Num a => a -> a -> a

-- Exemplo
add a b = a+b
add 10 20
-- Equivalente à
10 `add` 20
```

## Recursão

```haskell
fac n =
    if n <= 1 then
        1
    else
        n * fac (n-1)
```

## Guards

Pode ter varias | até enjoar

```haskell
fac n
    | n <= 1    = 1
    | otherwise = n * fac (n-1)
```

## Pattern Matching

A primeria definição cobre um caso a segunda cobre os demais casos. "_" é uma wildcard.

```haskell
is_zero 0 = True
is_zero _ = False
```

## Accumulators

```haskell
fac n = aux n 1
    where
        aux n acc
            | n <= 1    = acc
            | otherwise = aux (n-1) (n*acc)
```

## Lists
Só possui um unico elemento interno.

Lista podem ser construidas por construtores como x:xs

import Data.List -> Modulo para operações a mais com listas.

Funções uteis dentro do haskell
- head: Pega o primeiro elemento de uma lista
    Retorna um elemento
- tail: Pega o restando de uma lista, sem o primeiro elemento
    Retonar uma lista
- length: Retorna o tamanho da lista
- init: retorna uma copia da lista sem o ultimo elemento da lista
- null: Verifica se a lista está vazia

- and: Operador "e" logico -> Trabalha com os operadores direto em uma lista
- or: Operador "ou" logico ->  Trabalha com os operadores direto em uma lista

```haskell
-- Sintax
[1,5,3,123] :: [Integer]
1 : 5 : 3 : 123 : []

-- Example generating lists
asc :: Int -> Int -> [Int]
asc n m
    | m < n = []
    | m == n = [m]
    | otherwise = n: asc (n+1) m
```

## Compreensçao e lista

```haskell
[ (x,y) | x <- [1,2,3], y <- ['a','b']]

```

## Função anonima

(\x -> x+1) 1

Só precisa coloca o \ no inicio e definir a função, da pra atribuir ela a uma variavel tbm.



```haskell
```

```haskell
```