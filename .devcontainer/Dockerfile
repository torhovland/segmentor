FROM rust:1.58-slim

ARG INSTALL_ZSH="false"
ARG UPGRADE_PACKAGES="false"

# ARG USERNAME=vscode
# ARG USER_UID=1000
# ARG USER_GID=$USER_UID

# ENV CARGO_HOME=/home/vscode/.cargo
# ENV RUSTUP_HOME=/home/vscode/.rustup
ENV ENVIRONMENT=development

COPY library-scripts/*.sh library-scripts/*.env /tmp/library-scripts/
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    # Remove imagemagick due to https://security-tracker.debian.org/tracker/CVE-2019-10131
    && apt-get purge -y imagemagick imagemagick-6-common \
    # Install common packages, non-root user, updated lldb, dependencies
    # && bash /tmp/library-scripts/common-debian.sh "${INSTALL_ZSH}" "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" "true" "true" \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/library-scripts

RUN apt-get update \
    && apt-get install -y git libssl-dev pkg-config \
    && rustup default stable \
    && rustup component add clippy \
    && rustup component add rustfmt \
    && cargo install cargo-edit
