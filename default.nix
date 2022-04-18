{ dockerTools, writeShellScriptBin, cacert, segmentor }: {
    image = dockerTools.buildLayeredImage {
        name = "gcr.io/segmentor-340421/segmentor";
        tag = "latest";
        contents = with segmentor; [ 
            cacert # Needed for SSL requests to Strava.
            backend.segmentor 
            frontend.static 
        ];

        config = {
            Cmd = [ "/bin/segmentor" ];
            Env = [ 
                "ENVIRONMENT=production" 
                "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt" # Needed for SSL requests to Strava.
            ];
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
