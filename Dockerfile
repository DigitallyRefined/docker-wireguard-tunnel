# syntax=docker/dockerfile:1

FROM ubuntu:jammy

LABEL org.opencontainers.image.source=https://github.com/DigitallyRefined/docker-wireguard-tunnel

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
    iptables \
    iputils-ping \
    net-tools \
    rinetd \
    openresolv \
    procps \
    wireguard-tools && \
  update-alternatives --set iptables /usr/sbin/iptables-legacy && \
  update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy && \
  update-alternatives --set ip6tables /usr/sbin/ip6tables-nft && \
  apt autoremove -y && \
  rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

COPY wg-start.sh /usr/local/bin/wireguard

EXPOSE 51820/udp

CMD ["wireguard"]
