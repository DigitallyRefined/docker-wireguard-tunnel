#!/bin/bash

if [ ! -f /etc/wireguard/wg0.conf ]; then
  server_private="$(wg genkey)"
  server_public=$(echo "${server_private}" | wg pubkey)

  cat >/etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = $server_private
# PublicKey = $server_public
Address = 10.0.0.254/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; ip6tables -A FORWARD -i wg0 -j ACCEPT; ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE; ip6tables -D FORWARD -i wg0 -j ACCEPT; ip6tables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
SaveConfig = true
EOF

  if [[ ${DOMAIN} && ${PEERS} ]]; then
    count=${PEERS//[a-z]/}
    for peer_number in $(seq $count); do
      peer_private="$(wg genkey)"
      peer_public=$(echo "${peer_private}" | wg pubkey)

      cat >/mnt/peers/peer$peer_number.conf <<EOF
[Interface]
PrivateKey = $peer_private
# PublicKey = $peer_public
Address = 10.0.0.$peer_number/15

[Peer]
PublicKey = $server_public
Endpoint = $DOMAIN:51820
AllowedIPs = 10.0.0.254/32
PersistentKeepalive = 25
EOF

      cat >>/etc/wireguard/wg0.conf <<EOF

[Peer]
# peer$peer_number
PublicKey = $peer_public
AllowedIPs = 10.0.0.$peer_number/32
EOF
    done
  fi
fi

IFS=',' read -ra SERVICE <<< "$SERVICES"
for serv in "${SERVICE[@]}"; do
  service_parts=(${serv//\:/ })
  peer_number=${service_parts[0]//[a-z]/}
  service_hostname=${service_parts[1]}
  container_port=${service_parts[2]}
  expose_port_as=${service_parts[3]}

  if [[ ${DOMAIN} && ${PEERS} ]]; then
    iptables -t nat -A PREROUTING -p tcp --dport $expose_port_as -j DNAT --to-destination 10.0.0.$peer_number:$expose_port_as
  else
    container_ip=`ping -c1 $service_hostname | sed -nE 's/^PING[^(]+\(([^)]+)\).*/\1/p'`
    iptables -t nat -A PREROUTING -p tcp --dport $expose_port_as -j DNAT --to-destination $container_ip:$container_port
  fi
done

iptables -t nat -A POSTROUTING -j MASQUERADE

## Startup modified from https://github.com/activeeos/wireguard-docker

# Find a Wireguard interface
interfaces=$(find /etc/wireguard -type f)
if [ -z $interfaces ]; then
  echo "$(date): Interface not found in /etc/wireguard" >&2
  exit 1
fi

start_interfaces() {
  for interface in $interfaces; do
    echo "$(date): Starting Wireguard $interface"
    wg-quick up $interface
  done
}

stop_interfaces() {
  for interface in $interfaces; do
    wg-quick down $interface
  done
}

start_interfaces

# Handle shutdown behaviour
finish() {
  echo "$(date): Shutting down Wireguard"
  timeout 5 stop_interfaces

  exit 0
}

trap finish TERM INT QUIT

wg

while :; do
  if [ `timeout 5 wg | wc -l` == 0 ]; then
    exit 1
  fi
  sleep 10
done
