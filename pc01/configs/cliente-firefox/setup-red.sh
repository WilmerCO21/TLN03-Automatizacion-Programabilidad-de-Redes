#!/bin/sh
set -eu

echo "[FIREFOX] Esperando interfaz empresarial eth1"

intentos=0

until ip link show eth1 >/dev/null 2>&1; do
    intentos=$((intentos + 1))

    if [ "$intentos" -ge 30 ]; then
        echo "[FIREFOX] FALLA: eth1 no apareció"
        exit 1
    fi

    sleep 1
done

ip link set eth1 up

ip address replace \
  10.30.0.10/24 \
  dev eth1

ip -6 address replace \
  2001:db8:30::10/64 \
  dev eth1

ip route replace \
  192.0.2.0/29 \
  via 10.30.0.1 \
  dev eth1

ip route replace \
  190.1.1.0/24 \
  via 10.30.0.1 \
  dev eth1

ip route replace \
  200.1.1.0/24 \
  via 10.30.0.1 \
  dev eth1

ip route replace \
  203.0.113.0/24 \
  via 10.30.0.1 \
  dev eth1

ip -6 route replace \
  2001:1:1::/48 \
  via 2001:db8:30::1 \
  dev eth1

ip -6 route replace \
  2006:1:1::/48 \
  via 2001:db8:30::1 \
  dev eth1

ip -6 route replace \
  2001:db8:500::/64 \
  via 2001:db8:30::1 \
  dev eth1

echo "[FIREFOX] Red empresarial configurada"
