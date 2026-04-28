# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Master's-level Theory of Computation lab (PPComp/Ifes 2026.1) implementing automaton conversion in Haskell:
- **NFAɛ → NFA**: Remove epsilon transitions
- **NFA → DFA**: Subset construction algorithm

Input/output format is YAML. The program reads an automaton definition and exports the converted result in the same format.

## Development Environment

Uses Nix for reproducible builds. Enter the environment with:

```bash
nix-shell
# or, with direnv:
direnv allow
```

The Nix shell provides: GHC, cabal-install, haskell-language-server, gnuplot, git.

**Any new Haskell libraries must also be added to `shell.nix` buildInputs.**

## Build & Run

Once the Cabal project is initialized:

```bash
cabal build                                          # compilar
cabal run automata-converter -- entrada.yaml saida.yaml   # executar
cabal repl --repl-options='-XOverloadedStrings'      # REPL interativo
# No REPL: :load test/GHCiTests.hs
```

## YAML Automaton Format

```yaml
type: nfae       # 'dfa', 'nfa', or 'nfae' (normalized to lowercase)
alphabet: [0, 1]
states: [q0, q1, q2]
initial_state: q0
final_states: [q2]
transitions:
  - from: q0
    symbol: 0
    to: [q0, q1]
  - from: q0
    symbol: epsilon   # epsilon transitions only in NFAɛ
    to: [q1]
  - from: q1
    symbol: 1
    to: [q2]
```

## Architecture

The implementation must be organized as chainable conversion functions:

1. **YAML I/O** — parse input file into internal data structures; serialize result back to YAML
2. **Data structures** — separate types for `DFA`, `NFA`, and `NFAɛ`
3. **`nfaeToNfa`** — epsilon-closure computation to eliminate epsilon transitions
4. **`nfaToDfa`** — subset construction to produce a deterministic automaton
5. **Pipeline** — `nfaeToNfa >=> nfaToDfa` lets any NFAɛ/NFA/DFA input reach DFA output; `type` field is always lowercased before dispatch

Each conversion function, library choice, and design decision must be documented in a separate architecture justification file.
