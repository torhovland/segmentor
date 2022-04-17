{
  inputs = {
    nixpkgs.url = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    naersk.url = "github:nix-community/naersk";
  };

  outputs = { self, nixpkgs, flake-utils, naersk }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
          config.allowUnfree = true;
        };

        overlay = (final: prev: {
          segmentor = (final.callPackage ./. { } // {
            backend = final.callPackage ./backend { inherit naersk; };
            frontend = final.callPackage ./frontend { };
          });
        });

        mergeEnvs = pkgs: envs:
          pkgs.mkShell (builtins.foldl' (a: v: {
            buildInputs = a.buildInputs ++ v.buildInputs;
            nativeBuildInputs = a.nativeBuildInputs ++ v.nativeBuildInputs;
            propagatedBuildInputs = a.propagatedBuildInputs
              ++ v.propagatedBuildInputs;
            propagatedNativeBuildInputs = a.propagatedNativeBuildInputs
              ++ v.propagatedNativeBuildInputs;
            shellHook = a.shellHook + "\n" + v.shellHook;
          }) (pkgs.mkShell { }) envs);

      in rec {
        inherit overlay;
        apps = { dev = pkgs.segmentor.dev; };
        packages = {
          image = pkgs.segmentor.image;
          backend = pkgs.segmentor.backend.segmentor;
          frontend = pkgs.segmentor.frontend.static;
        };
        defaultPackage = packages.image;
        checks = packages;
        devShell = mergeEnvs pkgs (with devShells; [ backend frontend ]);
        devShells = {
          backend = pkgs.segmentor.backend.shell;
          frontend = pkgs.segmentor.frontend.shell;
        };
      });
}