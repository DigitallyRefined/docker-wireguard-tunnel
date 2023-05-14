# Example using Docker WireGuard Tunnel with Fly.io

[Fly.io](https://fly.io/) is a platform to deploy app servers. Their free allowance is quite generous and works with Docker WireGuard Tunnels.

This assumes that you have already setup [Fly.io account](https://fly.io/), have [installed their command line tool](https://fly.io/docs/hands-on/install-flyctl/) and have entered your credit card details on your Fly.io account (they wont charge unless you [exceed their free allowances](https://fly.io/docs/about/pricing/)).

## Server

Will accept connections on behalf of a peer and tunnel them to the designated peer.

`fly.toml`

```yml
# fly.toml app configuration file
#
# See https://fly.io/docs/reference/configuration/ for information about how to use this file.
#

# Choose your own fly.dev subdomain here
app = "my-app-1234"

[build]
  image = "ghcr.io/digitallyrefined/docker-wireguard-tunnel:v2"

[env]
  DOMAIN = "my-app-1234.fly.dev" # Update this to match your subdomain
  PEERS = "1"
  SERVICES = "peer1:nginx:80:8080"

[[mounts]]
  source = "wireguard_data"
  destination = "/etc/wireguard"

[[services]]
  protocol = "udp"
  internal_port = 51820

  [[services.ports]]
    port = 51820

[[services]]
  protocol = "tcp"
  internal_port = 8080

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]
    [services.ports.tls_options]
      alpn = ["h2", "http/1.1"]
      versions = ["TLSv1.2", "TLSv1.3"]
```

```bash
fly launch
```
Use the following options:

```log
? Would you like to copy its configuration to the new app? Yes
? Choose an app name (leaving blank will default to 'my-app-1234') change-me
? Choose a region for deployment: Denver, Colorado (US) (den) # Or a location closest to you
? Would you like to set up a Postgresql database now? No
? Would you like to set up an Upstash Redis database now? No
? Would you like to deploy now? Yes
? Would you like to allocate a dedicated ipv4 address now? Yes
```

Once started, a `peer1.conf` file will be automatically generated in the `/etc/wireguard` directory, it can be viewed and then removed via:

```bash
fly ssh console
cat /etc/wireguard/peer1.conf
# Copy the contents of peer1.conf
rm /etc/wireguard/peer1.conf
```

## Peer

Will connect to the server via WireGuard and setup a tunnel to expose the listed ports.

Paste the `peer1.conf` contents from the Fly.io server into a file named `config/wg0.conf` on the peer.

`docker-compose.yml`

```yml
services:
  wireguard-peer:
    image: ghcr.io/digitallyrefined/docker-wireguard-tunnel:v2
    container_name: wireguard-peer
    environment:
      # Note that DOMAIN & PEERS are not required for the peer
      # Services to expose
      # Format: SERVICES=peer-id:peer-container-name:peer-container-port:expose-port-as
      - SERVICES=peer1:nginx:80:8080
    cap_add:
      - NET_ADMIN
    volumes:
      - ./config:/etc/wireguard
    restart: unless-stopped
    links:
      - nginx:nginx

  nginx:
    image: nginx
    restart: unless-stopped
```

```bash
docker compose up -d
docker compose logs -f
```

Once started you should be able to access the demo nginx server via the domain name that was created by Fly.io, for example:   
`https://my-app-1234.fly.dev`
