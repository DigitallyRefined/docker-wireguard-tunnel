# Docker WireGuard Tunnel

[![Build and push workflow](https://github.com/DigitallyRefined/docker-wireguard-tunnel/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/DigitallyRefined/docker-wireguard-tunnel/actions/workflows/build-and-push.yml)
[![Check for updates workflow](https://github.com/DigitallyRefined/docker-wireguard-tunnel/actions/workflows/check-for-updates.yml/badge.svg)](https://github.com/DigitallyRefined/docker-wireguard-tunnel/actions/workflows/check-for-updates.yml)
[![Container registry](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fdigitallyrefined.github.io%2Fbackage%2FDigitallyRefined%2Fdocker-wireguard-tunnel%2Fdocker-wireguard-tunnel.json&query=%24.downloads&label=Pulls)](https://github.com/DigitallyRefined/docker-wireguard-tunnel/pkgs/container/docker-wireguard-tunnel)
[![Container registry](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fdigitallyrefined.github.io%2Fbackage%2FDigitallyRefined%2Fdocker-wireguard-tunnel%2Fdocker-wireguard-tunnel.json&query=%24.downloads_month&label=Pulls%20per%20month)](https://github.com/DigitallyRefined/docker-wireguard-tunnel/pkgs/container/docker-wireguard-tunnel)

Connect two or more Docker servers together sharing container ports between them via a [WireGuard](https://www.wireguard.com/) tunnel.

For example a Docker server without a public IP address behind a NAT can expose container ports to another Docker server that has a public IP address to allow incoming connections.

![Example Topology](docker-wireguard-tunnel.png)

## Usage Example

This assumes that you have already setup a subdomain DNS entry for your domain, for example:  
`wireguard-tunnel.example.com`

### Server

Will accept connections on behalf of a peer and tunnel them to the designated peer.

`docker-compose.yml`

```yml
services:
  wireguard-tunnel-server:
    image: ghcr.io/digitallyrefined/docker-wireguard-tunnel:v3
    container_name: wireguard-tunnel-server
    environment:
      # Update to your domain
      - DOMAIN=wireguard-tunnel.example.com
      # Number of peers to auto generate config for
      - PEERS=1
      # Services to expose format (comma-separated)
      # SERVICES=peer-id:peer-container-name:peer-container-port:expose-port-as
      - SERVICES=peer1:nginx:80:8080,peer1:nginx-demo:80:8081
    cap_add:
      - NET_ADMIN
    volumes:
      - ./config:/etc/wireguard
    restart: unless-stopped
    ports:
      - '51820:51820/udp'
      - 8080:8080
      - 8081:8081
```

```bash
docker compose up -d
docker compose logs -f
```

Once started, a `peer1.conf` file will be automatically generated in the `config` directory.

### Peer

Will connect to the server via WireGuard and setup a tunnel to expose the listed ports.

Move the `config/peer1.conf` file from the server that was automatically generated and rename it to `config/wg0.conf` on the peer.

`docker-compose.yml`

```yml
services:
  wireguard-tunnel-peer:
    image: ghcr.io/digitallyrefined/docker-wireguard-tunnel:v3
    container_name: wireguard-tunnel-peer
    environment:
      # Note that DOMAIN & PEERS are not required for the peer
      # Services to expose format (comma-separated)
      # SERVICES=peer-id:peer-container-name:peer-container-port:expose-port-as
      - SERVICES=peer1:nginx:80:8080,peer1:nginx-demo:80:8081
    cap_add:
      - NET_ADMIN
    volumes:
      - ./config:/etc/wireguard
    restart: unless-stopped
    init: true
    healthcheck:
      test: ping 10.0.0.254 -c 1 || bash -c 'kill -s 15 -1 && (sleep 10; kill -s 9 -1)'
      interval: 60s
      timeout: 30s
      retries: 3
      start_period: 20s
    links:
      - nginx:nginx
      - nginx-demo:nginx-demo

  nginx:
    image: nginx
    restart: unless-stopped

  nginx-demo:
    image: nginxdemos/hello
    restart: unless-stopped
```

```bash
docker compose up -d
docker compose logs -f
```

Note: if you have a firewall in front of your server you will need to allow connections on port `51820/udp` for the WireGuard server, and connections on ports `8080` and `8081` for the 2 demo nginx servers.

Once started you should be able to access both nginx servers via their exposed ports on the WireGuard server, for example:  
`wireguard-tunnel.example.com:8080` and `wireguard-tunnel.example.com:8081`

You may want to combine the WireGuard tunnel server with [Traefik](example-tls-traefik.md) or [Nginx Proxy Manager](https://nginxproxymanager.com/) or use a 3rd party service such as [Fly.io](example-tls-fly-io.md).

Examples using Docker WireGuard Tunnel with:

* [Traefik](example-tls-traefik.md) to automatically provision TLS/HTTPS certificates
* [Fly.io](example-tls-fly-io.md) to provision a server, subdomain and TLS/HTTPS certificates
