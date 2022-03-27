FROM rust:1.58-slim as builder

ARG SERVICE_NAME=segmentor

RUN apt-get update \
    && apt-get install -y libssl-dev nodejs npm pkg-config

WORKDIR /usr/src/${SERVICE_NAME}

ADD . ./

RUN cargo build --release

RUN npm install --prefix frontend
RUN npm run build --prefix frontend

FROM gcr.io/distroless/cc-debian10

ARG SERVICE_NAME=segmentor

COPY --from=builder /usr/src/${SERVICE_NAME}/target/release/${SERVICE_NAME} /usr/local/bin/${SERVICE_NAME}
COPY --from=builder /usr/src/${SERVICE_NAME}/static /usr/src/${SERVICE_NAME}/static
COPY --from=builder /usr/src/${SERVICE_NAME}/frontend/build/static /usr/src/${SERVICE_NAME}/static

ENV ENVIRONMENT=production

EXPOSE 8088

CMD ["segmentor"]
