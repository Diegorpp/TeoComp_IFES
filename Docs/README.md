# Lab01

O laboratório deve ser executado em haskell

1. Implementar algoritmos fundamentais de conversão entre modelos de autômatos finitios.
2. Explorar a equivalência entre Expressões Regulares (RE) e Autômatos.
3. Desenvolver habilidades práticas em manipulação de linguagens formais e ferramentas de reprodução
(Nix).

## Parte 1: Conversão de Autômatos (NFAɛ → DFA)

NFA = Nondeterministic Finite Automaton
DFA = Deterministic Finite Automaton
NFAɛ = Nondeterministic Finite Automaton with empty transitions
ɛ = episilon

Você deve implementar um programa que realize as seguintes transformações:

- NFAɛ → NFA: Remoção de transições vazias.
- NFA → DFA: Construção de subconjuntos (Subset Construction).

O programa deve ser capaz de ler a definição de um autômato a partir de um arquivo YAML e exportar o resultado equivalente no mesmo formato.

## Especificação YAML do Autômato

Os arquivos de entrada e saída devem seguir a estrutura abaixo:

# Exemplo de um NFA

```yaml
type: nfae # Pode ser 'dfa', 'nfa', 'nfae'
alphabet: [0, 1]
states: [q0, q1, q2]
initial_state: q0
final_states: [q2]
transitions:
- from: q0
symbol: 0
to: [q0, q1]
- from: q0
symbol: epsilon # Use 'epsilon' para transições vazias
to: [q1]
- from: q1
symbol: 1
to: [q2]
```

## Descrição do processo de planejamento

O projeto deve:
- Definir uma leitura de arquivo .yaml
- Definir estruturas de dados para representar os automatos
- Definir Uma função para cada conversão de forma que eu possa encadear elas e partir de uma automato NFAɛ e gerar DFA
- A especificação de "type" deve jogar a entrada sempre para minusculo para processar uma das três opções possíveis ('dfa', 'nfa', 'nfae')
- As bibliotecas que forem adicionadas devem ser adicionadas no ambiente nix
- Documentar cada uma das partes do código
- Documentar como executar o código
- Explique cada decisão da construção da aplicação em um arquivo separado justificando as bibliotecas e o funcionamentos delas.