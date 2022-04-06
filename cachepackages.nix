let
  pkgs = import <nixpkgs> { };
in with pkgs; [
  yarn2nix-moretea.mkYarnPackage
  cargo
  rustc
]