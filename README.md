# Conversor de Autômatos — PPComp/Ifes 2026.1

Projeto de Teoria da Computação que implementa a conversão entre tipos de autômatos finitos em Haskell:

- **NFAe → NFA**: elimina transições epsilon usando o algoritmo de ε-fecho
- **NFA → DFA**: aplica a construção de subconjuntos (powerset construction)
- **DFA**: passado sem alteração

A entrada e saída são arquivos YAML. O programa lê o autômato, identifica o tipo pelo campo `type`, executa as conversões necessárias e grava o DFA resultante.

---

## Como executar

```bash
# 1. Entrar no ambiente Nix (fornece GHC, Cabal, etc.)
nix-shell

# 2. Compilar
cabal build

# 3. Executar o conversor
cabal run automata-converter -- <entrada.yaml> <saida.yaml>

# Exemplo com os arquivos do projeto:
cabal run automata-converter -- Docs/entrada_nfae1.yaml saida.yaml
```

### REPL interativo (para explorar as estruturas)

```bash
nix-shell --run "cabal repl --repl-options='-XOverloadedStrings'"
# Dentro do REPL:
:load test/GHCiTests.hs
t1_epsilonClosure          -- testa o ε-fecho de q0
t5_fullPipeline            -- testa o pipeline completo NFAe -> DFA
```

---

## Estrutura do projeto

```
Lab01/
├── app/
│   └── Main.hs          -- ponto de entrada do executável
├── src/
│   ├── Types.hs         -- definição das estruturas de dados (NFAe, NFA, DFA)
│   ├── Conversion.hs    -- algoritmos de conversão (ε-fecho, subset construction)
│   ├── Pipeline.hs      -- orquestração: decide qual conversão aplicar
│   └── YamlIO.hs        -- leitura e escrita de arquivos YAML
├── test/
│   └── GHCiTests.hs     -- exemplos e testes para rodar no REPL
├── Docs/
│   ├── entrada_nfae1.yaml   -- exemplo NFAe de entrada
│   ├── entrada_nfa2.yaml    -- exemplo NFA de entrada
│   ├── entrada_dfa3.yaml    -- exemplo DFA de entrada (passado direto)
│   └── entrada_nfae4.yaml   -- edge case: símbolos numéricos sem aspas
└── automata-converter.cabal -- configuração do projeto Cabal
```

---

## Formato YAML de entrada

O arquivo YAML deve ter obrigatoriamente os campos abaixo. O campo `type` aceita `dfa`, `nfa` ou `nfae` (em qualquer capitalização).

```yaml
type: nfae
alphabet: ['0', '1']
states: [q0, q1, q2]
initial_state: q0
final_states: [q2]
transitions:
  - from: q0
    symbol: '0'
    to: [q0, q1]
  - from: q0
    symbol: epsilon      # epsilon só é válido em nfae
    to: [q1]
  - from: q1
    symbol: '1'
    to: [q2]
```

**Observação sobre números sem aspas:** YAML interpreta `0` e `1` sem aspas como inteiros. O programa trata esse caso automaticamente, então `symbol: 0` e `symbol: '0'` são equivalentes.

---

## Explicação dos arquivos fonte

### `automata-converter.cabal` — Configuração do projeto

O arquivo `.cabal` descreve como o projeto é compilado. Ele define duas coisas:

1. Uma **biblioteca** (`library`) com os módulos em `src/`: `Types`, `Conversion`, `Pipeline`, `YamlIO`.
2. Um **executável** (`executable`) com o ponto de entrada em `app/Main.hs`, que importa a biblioteca.

O bloco `common shared-deps` evita repetição: lista as dependências externas usadas por ambos.

```
base        -- biblioteca padrão do GHC (IO, String, etc.)
containers  -- estruturas Map e Set
text        -- tipo Text (strings UTF-8 eficientes)
yaml        -- parse e escrita de YAML
aeson       -- parse de JSON (yaml usa aeson internamente)
scientific  -- números de precisão arbitrária (usado para tratar 0/1 como Text)
```

A opção `ghc-options: -Wall` ativa todos os avisos do compilador, o que ajuda a encontrar código incompleto ou suspeito.

---

### `src/Types.hs` — Estruturas de dados

Define os três tipos de autômatos e os tipos auxiliares usados em todo o projeto.

```haskell
type State = Text
```
`type` cria um **apelido** (alias): `State` e `Text` são o mesmo tipo para o compilador. O apelido existe para tornar as assinaturas de funções mais legíveis — quando você vê `State`, sabe que aquele `Text` representa um estado do autômato.

```haskell
data Symbol = Symbol Text | Epsilon
  deriving (Show, Eq, Ord)
```
`data` cria um **tipo novo** com dois construtores alternativos:
- `Symbol Text` — símbolo concreto, como `Symbol "0"` ou `Symbol "a"`
- `Epsilon` — representa a transição vazia (ε)

O `deriving` instrui o compilador a gerar automaticamente três capacidades:
- `Show` — permite imprimir o valor (ex: no REPL)
- `Eq` — permite comparar com `==`
- `Ord` — permite ordenar e usar como chave de `Map` ou `Set`

O `Ord` é essencial porque as chaves do mapa de transições são pares `(State, Symbol)`.

```haskell
data NFAe = NFAe
  { nfaeAlphabet    :: [Text]
  , nfaeStates      :: [State]
  , nfaeInitial     :: State
  , nfaeFinals      :: Set State
  , nfaeTransitions :: Map (State, Symbol) (Set State)
  } deriving (Show, Eq)
```
A **record syntax** define um tipo produto (todos os campos existem simultaneamente). Cada campo ganha automaticamente uma função de acesso: `nfaeInitial meuNfae` retorna o estado inicial.

A função de transição `Map (State, Symbol) (Set State)` representa δ(estado, símbolo) = {conjunto de destinos}. Usar `Set` no valor captura o não-determinismo: um mesmo par (estado, símbolo) pode levar a múltiplos estados.

Comparação entre os três tipos:

| Tipo | Chave do Map | Valor do Map | Permite ε? |
|------|-------------|-------------|------------|
| `NFAe` | `(State, Symbol)` | `Set State` | Sim (`Symbol` inclui `Epsilon`) |
| `NFA`  | `(State, Text)` | `Set State` | Não |
| `DFA`  | `(State, Text)` | `State` | Não |

O `DFA` tem `State` (não `Set State`) no valor porque cada par (estado, símbolo) leva a **exatamente um** estado — essa é a definição de determinismo.

---

### `src/Conversion.hs` — Algoritmos de conversão

#### Importações

```haskell
import Data.Maybe (fromMaybe)
import qualified Data.Map.Strict as Map
import qualified Data.Set        as Set
import qualified Data.Text       as T
```

As importações `qualified` exigem o prefixo para chamar qualquer função do módulo: `Map.lookup`, `Set.empty`, `T.intercalate`. Isso evita colisão de nomes — `Map` e `Set` têm funções com os mesmos nomes (`null`, `member`, `toList`, etc.).

`fromMaybe padrão (Maybe a)` extrai o valor de um `Maybe` ou retorna o padrão se for `Nothing`. É equivalente a verificar "se existe, usa; se não, usa o padrão".

#### `epsilonClosure` — ε-fecho de um estado

O ε-fecho de um estado `s` é o conjunto de **todos os estados alcançáveis a partir de `s` usando apenas transições epsilon**, incluindo o próprio `s`.

```haskell
epsilonClosure :: NFAe -> State -> Set State
epsilonClosure nfae s0 = go (Set.singleton s0) (Set.singleton s0)
  where
    go visited worklist
      | Set.null worklist = visited
      | otherwise =
          let reached   = foldMap
                            (\s -> fromMaybe Set.empty $
                               Map.lookup (s, Epsilon) (nfaeTransitions nfae))
                            (Set.toList worklist)
              newStates = Set.difference reached visited
          in  go (Set.union visited newStates) newStates
```

A função usa **BFS com worklist**:
- `visited` acumula todos os estados já processados (o resultado final)
- `worklist` contém os estados descobertos mas ainda não expandidos
- A cada passo: para cada estado na worklist, busca os destinos por ε; descarta os já visitados; adiciona os novos à worklist e ao visited
- Para quando a worklist fica vazia (ponto fixo)

`foldMap f lista` aplica `f` a cada elemento e combina os resultados. Para `Set`, a combinação é a união. É equivalente a `Set.unions (map f lista)`.

#### `nfaeToNfa` — Remoção de transições epsilon

Para cada estado `s` e símbolo concreto `a`, a nova transição do NFA é calculada assim:

1. Calcula `ε-fecho(s)` — estados alcançáveis por ε a partir de `s`
2. Para cada estado `t` no ε-fecho, busca `δ(t, a)` no NFAe
3. Une todos os resultados → este é o conjunto `move(s, a)`
4. Calcula o ε-fecho de cada estado em `move(s, a)` e une tudo → este é `δ_NFA(s, a)`

Um estado `s` passa a ser **final no NFA** se o seu ε-fecho intersecta os estados finais do NFAe. Isso garante que estados que chegam a um estado final por ε também são finais.

```haskell
newTrans = Map.fromList
  [ ((s, a), tgt)
  | s <- states, a <- alphabet       -- para todo estado e todo símbolo
  , let tgt = newTarget s a
  , not (Set.null tgt)               -- omite transições para conjunto vazio
  ]
```

A **list comprehension** `[ expr | gerador, condição ]` é equivalente a um loop com filtro: gera pares `((estado, símbolo), destinos)` para todas as combinações válidas.

#### `nfaToDfa` — Construção de subconjuntos

Cada estado do DFA **é um subconjunto** dos estados do NFA. O estado inicial do DFA é `{q0}` (o singleton com o estado inicial do NFA).

```haskell
setName :: Set State -> State
setName ss = "{" <> T.intercalate "," (Set.toAscList ss) <> "}"
-- Set.fromList ["q0","q1"] → "{q0,q1}"
```

`T.intercalate "," lista` insere `","` entre os elementos da lista e concatena tudo. `<>` é o operador de concatenação de `Text`.

A construção explora os subconjuntos por **BFS**:

```haskell
explore visited worklist trans
  | Set.null worklist = (visited, trans)   -- acabou
  | otherwise =
      let ss      = Set.findMin worklist   -- pega um subconjunto para processar
          rest    = Set.deleteMin worklist
          targets = [(a, move ss a) | a <- alphabet, not (Set.null (move ss a))]
          -- para cada símbolo, calcula o subconjunto destino
          entries = [((setName ss, a), setName tgt) | (a, tgt) <- targets]
          -- converte para entradas do mapa do DFA
          newSets = [tgt | (_, tgt) <- targets, Set.notMember tgt visited]
          -- subconjuntos ainda não visitados
          trans'  = foldr (uncurry Map.insert) trans entries
          -- insere as novas transições no mapa
      in  explore (visited ∪ newSets) (rest ∪ newSets) trans'
```

`foldr (uncurry Map.insert) trans entries` percorre a lista `entries` da direita para a esquerda e insere cada par no mapa `trans`. `uncurry` converte `Map.insert :: k -> v -> Map k v` para aceitar um par `(k, v)` diretamente.

Subconjuntos que levam a conjunto vazio (estados mortos) são **omitidos** — o DFA gerado é parcial, sem lixo desnecessário.

---

### `src/Pipeline.hs` — Orquestração

```haskell
convertToDfa :: SomeAutomaton -> DFA
convertToDfa (ANfae nfae) = nfaToDfa (nfaeToNfa nfae)  -- NFAe: 2 passos
convertToDfa (ANfa  nfa)  = nfaToDfa nfa                -- NFA: 1 passo
convertToDfa (ADfa  dfa)  = dfa                          -- DFA: identidade
```

`SomeAutomaton` é um tipo soma — pode ser `ADfa`, `ANfa` ou `ANfae`. O **pattern matching** no construtor decide qual conversão aplicar. O compilador garante que todos os casos são cobertos.

---

### `src/YamlIO.hs` — Leitura e escrita YAML

#### Estruturas intermediárias (Raw)

O módulo define estruturas `RawTransition` e `RawAutomaton` que espelham **exatamente** o formato YAML. A ideia é separar o formato externo (YAML) das estruturas internas (`NFAe`, `NFA`, `DFA`).

O fluxo de leitura é: YAML → Raw → estrutura interna.
O fluxo de escrita é: estrutura interna → Raw → YAML.

#### Tratamento de números sem aspas

```haskell
parseText :: Value -> Parser Text
parseText (String t) = pure t
parseText (Number n) = pure $ case (floatingOrInteger n) of
  Right i -> T.pack (show i)   -- inteiro: 0 → "0"
  Left  d -> T.pack (show d)   -- decimal: 0.5 → "0.5"
parseText v = typeMismatch "String or Number" v
```

YAML sem aspas interpreta `0` e `1` como inteiros. Esta função trata ambos os casos, convertendo qualquer número para a representação textual equivalente.

#### Instâncias FromJSON

```haskell
instance FromJSON RawTransition where
  parseJSON = withObject "RawTransition" $ \o ->
    RawTransition
      <$> (o .: "from"   >>= parseText)
      <*> (o .: "symbol" >>= parseText)
      <*> (o .: "to"     >>= mapM parseText)
```

- `withObject` garante que o valor YAML é um objeto (não uma lista ou número)
- `o .: "from"` extrai o campo `"from"` do objeto, retornando um `Parser Value`
- `>>= parseText` encadeia o resultado com `parseText` via `Monad`
- `<$>` e `<*>` são operadores do `Applicative` que aplicam o construtor `RawTransition` dentro do contexto `Parser`

#### Conversão camelCase → snake_case

```haskell
camelToSnake "InitialState" = "initial_state"
```

Os campos do record Haskell usam camelCase (`raInitialState`), mas o YAML usa snake_case (`initial_state`). A função `camelToSnake` seguida de `drop 2` (remove o prefixo `ra` ou `rt`) faz essa conversão automaticamente na serialização.

#### `readAutomaton`

```haskell
readAutomaton :: FilePath -> IO (Either String SomeAutomaton)
```

O tipo de retorno `IO (Either String SomeAutomaton)` expressa dois níveis:
- `IO` — a função tem efeito colateral (lê um arquivo)
- `Either String SomeAutomaton` — pode falhar (`Left` com mensagem de erro) ou ter sucesso (`Right` com o autômato)

#### `writeDfa`

```haskell
writeDfa :: FilePath -> DFA -> IO ()
writeDfa path = encodeFile path . dfaToRaw
```

A composição de funções `f . g` cria uma nova função que aplica `g` primeiro e depois `f`. Aqui: converte `DFA` para `RawAutomaton` e depois escreve no arquivo. O `()` no retorno indica que a função só tem efeito colateral, sem valor útil de retorno.

---

### `app/Main.hs` — Ponto de entrada

```haskell
main :: IO ()
main = do
  args <- getArgs
  case args of
    [inputFile, outputFile] -> do
      result <- readAutomaton inputFile
      case result of
        Left err      -> putStrLn ("Erro: " ++ err) >> exitFailure
        Right someAut -> do
          let dfa = convertToDfa someAut
          writeDfa outputFile dfa
    _ -> putStrLn "Uso: ..." >> exitFailure
```

A `do`-notation é açúcar sintático para encadeamento monádico em `IO`. Cada linha com `<-` extrai um valor de dentro de `IO` — é equivalente ao `await` de linguagens assíncronas.

`let dfa = ...` dentro de `do` é um binding **puro** (sem `IO`) — apenas dá nome a um valor calculado.

`[inputFile, outputFile]` é pattern matching em lista: só casa se a lista tiver exatamente 2 elementos. O `_` é o curinga que captura qualquer outro caso.

---

## Exemplos de validação

Os arquivos de entrada estão em `Docs/`. Para rodar cada um:

```bash
nix-shell --run "cabal run automata-converter -- Docs/entrada_nfae1.yaml saida.yaml"
cat saida.yaml
```

### Exemplo 1 — NFAe que reconhece `0*1`

Entrada (`Docs/entrada_nfae1.yaml`): NFAe com ε-transição de q0 para q1.

Saída gerada:
```
estados:  {q0}, {q0,q1}, {q2}
inicial:  {q0}
finais:   {q2}
```

| Estado DFA | por `0` | por `1` |
|---|---|---|
| `{q0}` | `{q0,q1}` | `{q2}` |
| `{q0,q1}` | `{q0,q1}` | `{q2}` |
| `{q2}` | — (omitido) | — (omitido) |

- `{q0}` →`0`→ `{q0,q1}`: ε-fecho(q0) = {q0, q1}; ambos leem `0` e chegam em {q0, q1}; ε-fecho do resultado = {q0, q1}
- `{q0}` →`1`→ `{q2}`: ε-fecho(q0) inclui q1; q1 lê `1` e chega em q2
- Estados mortos omitidos (q2 não tem transições de saída)

### Exemplo 2 — NFA que reconhece strings terminadas em `ab`

Entrada (`Docs/entrada_nfa2.yaml`): NFA sobre {a, b} sem ε-transições.

Saída gerada:
```
estados:  {p0}, {p0,p1}, {p0,p2}
inicial:  {p0}
finais:   {p0,p2}
```

| Estado DFA | por `a` | por `b` |
|---|---|---|
| `{p0}` | `{p0,p1}` | `{p0}` |
| `{p0,p1}` | `{p0,p1}` | `{p0,p2}` |
| `{p0,p2}` | `{p0,p1}` | `{p0}` |

- `{p0,p1}` →`b`→ `{p0,p2}`: p0→b→{p0}, p1→b→{p2}, união = {p0, p2}
- `{p0,p2}` é final porque contém p2 (estado final do NFA)

### Exemplo 3 — DFA passado sem alteração

Entrada (`Docs/entrada_dfa3.yaml`): DFA que reconhece strings com número par de `1`s.

Saída idêntica à entrada — estados `even` e `odd` sem renomeação para `{...}`. Confirma que `convertToDfa (ADfa dfa) = dfa` funciona corretamente.

### Exemplo 4 — Edge case: símbolos numéricos sem aspas

Entrada (`Docs/entrada_nfae4.yaml`): NFAe com `symbol: 0` e `symbol: 1` sem aspas.

Saída gerada: DFA com estados `{q0}` e `{q1}`, confirmando que o `parseText` converteu os inteiros YAML para `Text` corretamente.

---

## Algoritmos de conversão

### Algoritmo 1: ε-fecho (epsilon closure)

**Objetivo:** dado um estado `s`, encontrar todos os estados alcançáveis usando apenas transições ε.

**Por que é necessário:** no NFAe, ao ler um símbolo `a` a partir de `s`, o autômato pode ter chegado em `s` via ε-transições, e pode sair de `s` por ε-transições antes de consumir `a`. O ε-fecho captura toda essa "mobilidade gratuita".

**Algoritmo (BFS):**

```
ε-fecho(s):
  visitados = {s}
  worklist  = {s}
  enquanto worklist não estiver vazia:
    para cada t em worklist:
      novos = δ(t, ε) \ visitados   (destinos por ε ainda não vistos)
    worklist  = novos
    visitados = visitados ∪ novos
  retorna visitados
```

**Exemplo:** no NFAe do Exemplo 1, com `q0 --ε--> q1`:
- Início: visitados = {q0}, worklist = {q0}
- Passo 1: δ(q0, ε) = {q1}; novos = {q1}; visitados = {q0, q1}, worklist = {q1}
- Passo 2: δ(q1, ε) = {}; novos = {}; worklist vazia
- Resultado: ε-fecho(q0) = {q0, q1}

---

### Algoritmo 2: NFAe → NFA (eliminação de ε-transições)

**Objetivo:** construir um NFA equivalente sem nenhuma transição ε.

**Ideia central:** a nova transição `δ_NFA(s, a)` deve capturar todos os estados que o NFAe alcançaria lendo `a` — incluindo os "saltos livres" por ε antes e depois.

**Fórmula:**

```
δ_NFA(s, a) = ε-fecho( ∪{ δ_NFAe(t, a) | t ∈ ε-fecho(s) } )
```

Passo a passo:
1. Calcule ε-fecho(s): estados acessíveis por ε a partir de `s`
2. Para cada estado `t` no ε-fecho, aplique `δ_NFAe(t, a)`: estados acessíveis por `a`
3. Una todos esses destinos
4. Calcule o ε-fecho do resultado: estados acessíveis por ε após consumir `a`

**Estados finais no NFA:**
Um estado `s` torna-se final no NFA se `ε-fecho(s)` contém algum estado final do NFAe. Isso garante que estados que chegam a um estado final "de graça" (por ε) também aceitem a entrada.

**Exemplo:** NFAe do Exemplo 1 — calculando `δ_NFA(q0, 1)`:
1. ε-fecho(q0) = {q0, q1}
2. δ_NFAe(q0, 1) = {} e δ_NFAe(q1, 1) = {q2}; união = {q2}
3. ε-fecho(q2) = {q2}
4. Resultado: `δ_NFA(q0, 1) = {q2}`

---

### Algoritmo 3: NFA → DFA (construção de subconjuntos)

**Objetivo:** construir um DFA equivalente ao NFA, onde cada estado do DFA representa um subconjunto dos estados do NFA.

**Ideia central:** o não-determinismo do NFA faz com que, após ler uma sequência de símbolos, o autômato possa estar em **vários estados ao mesmo tempo**. O DFA simula isso mantendo explicitamente o conjunto de estados possíveis como seu estado atual.

**Construção:**

```
subconjunto inicial: S0 = {q0}   (singleton com o estado inicial do NFA)

δ_DFA(S, a) = ∪{ δ_NFA(s, a) | s ∈ S }

estados finais do DFA: todos os subconjuntos S que contêm
                       pelo menos um estado final do NFA
```

**BFS sobre subconjuntos:**

```
visitados = {S0}
worklist  = {S0}
transições = {}

enquanto worklist não estiver vazia:
  S = primeiro elemento de worklist
  para cada símbolo a no alfabeto:
    T = δ_DFA(S, a)
    se T não for vazio:
      adiciona (S, a) → T às transições
      se T não estiver em visitados:
        adiciona T à worklist e aos visitados
```

**Nomeação dos estados:** cada subconjunto `{q0, q1}` vira o nome de estado `"{q0,q1}"` (string). Isso permite representar o DFA no mesmo formato de texto que os outros autômatos.

**Estados mortos omitidos:** se `δ_DFA(S, a)` for o conjunto vazio, a transição não é adicionada. O DFA resultante é parcial (sem estado-lixo explícito), o que mantém o resultado limpo.

**Exemplo completo — Exemplo 1 (NFAe → NFA → DFA):**

NFA após eliminar ε (resultado intermediário do Algoritmo 2):
```
δ_NFA(q0, 0) = {q0, q1}
δ_NFA(q0, 1) = {q2}
δ_NFA(q1, 1) = {q2}
```

Construção do DFA:

| Iteração | S processado | por `0` | por `1` | Novos subconjuntos |
|---|---|---|---|---|
| 1 | `{q0}` | `{q0,q1}` | `{q2}` | `{q0,q1}`, `{q2}` |
| 2 | `{q0,q1}` | `{q0,q1}` | `{q2}` | nenhum (já visitados) |
| 3 | `{q2}` | — | — | nenhum |

DFA final:
- Estados: `{q0}`, `{q0,q1}`, `{q2}`
- Inicial: `{q0}`
- Finais: `{q2}` (único subconjunto que contém q2)

**Complexidade:** no pior caso, um NFA com `n` estados gera `2^n` subconjuntos. Na prática, apenas os subconjuntos alcançáveis a partir do estado inicial são construídos, e o número tende a ser bem menor.

---

## Dúvidas

Abra uma issue ou consulte os arquivos em `Docs/` para mais exemplos.
