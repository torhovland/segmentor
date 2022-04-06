let
  overlay = self: super: {
    segmentor = self.rustPlatform.buildRustPackage {
      pname = "segmentor";
      version = "0.0.1";
      src = ./.;
      nativeBuildInputs = [ self.pkgs.pkg-config ];
      buildInputs = [ self.pkgs.openssl.dev ];
      cargoLock = {
        lockFile = ./Cargo.lock;
        outputHashes = {
          "strava-0.2.0" = "sha256-K++qwPNd5m9hj4/Wc0OZM2G7b4XlJEJQvXiA8nKIw88=";
        };
      };
    };
  };
  hostPkgs = import <nixpkgs> { overlays = [ overlay ]; };
  dockerPkgs = import <nixpkgs> { overlays = [ overlay ]; system = "x86_64-linux"; };
in
{
  inherit (hostPkgs) segmentor;

  docker = hostPkgs.dockerTools.streamLayeredImage {
    name = "segmentor";
    contents = [ dockerPkgs.segmentor ];
    config.Cmd = [ "segmentor" ];
    config.Env = [ "ENVIRONMENT=production" ];
  };
}