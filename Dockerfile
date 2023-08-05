# syntax=docker/dockerfile:1

FROM ubuntu:jammy

ARG TARGETPLATFORM

LABEL org.opencontainers.image.source=https://github.com/DigitallyRefined/docker-wireguard-tunnel
LABEL org.opencontainers.image.description="docker-wireguard-tunnel ${TARGETPLATFORM}"

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm

RUN \
  apt update && \
  apt dist-upgrade -y && \
  apt install -y --no-install-recommends \
    ca-certificates \
    curl \
    ifupdown \
    iproute2 \
    iputils-ping \
    openresolv \
    rinetd \
    wireguard-tools && \
  apt autoremove -y && \
  rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

RUN cp /etc/rinetd.conf /etc/rinetd.conf.ori

COPY wg-start.sh /usr/local/bin/wireguard

CMD ["wireguard"]

EXPOSE 51820/udp
