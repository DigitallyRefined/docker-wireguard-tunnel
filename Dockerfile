# syntax=docker/dockerfile:1

FROM alpine:3.18 AS builder

RUN set -ex \
  && apk add --no-cache \
    build-base \
    git \
    autoconf \
    automake \
  && cd /tmp \
  && git clone --depth=1 "https://github.com/samhocevar/rinetd" \
  && cd rinetd \
  && ./bootstrap \
  && ./configure --prefix=/usr \
  && make -j $(nproc) \
  && strip rinetd

FROM alpine:3.18

ARG TARGETPLATFORM

LABEL org.opencontainers.image.source=https://github.com/digitallyrefined/tmp
LABEL org.opencontainers.image.description="docker-wireguard-tunnel ${TARGETPLATFORM}"

COPY --from=builder /tmp/rinetd/rinetd /usr/sbin/rinetd

RUN apk add --no-cache wireguard-tools

COPY wg-start.sh /usr/sbin/wireguard

CMD ["/usr/sbin/wireguard"]

EXPOSE 51820/udp
