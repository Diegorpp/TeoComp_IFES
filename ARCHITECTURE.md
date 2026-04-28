# Arquitetura e Decisões de Design

Este documento justifica as decisões tomadas na construção do conversor de autômatos.

---

## 1. Por que Haskell?

A Teoria da Computação trabalha com estruturas matemáticas (conjuntos, funções, fixpoints). Haskell oferece:

- **Tipos algébricos (ADTs)**: representam exatamente o domínio sem estados inválidos.
- **Imutabilidade por padrão**: as conversões são funções puras — dado o mesmo autômato de entrada, o resultado é sempre idêntico.
- **Funções de ordem superior e composição**: a pipeline `nfaeToNfa >=> nfaToDfa` expressa diretamente a composição matemática das conversões.

---

## 2. Três Tipos Distintos vs. Um Tipo Parametrizado

**Decisão:** `NFAe`, `NFA` e `DFA` são tipos separados.

**Alternativa rejeitada:** Um único `data Automaton kind = ...` parametrizado por phantom type.

**Motivo:** Com tipos distintos, a assinatura `nfaeToNfa :: NFAe -> NFA` torna impossível chamar a função com um `DFA`. O compilador detecta erros de pipeline na hora da compilação, não em runtime. O custo é alguma repetição estrutural, aceitável dada a escala do projeto.

---

## 3. Representação das Transições

**NFAe:** `Map (State, Symbol) (Set State)`  
**NFA:**  `Map (State, Text) (Set State)`  
**DFA:**  `Map (State, Text) State`

- `Data.Map.Strict` oferece lookup O(log n), adequado para autômatos acadêmicos.
- A versão `Strict` evita thunks acumulados (importante no BFS da construção de subconjuntos).
- `Set State` como valor representa naturalmente o não-determinismo; o DFA usa `State` diretamente para expressar o determinismo.

---

## 4. ADT `Symbol = Symbol Text | Epsilon`

**Motivo:** Impede estaticamente que transições epsilon apareçam no `NFA` ou `DFA`. O campo `nfaTransitions :: Map (State, Text) ...` não aceita o construtor `Epsilon` — qualquer tentativa é um erro de compilação.

**Alternativa rejeitada:** Representar epsilon como `Text "epsilon"`. Isso funcionaria em runtime mas não daria nenhuma garantia estática.

---

## 5. Biblioteca YAML: `yaml` + `aeson`

- **`yaml` (v0.11+)**: wrapper Haskell sobre `libyaml` (biblioteca C), eficiente e madura. Provê `decodeFileEither` e `encodeFile`.
- **`aeson` (v2.1+)**: define `FromJSON`/`ToJSON`. O pacote `yaml` usa `aeson` internamente; os tipos YAML são serializados/desserializados via instâncias `FromJSON`/`ToJSON`.
- **`GHC.Generics`**: `genericParseJSON` e `genericToJSON` com `fieldLabelModifier` derivam automaticamente as instâncias, mapeando nomes de campo Haskell (`raInitialState`) para o formato YAML (`initial_state`) via a função `camelToSnake . drop 2`.

Por que dois registros intermediários (`RawTransition`, `RawAutomaton`)?  
Os tipos internos (`NFAe`, `NFA`, `DFA`) usam estruturas eficientes (`Map`, `Set`) que não serializam bem diretamente para YAML. Os registros raw espelham a estrutura plana do arquivo e servem de camada de tradução.

---

## 6. Normalização do Campo `type`

```haskell
T.toLower (T.strip (raType raw))
```

Aplicado imediatamente após o parse do YAML, antes de qualquer despacho. Aceita `"NFAe"`, `"NFAE"`, `"nfae"`, `" NfAe "`, etc. Falha de forma clara com mensagem de erro para tipos desconhecidos.

---

## 7. Nomeação de Estados no DFA

Estados do DFA são subconjuntos de estados do NFA. A função `setName` os codifica como `{q0,q1}` (elementos em ordem ascendente, separados por vírgula, entre chaves).

- **Legível**: o YAML de saída mostra exatamente quais estados NFA compõem cada estado DFA.
- **Determinístico**: `Set.toAscList` garante a mesma string para o mesmo conjunto, independentemente da ordem de inserção.
- **Invertível**: é possível reconstruir os estados NFA constituintes a partir do nome.

---

## 8. Estados Mortos Omitidos

A construção de subconjuntos produz apenas subconjuntos alcançáveis. Transições que levariam ao conjunto vazio `{}` não são geradas (`not (Set.null tgt)` filtra esses casos). O estado morto é implícito: qualquer símbolo sem transição definida vai para o estado morto (rejeição).

Isso mantém o DFA de saída menor e mais legível. Para autômatos completos (com estado morto explícito), basta adicionar um estado `{}` e transições para ele — extensão futura documentada aqui.

---

## 9. Composição da Pipeline

```haskell
-- Versão pura (usada):
convertToDfa (ANfae nfae) = nfaToDfa (nfaeToNfa nfae)

-- Versão Kleisli (mencionada):
fullPipeline :: NFAe -> Identity DFA
fullPipeline = nfaeToNfaM >=> nfaToDfaM
```

A versão pura é mais simples e suficiente. A versão Kleisli com `>=>` em `Identity` seria equivalente; trocando `Identity` por `Either String` adicionaríamos tratamento de erros sem alterar a estrutura da pipeline — padrão útil para futuras validações.

---

## 10. Reprodutibilidade com Nix

O `shell.nix` está pinado ao commit `50ab793786d9de88ee30ec4e4c24fb4236fc2674` do canal `nixos-24.11` com hash SHA256 verificado. Isso garante:

- O mesmo GHC, as mesmas versões de `yaml`/`aeson`, as mesmas ferramentas em qualquer máquina.
- `ghcWithPackages` embute as dependências Haskell no closure do Nix — não há download do Hackage em runtime dentro do `nix-shell`.
- Para atualizar o ambiente: obtenha o novo commit do canal, recalcule o SHA256 com `nix-prefetch-url --unpack <url>` e atualize `shell.nix`.
