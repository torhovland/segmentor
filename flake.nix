let
  hostPkgs = import <nixpkgs> { };
  stdenv = hostPkgs.stdenv;
  mkYarnPackage = hostPkgs.yarn2nix-moretea.mkYarnPackage;
  dockerPkgs = import <nixpkgs> { system = "x86_64-linux"; };
  cargo_nix = import ./Cargo.nix { inherit (dockerPkgs) pkgs; };
  backend = cargo_nix.rootCrate.build;
in
{
  docker = hostPkgs.dockerTools.buildLayeredImage {
    name = "gcr.io/segmentor-340421/segmentor";
    tag = "latest";
    contents = [ backend frontend ];
    config.Cmd = [ "/bin/segmentor" ];
    config.Env = [ "ENVIRONMENT=production" ];
  };
}

