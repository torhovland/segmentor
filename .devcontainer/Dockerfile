FROM debian:stable-20200224-slim

ARG USERNAME=vscode
RUN useradd -ms /bin/bash $USERNAME

RUN apt-get update && apt-get install -y curl git npm ca-certificates

# Google Cloud SDK
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
RUN apt-get install -y apt-transport-https gnupg
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
RUN apt-get update && apt-get install -y google-cloud-sdk google-cloud-sdk-app-engine-go

# Elm
RUN curl -L https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz | gunzip -c >/usr/local/bin/elm
RUN chmod +x /usr/local/bin/elm
RUN npm install -g elm-format elm-live --unsafe-perm=true
ENTRYPOINT ["elm"]

USER $USERNAME
