#!/usr/bin/env bash
set -uo pipefail

WEB1="clab-pc01-servidor-web1"
CLIENTE="clab-pc01-cliente-firefox"
fallas=0

web1_activo() {
    pagina=$(
        docker exec "$WEB1" \
          curl --noproxy '*' \
          --connect-timeout 1 \
          --max-time 2 \
          -fsS http://127.0.0.1/ 2>/dev/null
    )

    grep -F 'SERVICIO OPERATIVO' \
      <<<"$pagina" \
      >/dev/null
}

restaurar_web1() {
    if ! web1_activo; then
        docker exec "$WEB1" nginx \
          >/dev/null 2>&1 || true
    fi
}

trap restaurar_web1 EXIT INT TERM

tiene_anycast4() {
    salida=$(
        docker exec "$WEB1" \
          ip -4 address show dev lo 2>/dev/null
    )

    grep -F '203.0.113.10/32' \
      <<<"$salida" \
      >/dev/null
}

tiene_anycast6() {
    salida=$(
        docker exec "$WEB1" \
          ip -6 address show dev lo 2>/dev/null
    )

    grep -F '2001:db8:500::10/128' \
      <<<"$salida" \
      >/dev/null
}

nodo_ipv4() {
    docker exec "$CLIENTE" \
      curl --noproxy '*' \
      --connect-timeout 3 \
      --max-time 5 \
      -fsSI http://203.0.113.10/ 2>/dev/null |
    awk -F': ' '
      tolower($1) == "x-tln03-node" {
          gsub("\r", "", $2)
          print $2
          exit
      }
    '
}

nodo_ipv6() {
    docker exec "$CLIENTE" \
      curl --noproxy '*' \
      --connect-timeout 3 \
      --max-time 5 \
      -g -6 -fsSI \
      "http://[2001:db8:500::10]/" 2>/dev/null |
    awk -F': ' '
      tolower($1) == "x-tln03-node" {
          gsub("\r", "", $2)
          print $2
          exit
      }
    '
}

echo "=== PRUEBA DE CONMUTACIÓN WEB ANYCAST ==="

echo
echo "=== 1. ESTADO INICIAL ==="

inicial_v4="$(nodo_ipv4)"
inicial_v6="$(nodo_ipv6)"

echo "IPv4: ${inicial_v4:-sin respuesta}"
echo "IPv6: ${inicial_v6:-sin respuesta}"

if [ "$inicial_v4" != "servidor-web1" ] ||
   [ "$inicial_v6" != "servidor-web1" ]; then

    echo "FALLA: servidor-web1 no es el nodo inicial"
    exit 1
fi

echo "OK: servidor-web1 atiende IPv4 e IPv6"

echo
echo "=== 2. DETENIENDO SOLAMENTE NGINX EN WEB1 ==="

docker exec "$WEB1" \
  nginx -s stop

echo
echo "=== 3. ESPERANDO RETIRO DE ANYCAST ==="

retiro=0
inicio=$(date +%s)

for intento in $(seq 1 20); do
    http=0
    anycast4=0
    anycast6=0

    web1_activo && http=1
    tiene_anycast4 && anycast4=1
    tiene_anycast6 && anycast6=1

    echo "Intento $intento: HTTP=$http IPv4=$anycast4 IPv6=$anycast6"

    if [ "$http" -eq 0 ] &&
       [ "$anycast4" -eq 0 ] &&
       [ "$anycast6" -eq 0 ]; then

        fin=$(date +%s)
        segundos=$((fin - inicio))

        echo "OK: rutas Anycast retiradas en $segundos segundos"
        retiro=1
        break
    fi

    sleep 1
done

if [ "$retiro" -eq 0 ]; then
    echo "FALLA: WEB1 no retiró sus direcciones Anycast"
    fallas=$((fallas + 1))
fi

echo
echo "=== 4. ESPERANDO CONMUTACIÓN A WEB2 ==="

transferencia=0
inicio=$(date +%s)

for intento in $(seq 1 30); do
    servidor_v4="$(nodo_ipv4)"
    servidor_v6="$(nodo_ipv6)"

    echo "Intento $intento: IPv4=${servidor_v4:-sin respuesta} IPv6=${servidor_v6:-sin respuesta}"

    if [ "$servidor_v4" = "servidor-web2" ] &&
       [ "$servidor_v6" = "servidor-web2" ]; then

        fin=$(date +%s)
        segundos=$((fin - inicio))

        echo "OK: tráfico transferido a WEB2 en $segundos segundos"
        transferencia=1
        break
    fi

    sleep 1
done

if [ "$transferencia" -eq 0 ]; then
    echo "FALLA: el tráfico no cambió a servidor-web2"
    fallas=$((fallas + 1))
fi

echo
echo "=== 5. RESTAURANDO NGINX EN WEB1 ==="

docker exec "$WEB1" nginx

echo
echo "=== 6. ESPERANDO RECUPERACIÓN DE WEB1 ==="

recuperacion=0
inicio=$(date +%s)

for intento in $(seq 1 30); do
    servidor_v4="$(nodo_ipv4)"
    servidor_v6="$(nodo_ipv6)"

    echo "Intento $intento: IPv4=${servidor_v4:-sin respuesta} IPv6=${servidor_v6:-sin respuesta}"

    if [ "$servidor_v4" = "servidor-web1" ] &&
       [ "$servidor_v6" = "servidor-web1" ]; then

        fin=$(date +%s)
        segundos=$((fin - inicio))

        echo "OK: tráfico recuperado por WEB1 en $segundos segundos"
        recuperacion=1
        break
    fi

    sleep 1
done

if [ "$recuperacion" -eq 0 ]; then
    echo "FALLA: el tráfico no regresó a servidor-web1"
    fallas=$((fallas + 1))
fi

echo
echo "=== 7. INTERFACES FINALES DE WEB1 ==="

docker exec "$WEB1" \
  ip -br address show dev lo

docker exec "$WEB1" \
  ip -br address show dev eth1

echo
echo "=== RESULTADO ==="

if [ "$retiro" -eq 1 ] &&
   [ "$transferencia" -eq 1 ] &&
   [ "$recuperacion" -eq 1 ] &&
   [ "$fallas" -eq 0 ]; then

    echo "OK: FAILOVER WEB ANYCAST SUPERADO"
    trap - EXIT INT TERM
    exit 0
else
    echo "FALLA: la prueba de conmutación web no fue superada"
    exit 1
fi
