{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  buildInputs = with pkgs; [ 
    rustc 
    cargo 
    gcc 
    rustfmt 
    clippy 
    openssl.dev # Needed to build the app.
    vscode
    gtk3 # Needed for VS Code code actions, along with the shellHook below. See https://nixos.wiki/wiki/Development_environment_with_nix-shell.
  ];
  shellHook = ''
     XDG_DATA_DIRS=$GSETTINGS_SCHEMA_PATH
  '';
  ENVIRONMENT = "development";
  RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
}
