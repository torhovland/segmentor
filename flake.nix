let
  hostPkgs = import <nixpkgs> { };
  stdenv = hostPkgs.stdenv;
  mkYarnPackage = hostPkgs.yarn2nix-moretea.mkYarnPackage;
  dockerPkgs = import <nixpkgs> { system = "x86_64-linux"; };
  cargo_nix = import ./Cargo.nix { inherit (dockerPkgs) pkgs; };
  backend = cargo_nix.rootCrate.build;
  frontend = mkYarnPackage {
    src = ./frontend;
    packageJSON = ./frontend/package.json;
    yarnLock = ./frontend/yarn.lock;
    buildPhase = ''
      runHook preBuild
      shopt -s dotglob

      rm deps/frontend/node_modules
      mkdir deps/frontend/node_modules
      pushd deps/frontend/node_modules
      ln -s ../../../node_modules/* .
      popd
      yarn --offline build
      mkdir deps/frontend/new_static
      mv deps/frontend/build/* deps/frontend/new_static/
      mv deps/frontend/new_static/static/* deps/frontend/new_static/
      rm -rf deps/frontend/build/static
      mv deps/frontend/new_static deps/frontend/build/static

      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall

      mv deps/frontend/build $out

      runHook postInstall
    '';
    distPhase = ''
      true
    '';
  };
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

