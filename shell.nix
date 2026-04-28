# Ambiente reprodutível pinado ao commit 50ab793 do nixos-24.11 (2025-04-20).
# Para atualizar: obtenha o novo SHA com:
#   nix-prefetch-url --unpack https://github.com/NixOS/nixpkgs/archive/<COMMIT>.tar.gz
{ pkgs ? import (fetchTarball {
    url    = "https://github.com/NixOS/nixpkgs/archive/50ab793786d9de88ee30ec4e4c24fb4236fc2674.tar.gz";
    sha256 = "1s2gr5rcyqvpr58vxdcb095mdhblij9bfzaximrva2243aal3dgx";
  }) {} }:

let
  # Empacota GHC junto com todas as dependências Haskell do projeto.
  # Isso garante que `ghc` e `ghci` enxerguem os pacotes sem precisar
  # baixar nada do Hackage em runtime.
  haskellEnv = pkgs.haskellPackages.ghcWithPackages (ps: with ps; [
    yaml
    aeson
    unordered-containers
    text
    containers
  ]);
in
pkgs.mkShell {
  name = "teo-comp-env";

  buildInputs = [
    # Haskell: GHC + dependências do projeto embutidas
    haskellEnv
    pkgs.cabal-install
    pkgs.haskell-language-server

    # Ferramentas gerais
    pkgs.git
    pkgs.direnv
    pkgs.gnuplot
  ];

  shellHook = ''
    echo "========================================================="
    echo "  Teoria da Computação - PPComp/Ifes (2026.1)"
    echo "  Ambiente reprodutível ativado via Nix (nixos-24.11)."
    echo "========================================================="
    echo "  Haskell: $(ghc --version)"
    echo "  Cabal:   $(cabal --version | head -1)"
    echo "========================================================="
    echo "  Comandos úteis:"
    echo "    cabal build                   compilar"
    echo "    cabal run -- entrada.yaml saida.yaml"
    echo "    cabal repl --repl-options='-XOverloadedStrings'"
    echo "========================================================="
  '';
}
