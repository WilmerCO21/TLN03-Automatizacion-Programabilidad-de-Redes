#!/bin/sh
set -eu

echo "[CPE-ISP1] Configurando rutas y NAT"

echo "[CPE-ISP1] Esperando dirección WAN en eth1"

intentos=0

until ip -4 address show dev eth1 2>/dev/null |
      grep -q "192.0.2.2/30"; do

    intentos=$((intentos + 1))

    if [ "$intentos" -ge 30 ]; then
        echo "[CPE-ISP1] FALLA: FRR no configuró 192.0.2.2/30"
        exit 1
    fi

    sleep 1
done

echo "[CPE-ISP1] Dirección WAN disponible"

ip route del default dev eth0 2>/dev/null || true
ip -6 route del default dev eth0 2>/dev/null || true

ip route replace default via 192.0.2.1 dev eth1
ip -6 route replace default via 2001:db8:100:10::1 dev eth1

iptables -t nat -C POSTROUTING \
    -s 10.30.0.0/24 -o eth1 -j MASQUERADE 2>/dev/null ||
iptables -t nat -A POSTROUTING \
    -s 10.30.0.0/24 -o eth1 -j MASQUERADE

iptables -C FORWARD \
    -i eth2 -o eth1 -s 10.30.0.0/24 -j ACCEPT 2>/dev/null ||
iptables -A FORWARD \
    -i eth2 -o eth1 -s 10.30.0.0/24 -j ACCEPT

iptables -C FORWARD \
    -i eth1 -o eth2 -d 10.30.0.0/24 \
    -m conntrack --ctstate ESTABLISHED,RELATED \
    -j ACCEPT 2>/dev/null ||
iptables -A FORWARD \
    -i eth1 -o eth2 -d 10.30.0.0/24 \
    -m conntrack --ctstate ESTABLISHED,RELATED \
    -j ACCEPT

echo "[CPE-ISP1] NAT IPv4 operativo"
