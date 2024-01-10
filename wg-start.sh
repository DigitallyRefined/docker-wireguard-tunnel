#!/usr/bin/env bash

wireguard_port="${WIREGUARD_PORT:-51820}"
wireguard_mtu="${WIREGUARD_MTU:-1280}"

if [ ! -f /etc/wireguard/wg0.conf ]; then
  server_private="$(wg genkey)"
  server_public=$(echo -n "${server_private}" | wg pubkey)

  cat >/etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = $server_private
Address = 10.0.0.254/32
ListenPort = $wireguard_port
MTU = $wireguard_mtu
SaveConfig = false
EOF

  if [[ ${DOMAIN} && ${PEERS} ]]; then
    count=${PEERS//[a-z]/}
    for peer_number in $(seq $count); do
      peer_private="$(wg genkey)"
      peer_public=$(echo -n "${peer_private}" | wg pubkey)

      cat >/etc/wireguard/peer$peer_number.conf <<EOF
[Interface]
PrivateKey = $peer_private
Address = 10.0.0.$peer_number/32
MTU = $wireguard_mtu
SaveConfig = false

[Peer]
PublicKey = $server_public
Endpoint = $DOMAIN:$wireguard_port
AllowedIPs = 10.0.0.254/32
PersistentKeepalive = 25
EOF

      cat >>/etc/wireguard/wg0.conf <<EOF

[Peer]
PublicKey = $peer_public
AllowedIPs = 10.0.0.$peer_number/32
EOF
    done
  fi
fi

IFS=',' read -ra SERVICE <<<"$SERVICES"
for serv in "${SERVICE[@]}"; do
  service_parts=(${serv//\:/ })
  peer_number=${service_parts[0]//[a-z]/}
  service_hostname=${service_parts[1]}
  container_port=${service_parts[2]}
  expose_port_as=${service_parts[3]}

  if [[ ${DOMAIN} && ${PEERS} ]]; then
    echo "0.0.0.0 $expose_port_as 10.0.0.$peer_number $expose_port_as" >>/etc/rinetd.conf
  else
    container_ip=$(ping -c1 $service_hostname | sed -nE 's/^PING[^(]+\(([^)]+)\).*/\1/p')
    echo "0.0.0.0 $expose_port_as $container_ip $container_port" >>/etc/rinetd.conf
  fi
done

echo "$(date): Starting Internet redirection server"
rinetd

echo "$(date): Starting Wireguard"
wg-quick up wg0

finish() {
  echo "$(date): Shutting down Wireguard"
  timeout 5 wg-quick down wg0

  exit 0
}

trap finish TERM INT QUIT

wg

while :; do
  if [ $(timeout 5 wg | wc -l) == 0 ]; then
    exit 1
  fi
  sleep 10
done
