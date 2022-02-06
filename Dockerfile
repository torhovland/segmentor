FROM rust:1.58-slim as builder

ARG SERVICE_NAME=segmentor

RUN apt-get update \
    && apt-get install -y libssl-dev pkg-config

WORKDIR /usr/src/${SERVICE_NAME}

ADD . ./

RUN cargo build --release

FROM gcr.io/distroless/cc-debian10

ARG SERVICE_NAME=segmentor

COPY --from=builder /usr/src/${SERVICE_NAME}/target/release/${SERVICE_NAME} /usr/local/bin/${SERVICE_NAME}

CMD ["segmentor"]
