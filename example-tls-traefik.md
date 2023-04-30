# Example using Docker WireGuard Tunnel with Traefik

[Traefik](https://traefik.io/) allows multiple Docker services to be served from a server with different domain names and can automatically provision TLS/HTTPS certificates via [Let's Encrypt](https://letsencrypt.org/) and a HTTP challenge.

This assumes that you have already setup subdomain DNS entries for your domain:  
`wireguard-server.example.com`, `nginx.example.com` and `nginxdemos.example.com`

## Server

Will accept connections on behalf of a peer and tunnel them to the designated peer.

`docker-compose.yml`

```yml
services:
  traefik:
    image: "traefik:v2.9"
    container_name: "traefik"
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      # (Optional) Expose Dashboard
      # - "8080:8080"  # Don't do this in production!
    volumes:
      - ./traefik:/etc/traefik
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - "traefik"

  wireguard-server:
    build: .
    container_name: wireguard-server
    environment:
      # Update to your domain
      - DOMAIN=wireguard-server.example.com
      # Number of peers to auto generate config for
      - PEERS=1
      # Services to expose
      # Format: SERVICES=peer-id:peer-container-name:peer-container-port:expose-port-as
      - SERVICES=peer1:nginx:80:8080,peer1:nginx-demo:80:8081
    cap_add:
      - NET_ADMIN
    volumes:
      - ./wireguard/config:/etc/wireguard
      - ./wireguard/peers:/mnt/peers
    restart: unless-stopped
    ports:
      - '51820:51820/udp'
    networks:
      - "traefik"
    labels:
      traefik.enable: true

      traefik.http.routers.nginx.entrypoints: web,websecure
      traefik.http.routers.nginx.rule: Host(`nginx.example.com`) # Update to your domain
      traefik.http.routers.nginx.tls: true
      traefik.http.routers.nginx.tls.certresolver: production
      traefik.http.services.nginx.loadbalancer.server.port: 8080

      traefik.http.routers.nginx.entrypoints: web,websecure
      traefik.http.routers.nginx.rule: Host(`nginxdemos.example.com`) # Update to your domain
      traefik.http.routers.nginx.tls: true
      traefik.http.routers.nginx.tls.certresolver: production
      traefik.http.services.nginx.loadbalancer.server.port: 8081

networks:
  traefik:
    external: true
```

`config/traefik.yml`

```yml
global:
  checkNewVersion: false
  sendAnonymousUsage: false  # true by default

# (Optional) Log information
# ---
log:
 level: WARNING #ERROR  # DEBUG, INFO, WARNING, ERROR, CRITICAL
#   format: common  # common, json, logfmt
#   filePath: /var/log/traefik/traefik.log

# (Optional) Accesslog
# ---
# accesslog:
  # format: common  # common, json, logfmt
  # filePath: /var/log/traefik/access.log

# (Optional) Enable API and Dashboard
# ---
api:
  dashboard: false # true by default
  debug: false
  insecure: false # Don't do this in production!

# Entry Points configuration
# ---
entryPoints:
  web:
    address: :80
    # (Optional) Redirect to HTTPS
    # ---
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          priority: 1000

  websecure:
    address: :443

ping:
  entryPoint: web

certificatesResolvers:
  production:
    acme:
      email: you@example.com # Update this!
      storage: /etc/traefik/certs/acme.json
      caServer: "https://acme-v02.api.letsencrypt.org/directory"
      httpChallenge:
        entryPoint: web

serversTransport:
  insecureSkipVerify: true

providers:
  docker:
    exposedByDefault: false  # Default is true
  file:
    # watch for dynamic configuration changes
    directory: /etc/traefik
    watch: true
```

```bash
docker compose up
```

Once started, a `peer1.conf` file will be saved under the `peers` directory.

## Peer

Will connect to the server via WireGuard and setup a tunnel to expose the listed ports.

Move the `peers/peer1.conf` file that was automatically generated when starting the server and rename it to `config/wg0.conf` on the peer.

`docker-compose.yml`

```yml
services:
  wireguard-peer:
    build: .
    container_name: wireguard-peer
    environment:
      # Note that DOMAIN & PEERS are not required for the peer
      # Services to expose
      # Format: SERVICES=peer-id:peer-container-name:peer-container-port:expose-port-as
      - SERVICES=peer1:nginx:80:8080,peer1:nginx-demo:80:8081
    cap_add:
      - NET_ADMIN
    volumes:
      - ./config:/etc/wireguard
    restart: unless-stopped
    links:
      - nginx:nginx
      - nginx-demo:nginx-demo

  nginx:
    image: nginx

  nginx-demo:
    image: nginxdemos/hello
```

```bash
docker compose up
```

Once started you should be able to access both nginx servers via the domain names listed on the WireGuard server.   
`https://nginx.example.com` and `https://nginxdemos.example.com`
