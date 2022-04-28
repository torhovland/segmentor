{ pkgs, naersk }: 
let
    naersk-lib = pkgs.callPackage naersk {};
in {
    segmentor = naersk-lib.buildPackage {
        src = ./.;
        nativeBuildInputs = with pkgs; [ openssl pkg-config ];
    };

    shell = pkgs.mkShell {
        buildInputs = with pkgs; [ 
            rustc 
            cargo 
            cargo-edit
            cargo-watch
            gcc 
            rustfmt 
            clippy 
            openssl.dev # Needed to build the app.
            postgresql
            vscode
            gtk3 # Needed for VS Code code actions, along with the shellHook below. See https://nixos.wiki/wiki/Development_environment_with_nix-shell.
        ];
        shellHook = ''
            XDG_DATA_DIRS=$GSETTINGS_SCHEMA_PATH
            export PGDATA=$PWD/postgres_data
            export PGHOST=$PWD/postgres
            export LOG_PATH=$PWD/postgres/LOG
            export PGDATABASE=postgres
            export DATABASE_URL="postgresql:///postgres?host=$PGHOST"
            if [ ! -d $PGHOST ]; then
            mkdir -p $PGHOST
            fi
            if [ ! -d $PGDATA ]; then
            echo 'Initializing postgresql database...'
            initdb $PGDATA --auth=trust >/dev/null
            fi
            pg_ctl start -l $LOG_PATH -o "-c listen_addresses= -c unix_socket_directories=$PGHOST"
        '';
    };
}