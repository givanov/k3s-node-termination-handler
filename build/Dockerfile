FROM quay.io/ouzi/go-builder:1.14.2 as builder

WORKDIR /operator

# download modules
COPY go.mod .
COPY go.sum .
RUN go mod download

# add makefile
COPY Makefile .
RUN make setup

COPY . /operator
ARG TARGETOS
ARG TARGETARCH

RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOARM=7 make build-docker

FROM alpine:3.12.0

ENV OPERATOR=/usr/local/bin/operator \
    USER_UID=1001 \
    USER_NAME=k3s-node-termination-handler

# install operator binary
COPY --from=builder /operator/_dist/k3s-node-termination-handler ${OPERATOR}

COPY build/bin /usr/local/bin
RUN  /usr/local/bin/user_setup

ENTRYPOINT ["/usr/local/bin/entrypoint"]

USER ${USER_UID}