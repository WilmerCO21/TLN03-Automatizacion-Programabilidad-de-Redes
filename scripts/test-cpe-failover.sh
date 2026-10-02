#!/usr/bin/env bash
set -uo pipefail

CPE1="clab-pc01-cpe-isp1"
CPE2="clab-pc01-cpe-isp2"
CLIENTE="clab-pc01-cliente-firefox"
fallas=0

restaurar_isp1() {
    docker exec "$CPE1" \
      ip link set dev eth1 up \
      >/dev/null 2>&1 || true
}

trap restaurar_isp1 EXIT INT TERM

tiene_vip4() {
    contenedor="$1"

    salida=$(
        docker exec "$contenedor" \
          ip -4 address show dev eth2 2>/dev/null
    )

    grep -F '10.30.0.1/24' \
      <<<"$salida" \
      >/dev/null
}

tiene_vip6() {
    contenedor="$1"

    salida=$(
        docker exec "$contenedor" \
          ip -6 address show dev eth2 2>/dev/null
    )

    grep -F '2001:db8:30::1/64' \
      <<<"$salida" \
      >/dev/null
}

http_ipv4() {
    pagina=$(
        docker exec "$CLIENTE" \
          curl --noproxy '*' \
          --interface 10.30.0.10 \
          --connect-timeout 5 \
          --max-time 8 \
          -fsS http://203.0.113.10/ 2>/dev/null
    )

    grep -F 'SERVICIO OPERATIVO' \
      <<<"$pagina" \
      >/dev/null
}

http_ipv6() {
    pagina=$(
        docker exec "$CLIENTE" \
          curl --noproxy '*' \
          --interface 2001:db8:30::10 \
          --connect-timeout 5 \
          --max-time 8 \
          -g -6 -fsS \
          'http://[2001:db8:500::10]/' 2>/dev/null
    )

    grep -F 'SERVICIO OPERATIVO' \
      <<<"$pagina" \
      >/dev/null
}

echo "=== PRUEBA DE CONMUTACIÓN DE CPE ==="

echo
echo "=== 1. ESTADO INICIAL ==="

if tiene_vip4 "$CPE1" &&
   tiene_vip6 "$CPE1"; then
    echo "OK: CPE-ISP1 posee las VIP IPv4 e IPv6"
else
    echo "FALLA: CPE-ISP1 no es el MASTER inicial"
    exit 1
fi

if http_ipv4 && http_ipv6; then
    echo "OK: HTTP IPv4 e IPv6 funcionan antes de la falla"
else
    echo "FALLA: el servicio no funciona antes de la prueba"
    exit 1
fi

echo
echo "=== 2. SIMULANDO FALLA DE ISP1 ==="

docker exec "$CPE1" \
  ip link set dev eth1 down

docker exec "$CPE1" \
  ip -br link show dev eth1

echo
echo "=== 3. ESPERANDO TRANSFERENCIA DE LAS VIP ==="

transferencia=0
inicio=$(date +%s)

for intento in $(seq 1 40); do
    if tiene_vip4 "$CPE2" &&
       tiene_vip6 "$CPE2"; then

        fin=$(date +%s)
        segundos=$((fin - inicio))

        echo "OK: CPE-ISP2 asumió ambas VIP en $segundos segundos"
        transferencia=1
        break
    fi

    echo "Intento $intento: esperando CPE-ISP2"
    sleep 1
done

if [ "$transferencia" -eq 0 ]; then
    echo "FALLA: CPE-ISP2 no asumió ambas VIP"
    fallas=$((fallas + 1))
fi

echo
echo "=== 4. COMPROBANDO SERVICIO MEDIANTE ISP2 ==="

servicio_isp2=0

for intento in $(seq 1 40); do
    estado4=0
    estado6=0

    http_ipv4 && estado4=1
    http_ipv6 && estado6=1

    echo "Intento $intento: HTTP-IPv4=$estado4 HTTP-IPv6=$estado6"

    if [ "$estado4" -eq 1 ] &&
       [ "$estado6" -eq 1 ]; then

        echo "OK: servicio dual-stack continúa mediante ISP2"
        servicio_isp2=1
        break
    fi

    sleep 1
done

if [ "$servicio_isp2" -eq 0 ]; then
    echo "FALLA: el servicio no continuó mediante ISP2"
    fallas=$((fallas + 1))
fi

echo
echo "=== 5. RESTAURANDO ISP1 ==="

docker exec "$CPE1" \
  ip link set dev eth1 up

docker exec "$CPE1" \
  ip -br link show dev eth1

echo
echo "=== 6. ESPERANDO RECUPERACIÓN DE CPE-ISP1 ==="

recuperacion=0
inicio=$(date +%s)

for intento in $(seq 1 60); do
    if tiene_vip4 "$CPE1" &&
       tiene_vip6 "$CPE1"; then

        fin=$(date +%s)
        segundos=$((fin - inicio))

        echo "OK: CPE-ISP1 recuperó ambas VIP en $segundos segundos"
        recuperacion=1
        break
    fi

    echo "Intento $intento: esperando recuperación de CPE-ISP1"
    sleep 1
done

if [ "$recuperacion" -eq 0 ]; then
    echo "FALLA: CPE-ISP1 no recuperó las VIP"
    fallas=$((fallas + 1))
fi

echo
echo "=== 7. COMPROBANDO SERVICIO FINAL ==="

servicio_final=0

for intento in $(seq 1 40); do
    if http_ipv4 && http_ipv6; then
        echo "OK: HTTP IPv4 e IPv6 recuperados mediante ISP1"
        servicio_final=1
        break
    fi

    echo "Intento $intento: esperando servicio final"
    sleep 1
done

if [ "$servicio_final" -eq 0 ]; then
    echo "FALLA: el servicio no se recuperó completamente"
    fallas=$((fallas + 1))
fi

echo
echo "=== 8. ESTADO FINAL DE LAS VIP ==="

docker exec "$CPE1" \
  ip -br address show dev eth2

docker exec "$CPE2" \
  ip -br address show dev eth2

echo
echo "=== RESULTADO ==="

if [ "$transferencia" -eq 1 ] &&
   [ "$servicio_isp2" -eq 1 ] &&
   [ "$recuperacion" -eq 1 ] &&
   [ "$servicio_final" -eq 1 ] &&
   [ "$fallas" -eq 0 ]; then

    echo "OK: FAILOVER CPE ISP1/ISP2 SUPERADO"
    trap - EXIT INT TERM
    exit 0
else
    echo "FALLA: la prueba de conmutación CPE no fue superada"
    exit 1
fi
