{ pkgs, sources }: 
let
    naersk = pkgs.callPackage sources.naersk { };
in {
    backend = naersk.buildPackage {
        src = ./.;
    };
}