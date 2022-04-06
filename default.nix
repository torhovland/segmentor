let
  hostPkgs = import <nixpkgs> { };
  dockerPkgs = import <nixpkgs> { system = "x86_64-linux"; };
  cargo_nix = import ./Cargo.nix { inherit (dockerPkgs) pkgs; };
in
{
  docker = hostPkgs.dockerTools.streamLayeredImage {
    name = "segmentor";
    contents = [ cargo_nix.rootCrate.build ];
    config.Cmd = [ "/bin/segmentor" ];
    config.Env = [ "ENVIRONMENT=production" ];
  };
}