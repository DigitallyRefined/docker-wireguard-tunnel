# syntax=docker/dockerfile:1

FROM alpine:3.21

ARG TARGETPLATFORM

LABEL org.opencontainers.image.source=https://github.com/DigitallyRefined/docker-wireguard-tunnel
LABEL org.opencontainers.image.description="docker-wireguard-tunnel ${TARGETPLATFORM}"

RUN apk upgrade --no-cache
RUN apk add --no-cache wireguard-tools
RUN apk add --no-cache rinetd --repository=https://dl-cdn.alpinelinux.org/alpine/edge/testing
RUN cp /etc/rinetd.conf /etc/rinetd.conf.ori

COPY wg-start.sh /usr/sbin/wg-start.sh

CMD ["/usr/sbin/wg-start.sh"]

EXPOSE 51820/udp
