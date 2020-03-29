FROM debian:stable-20200224-slim

ARG USERNAME=vscode
RUN useradd -ms /bin/bash $USERNAME

RUN apt update && apt install -y curl git npm

RUN curl -L https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz | gunzip -c >/usr/local/bin/elm
RUN chmod +x /usr/local/bin/elm
ENTRYPOINT ["elm"]

RUN npm install -g elm-format --unsafe-perm=true

USER $USERNAME
