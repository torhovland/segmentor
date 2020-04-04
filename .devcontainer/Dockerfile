FROM debian:stable-20200224-slim

ARG USERNAME=vscode
RUN useradd -ms /bin/bash $USERNAME

RUN apt-get update && apt-get install -y ca-certificates curl git npm procps

# Google Cloud SDK
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
RUN apt-get install -y apt-transport-https gnupg
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
RUN apt-get update && apt-get install -y google-cloud-sdk google-cloud-sdk-app-engine-go

# Go
RUN curl https://dl.google.com/go/go1.14.1.linux-amd64.tar.gz | tar -C /usr/local -xz
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH" \
    # Install Go tools w/module support
    && mkdir -p /tmp/gotools \
    && cd /tmp/gotools \
    && GO111MODULE=on go get -v golang.org/x/tools/gopls@latest 2>&1 \
    && GO111MODULE=on go get -v \
        honnef.co/go/tools/...@latest \
        golang.org/x/tools/cmd/gorename@latest \
        golang.org/x/tools/cmd/goimports@latest \
        golang.org/x/tools/cmd/guru@latest \
        golang.org/x/lint/golint@latest \
        github.com/mdempsky/gocode@latest \
        github.com/cweill/gotests/...@latest \
        github.com/haya14busa/goplay/cmd/goplay@latest \
        github.com/sqs/goreturns@latest \
        github.com/josharian/impl@latest \
        github.com/davidrjenni/reftools/cmd/fillstruct@latest \
        github.com/ramya-rao-a/go-outline@latest  \
        github.com/acroca/go-symbols@latest  \
        github.com/godoctor/godoctor@latest  \
        github.com/rogpeppe/godef@latest  \
        github.com/zmb3/gogetdoc@latest \
        github.com/fatih/gomodifytags@latest  \
        github.com/mgechev/revive@latest  \
        github.com/go-delve/delve/cmd/dlv@latest 2>&1 \
    #
    # Install Go tools w/o module support
    && go get -v github.com/alecthomas/gometalinter \
        github.com/uudashr/gopkgs/cmd/gopkgs 2>&1 \
    #
    # Install gocode-gomod
    && go get -x -d github.com/stamblerre/gocode 2>&1 \
    && go build -o gocode-gomod github.com/stamblerre/gocode \
    && mv gocode-gomod $GOPATH/bin/ \
    #
    # Install golangci-lint
    && curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin 2>&1 \
    # Add write permission for /go/pkg
    && chmod -R a+rwX /go/pkg \
    #
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /go/src /tmp/gotools

ENV GO111MODULE=auto

# Elm
RUN curl -L https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz | gunzip -c >/usr/local/bin/elm
RUN chmod +x /usr/local/bin/elm
RUN npm install -g elm-format elm-live --unsafe-perm=true
ENTRYPOINT ["elm"]

USER $USERNAME
