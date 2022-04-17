{ dockerTools, writeShellScriptBin, segmentor }: {
    image = dockerTools.buildLayeredImage {
        name = "gcr.io/segmentor-340421/segmentor";
        tag = "latest";
        contents = with segmentor; [ backend.segmentor frontend.static ];

        config = {
            Cmd = [ "/bin/segmentor" ];
            Env = [ "ENVIRONMENT=production" ];
        };
    };

    dev = writeShellScriptBin "dev" ''
        rm -rf ./node_modules
        ln -s ${segmentor.frontend.nodeDependencies}/lib/node_modules ./node_modules
        export PATH="${segmentor.frontend.nodeDependencies}/bin:$PATH"
        nix develop --command npx concurrently \
            -n FE,BE \
            -c green,red \
            "cd frontend && yarn start" \
            "cd backend && cargo run"
        '';
}
