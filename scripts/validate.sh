#!/usr/bin/env bash
set -uo pipefail

RAIZ=$(
    cd "$(dirname "${BASH_SOURCE[0]}")/.."
    pwd
)

TOPOLOGIA="$RAIZ/pc01/pc01.yml"
LABORATORIO="pc01"
ESPERADOS=27
fallas=0

correcto() {
    echo "OK: $1"
}

incorrecto() {
    echo "FALLA: $1"
    fallas=$((fallas + 1))
}

contar_bgp_establecidos() {
    contenedor="$1"
    comando="$2"

    docker exec "$contenedor" \
      vtysh -c "$comando" 2>/dev/null |
    awk '
      $1 ~ /^[0-9a-fA-F:.]+$/ &&
      $10 ~ /^[0-9]+$/ {
          cantidad++
      }

      END {
          print cantidad + 0
      }
    '
}

comprobar_bgp_total() {
    local descripcion="$1"
    local contenedor="$2"
    local comando="$3"
    local esperado="$4"
    local resultado

    resultado=$(
        contar_bgp_establecidos \
          "$contenedor" \
          "$comando"
    )

    echo "$descripcion: $resultado de $esperado"

    if [ "$resultado" -eq "$esperado" ]; then
        correcto "$descripcion"
    else
        incorrecto "$descripcion"
    fi
}

contar_bgp_as_establecidos() {
    contenedor="$1"
    comando="$2"
    as_remoto="$3"

    docker exec "$contenedor" \
      vtysh -c "$comando" 2>/dev/null |
    awk -v asn="$as_remoto" '
      $1 ~ /^[0-9a-fA-F:.]+$/ &&
      $3 == asn &&
      $10 ~ /^[0-9]+$/ {
          cantidad++
      }

      END {
          print cantidad + 0
      }
    '
}

comprobar_bgp_as() {
    descripcion="$1"
    contenedor="$2"
    comando="$3"
    as_remoto="$4"
    esperado="$5"

    resultado=$(
        contar_bgp_as_establecidos \
          "$contenedor" \
          "$comando" \
          "$as_remoto"
    )

    echo "$descripcion: $resultado de $esperado"

    if [ "$resultado" -eq "$esperado" ]; then
        correcto "$descripcion"
    else
        incorrecto "$descripcion"
    fi
}

echo "=== VALIDACIÓN AUTOMÁTICA TLN03 ==="

echo
echo "=== 1. TOPOLOGÍA ==="

if containerlab validate -t "$TOPOLOGIA"; then
    correcto "topología válida"
else
    incorrecto "topología inválida"
fi

echo
echo "=== 2. CONTENEDORES ==="

activos=$(
    docker ps \
      --filter "label=containerlab=$LABORATORIO" \
      --format '{{.Names}}' |
    wc -l
)

echo "Contenedores activos: $activos de $ESPERADOS"

if [ "$activos" -eq "$ESPERADOS" ]; then
    correcto "todos los contenedores están activos"
else
    incorrecto "cantidad de contenedores incorrecta"
fi

detenidos=$(
    docker ps -a \
      --filter "label=containerlab=$LABORATORIO" \
      --filter status=exited \
      --format '{{.Names}}'
)

if [ -z "$detenidos" ]; then
    correcto "no existen contenedores detenidos"
else
    incorrecto "existen contenedores detenidos"
    echo "$detenidos"
fi

echo
echo "=== 3. OSPF DUAL-STACK EN AS100 ==="

comprobar_ospf() {
    local nodo="$1"
    local esperado="$2"
    local contenedor="clab-pc01-$nodo"
    local ospf4
    local ospf6

    ospf4=$(
        docker exec "$contenedor" \
          vtysh -c "show ip ospf neighbor" 2>/dev/null |
        awk '
          $3 ~ /^Full/ {
              cantidad++
          }

          END {
              print cantidad + 0
          }
        '
    )

    ospf6=$(
        docker exec "$contenedor" \
          vtysh -c "show ipv6 ospf6 neighbor" 2>/dev/null |
        awk '
          $4 ~ /^Full/ {
              cantidad++
          }

          END {
              print cantidad + 0
          }
        '
    )

    echo "$nodo IPv4: $ospf4 de $esperado"
    echo "$nodo IPv6: $ospf6 de $esperado"

    if [ "$ospf4" -eq "$esperado" ]; then
        correcto "OSPF IPv4 de $nodo"
    else
        incorrecto "OSPF IPv4 de $nodo"
    fi

    if [ "$ospf6" -eq "$esperado" ]; then
        correcto "OSPFv3 de $nodo"
    else
        incorrecto "OSPFv3 de $nodo"
    fi
}

while read -r nodo esperado; do
    comprobar_ospf "$nodo" "$esperado"
done <<'VECINOS_OSPF'
as100-rr1 2
as100-rr2 2
as100-p1 4
as100-p2 5
as100-p3 4
as100-p4 5
as100-p5 4
as100-pe1 2
as100-pe2 2
as100-borde1 1
as100-borde2 1
VECINOS_OSPF

echo
echo "=== 4. IS-IS DUAL-STACK EN AS200 ==="

comprobar_isis() {
    local nodo="$1"
    local esperado="$2"
    local contenedor="clab-pc01-$nodo"
    local vecinos

    vecinos=$(
        docker exec "$contenedor" \
          vtysh -c "show isis neighbor" 2>/dev/null |
        awk '
          $4 == "Up" {
              cantidad++
          }

          END {
              print cantidad + 0
          }
        '
    )

    echo "$nodo: $vecinos de $esperado"

    if [ "$vecinos" -eq "$esperado" ]; then
        correcto "IS-IS dual-stack de $nodo"
    else
        incorrecto "IS-IS dual-stack de $nodo"
    fi
}

while read -r nodo esperado; do
    comprobar_isis "$nodo" "$esperado"
done <<'VECINOS_ISIS'
as200-rr1 2
as200-rr2 2
as200-p1 4
as200-p2 5
as200-p3 4
as200-p4 5
as200-p5 4
as200-pe1 2
as200-pe2 2
as200-borde1 1
as200-borde2 1
VECINOS_ISIS

echo
echo "=== 5. iBGP CON ROUTE REFLECTORS ==="

comprobar_bgp_total \
  "AS100-RR1 IPv4" \
  clab-pc01-as100-rr1 \
  "show bgp ipv4 unicast summary" \
  10

comprobar_bgp_total \
  "AS100-RR1 IPv6" \
  clab-pc01-as100-rr1 \
  "show bgp ipv6 unicast summary" \
  10

comprobar_bgp_total \
  "AS100-RR2 IPv4" \
  clab-pc01-as100-rr2 \
  "show bgp ipv4 unicast summary" \
  10

comprobar_bgp_total \
  "AS100-RR2 IPv6" \
  clab-pc01-as100-rr2 \
  "show bgp ipv6 unicast summary" \
  10

comprobar_bgp_total \
  "AS200-RR1 IPv4" \
  clab-pc01-as200-rr1 \
  "show bgp ipv4 unicast summary" \
  10

comprobar_bgp_total \
  "AS200-RR1 IPv6" \
  clab-pc01-as200-rr1 \
  "show bgp ipv6 unicast summary" \
  10

comprobar_bgp_total \
  "AS200-RR2 IPv4" \
  clab-pc01-as200-rr2 \
  "show bgp ipv4 unicast summary" \
  10

comprobar_bgp_total \
  "AS200-RR2 IPv6" \
  clab-pc01-as200-rr2 \
  "show bgp ipv6 unicast summary" \
  10

echo
echo "=== 6. eBGP EXTERNO ==="

echo
echo "--- INTERCONEXIÓN AS100-AS200 ---"

for nodo in as100-borde1 as100-borde2; do
    comprobar_bgp_as \
      "$nodo IPv4 hacia AS200" \
      "clab-pc01-$nodo" \
      "show bgp ipv4 unicast summary" \
      200 \
      2

    comprobar_bgp_as \
      "$nodo IPv6 hacia AS200" \
      "clab-pc01-$nodo" \
      "show bgp ipv6 unicast summary" \
      200 \
      2
done

for nodo in as200-borde1 as200-borde2; do
    comprobar_bgp_as \
      "$nodo IPv4 hacia AS100" \
      "clab-pc01-$nodo" \
      "show bgp ipv4 unicast summary" \
      100 \
      2

    comprobar_bgp_as \
      "$nodo IPv6 hacia AS100" \
      "clab-pc01-$nodo" \
      "show bgp ipv6 unicast summary" \
      100 \
      2
done

echo
echo "--- ACCESO EMPRESARIAL ---"

comprobar_bgp_as \
  "CPE-ISP1 IPv6 hacia AS100" \
  clab-pc01-cpe-isp1 \
  "show bgp ipv6 unicast summary" \
  100 \
  1

comprobar_bgp_as \
  "CPE-ISP2 IPv6 hacia AS200" \
  clab-pc01-cpe-isp2 \
  "show bgp ipv6 unicast summary" \
  200 \
  1

echo
echo "--- SERVIDORES ANYCAST ---"

comprobar_bgp_as \
  "Servidor-web1 IPv4 hacia AS100" \
  clab-pc01-servidor-web1 \
  "show bgp ipv4 unicast summary" \
  100 \
  1

comprobar_bgp_as \
  "Servidor-web1 IPv6 hacia AS100" \
  clab-pc01-servidor-web1 \
  "show bgp ipv6 unicast summary" \
  100 \
  1

comprobar_bgp_as \
  "Servidor-web2 IPv4 hacia AS200" \
  clab-pc01-servidor-web2 \
  "show bgp ipv4 unicast summary" \
  200 \
  1

comprobar_bgp_as \
  "Servidor-web2 IPv6 hacia AS200" \
  clab-pc01-servidor-web2 \
  "show bgp ipv6 unicast summary" \
  200 \
  1

echo
echo "=== 7. VRRP ==="

maestros_v4=0
maestros_v6=0
maestro_v4=""
maestro_v6=""

for cpe in cpe-isp1 cpe-isp2; do
    contenedor="clab-pc01-$cpe"

    if docker exec "$contenedor" \
         ip -4 address show dev eth2 2>/dev/null |
       grep '10.30.0.1/24' >/dev/null; then

        maestros_v4=$((maestros_v4 + 1))
        maestro_v4="$cpe"
    fi

    if docker exec "$contenedor" \
         ip -6 address show dev eth2 2>/dev/null |
       grep '2001:db8:30::1/64' >/dev/null; then

        maestros_v6=$((maestros_v6 + 1))
        maestro_v6="$cpe"
    fi
done

echo "MASTER IPv4: ${maestro_v4:-ninguno}"
echo "MASTER IPv6: ${maestro_v6:-ninguno}"

if [ "$maestros_v4" -eq 1 ] &&
   [ "$maestros_v6" -eq 1 ]; then
    correcto "un único MASTER VRRP dual-stack"
else
    incorrecto "elección VRRP incorrecta"
fi

echo
echo "=== 8. RUTAS Y NAT DE LOS CPE ==="

for cpe in cpe-isp1 cpe-isp2; do
    contenedor="clab-pc01-$cpe"

    if docker exec "$contenedor" \
         ip route show default 2>/dev/null |
       grep 'dev eth1' >/dev/null; then
        correcto "$cpe tiene ruta predeterminada IPv4"
    else
        incorrecto "$cpe no tiene ruta predeterminada IPv4"
    fi

    if docker exec "$contenedor" \
         ip -6 route show default 2>/dev/null |
       grep 'dev eth1' >/dev/null; then
        correcto "$cpe tiene ruta predeterminada IPv6"
    else
        incorrecto "$cpe no tiene ruta predeterminada IPv6"
    fi

    if docker exec "$contenedor" \
         iptables -t nat -S POSTROUTING 2>/dev/null |
       grep '10.30.0.0/24.*MASQUERADE' >/dev/null; then
        correcto "$cpe tiene NAT IPv4"
    else
        incorrecto "$cpe no tiene NAT IPv4"
    fi
done

echo
echo "=== 9. SERVIDORES WEB ==="

for servidor in servidor-web1 servidor-web2; do
    contenedor="clab-pc01-$servidor"

    if docker exec "$contenedor" \
         curl --noproxy '*' \
         --connect-timeout 2 \
         --max-time 3 \
         -fsS http://127.0.0.1/ 2>/dev/null |
       grep 'SERVICIO OPERATIVO' >/dev/null; then

        correcto "$servidor está operativo"
    else
        incorrecto "$servidor no responde"
    fi
done

echo
echo "=== 10. SERVICIO ANYCAST ==="

respuesta_v4=$(
    docker exec clab-pc01-cliente-firefox \
      curl --noproxy '*' \
      --connect-timeout 5 \
      --max-time 8 \
      -fsSI http://203.0.113.10/ 2>/dev/null |
    awk -F': ' '
      tolower($1) == "x-tln03-node" {
          gsub("\r", "", $2)
          print $2
          exit
      }
    '
)

respuesta_v6=$(
    docker exec clab-pc01-cliente-firefox \
      curl --noproxy '*' \
      --connect-timeout 5 \
      --max-time 8 \
      -g -6 -fsSI \
      'http://[2001:db8:500::10]/' 2>/dev/null |
    awk -F': ' '
      tolower($1) == "x-tln03-node" {
          gsub("\r", "", $2)
          print $2
          exit
      }
    '
)

echo "Servidor IPv4: ${respuesta_v4:-sin respuesta}"
echo "Servidor IPv6: ${respuesta_v6:-sin respuesta}"

if [ -n "$respuesta_v4" ]; then
    correcto "HTTP Anycast IPv4"
else
    incorrecto "HTTP Anycast IPv4"
fi

if [ -n "$respuesta_v6" ]; then
    correcto "HTTP Anycast IPv6"
else
    incorrecto "HTTP Anycast IPv6"
fi

echo
echo "=== 11. FIREFOX ==="

if curl -kfsS \
     --connect-timeout 5 \
     https://127.0.0.1:3001/ \
     >/dev/null 2>&1; then

    correcto "interfaz gráfica de Firefox"
else
    incorrecto "interfaz gráfica de Firefox"
fi

echo
echo "=== RESULTADO ==="

if [ "$fallas" -eq 0 ]; then
    echo "OK: TODAS LAS PRUEBAS TLN03 FUERON SUPERADAS"
    exit 0
else
    echo "FALLA: se encontraron $fallas comprobaciones incorrectas"
    exit 1
fi
