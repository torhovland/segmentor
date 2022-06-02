{
  inputs = {
    nixpkgs.url = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    naersk.url = "github:nix-community/naersk";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, naersk, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        segmentor-overlay = (final: prev: {
          segmentor = (final.callPackage ./. { } // {
            backend = final.callPackage ./backend { inherit naersk; };
            frontend = final.callPackage ./frontend { };
          });
        });

        overlays = [ (import rust-overlay) segmentor-overlay ];

        pkgs = import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
        };

        mergeEnvs = pkgs: envs:
          pkgs.mkShell (builtins.foldl' (a: v: {
            buildInputs = a.buildInputs ++ v.buildInputs;
            nativeBuildInputs = a.nativeBuildInputs ++ v.nativeBuildInputs;
            propagatedBuildInputs = a.propagatedBuildInputs
              ++ v.propagatedBuildInputs;
            propagatedNativeBuildInputs = a.propagatedNativeBuildInputs
              ++ v.propagatedNativeBuildInputs;
            shellHook = a.shellHook + "\n" + v.shellHook;
            ENVIRONMENT = "development";
            RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
            LC_ALL = "en_US.UTF-8";
            LC_CTYPE = "en_US.UTF-8";
          }) (pkgs.mkShell { }) envs);

      in with pkgs; rec {
        apps = { dev = segmentor.dev; };
        packages = {
          image = segmentor.image;
          backend = segmentor.backend.segmentor;
          frontend = segmentor.frontend.static;
        };
        defaultPackage = packages.image;
        checks = packages;
        devShell = mergeEnvs pkgs (with devShells; [ backend frontend ]);
        devShells = {
          backend = segmentor.backend.shell;
          frontend = segmentor.frontend.shell;
        };
      });
}