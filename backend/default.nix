{ pkgs, naersk }: 
let
    naersk-lib = pkgs.callPackage naersk {};
in {
    segmentor = naersk-lib.buildPackage {
        src = ./.;
        nativeBuildInputs = with pkgs; [ openssl pkg-config ];
    };
}