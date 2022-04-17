{ pkgs, stdenv, callPackage, nodejs, nodePackages, writeShellScriptBin }: {
    static = pkgs.yarn2nix-moretea.mkYarnPackage {
        src = ./.;
        packageJSON = ./package.json;
        yarnLock = ./yarn.lock;
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

    shell = pkgs.mkShell {
        buildInputs = with pkgs; [ 
            yarn
        ];
    };

}