#!/bin/sh
set -eu

echo "[NGINX] Esperando interfaz externa eth1"

intentos=0

until ip link show eth1 >/dev/null 2>&1; do
    intentos=$((intentos + 1))

    if [ "$intentos" -ge 30 ]; then
        echo "[NGINX] FALLA: eth1 no apareció"
        exit 1
    fi

    sleep 1
done

ip link set eth1 up

ip address replace \
  203.0.113.10/24 \
  dev eth1

ip -6 address replace \
  2001:db8:500::10/64 \
  dev eth1

ip route replace \
  10.30.0.0/24 \
  via 203.0.113.1 \
  dev eth1

ip route replace \
  192.0.2.0/29 \
  via 203.0.113.1 \
  dev eth1

ip -6 route replace \
  2001:db8:30::/64 \
  via 2001:db8:500::1 \
  dev eth1

echo "[NGINX] Red externa configurada"
