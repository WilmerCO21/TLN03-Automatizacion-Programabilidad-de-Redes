#!/usr/bin/env bash
set -Eeuo pipefail

RAIZ=$(
    cd "$(dirname "${BASH_SOURCE[0]}")/.."
    pwd
)

TOPOLOGIA="$RAIZ/pc01/pc01.yml"
LABORATORIO="pc01"
ESPERADOS=27

for comando in docker containerlab ip ss; do
    if ! command -v "$comando" >/dev/null 2>&1; then
        echo "FALLA: no se encontró el comando $comando"
        exit 1
    fi
done

if ! docker info >/dev/null 2>&1; then
    echo "FALLA: Docker no está funcionando"
    exit 1
fi

echo "=== VALIDANDO TOPOLOGÍA ==="

containerlab validate \
  -t "$TOPOLOGIA"

activos=$(
    docker ps \
      --filter "label=containerlab=$LABORATORIO" \
      --format '{{.Names}}' |
    wc -l
)

if [ "$activos" -eq "$ESPERADOS" ]; then
    detenidos=$(
        docker ps -a \
          --filter "label=containerlab=$LABORATORIO" \
          --filter status=exited \
          --format '{{.Names}}'
    )

    if [ -n "$detenidos" ]; then
        echo
        echo "FALLA: existen contenedores adicionales detenidos:"
        echo "$detenidos"
        echo "Ejecuta primero: ./scripts/destroy.sh"
        exit 1
    fi

    echo
    echo "Se detectaron todos los contenedores del laboratorio."
    echo "Contenedores activos: $activos de $ESPERADOS"
    echo "Se validará el despliegue existente."

    "$RAIZ/scripts/validate.sh"

    echo
    echo "El laboratorio existente está completamente operativo."
    echo "No se realizará un segundo despliegue."
    exit 0
elif [ "$activos" -gt 0 ]; then
    echo
    echo "FALLA: se detectó un despliegue parcial."
    echo "Contenedores activos: $activos de $ESPERADOS"

    docker ps -a \
      --filter "label=containerlab=$LABORATORIO" \
      --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'

    echo
    echo "Ejecuta primero: ./scripts/destroy.sh"
    exit 1
fi

restantes=$(
    docker ps -a \
      --filter "label=containerlab=$LABORATORIO" \
      --format '{{.Names}}'
)

if [ -n "$restantes" ]; then
    echo
    echo "FALLA: existen contenedores anteriores:"
    echo "$restantes"
    echo "Ejecuta primero: ./scripts/destroy.sh"
    exit 1
fi

echo
echo "=== COMPROBANDO IMÁGENES ==="

if ! docker image inspect \
     tln03-cpe:1.0 \
     tln03-web:1.0 \
     lscr.io/linuxserver/firefox:1157.0build1-1xtradeb1.2404.1-ls125 \
     >/dev/null 2>&1; then

    echo "Faltan imágenes; ejecutando construcción."
    "$RAIZ/scripts/build.sh"
else
    echo "OK: todas las imágenes están disponibles"
fi

echo
echo "=== PREPARANDO PUENTE EMPRESARIAL ==="

if ! ip link show br-empresa >/dev/null 2>&1; then
    sudo ip link add br-empresa type bridge
    echo "CREADO: br-empresa"
else
    echo "YA EXISTE: br-empresa"
fi

sudo ip link set br-empresa up

ip -br link show br-empresa

echo
echo "=== COMPROBANDO PUERTO DE FIREFOX ==="

puertos_escuchando=$(
    ss -ltnH |
    awk '{print $4}'
)

if grep -E '(^|:)3001$' \
     <<<"$puertos_escuchando" \
     >/dev/null; then

    echo "FALLA: el puerto TCP 3001 está ocupado"
    ss -ltnp | grep ':3001' || true
    exit 1
fi

echo "OK: puerto 3001 disponible"

echo
echo "=== DESPLEGANDO TLN03 ==="

cd "$RAIZ/pc01"

sudo containerlab deploy \
  -t pc01.yml \
  --max-workers 4

echo
echo "=== ESPERANDO INICIO DE SERVICIOS ==="

sleep 30

activos=$(
    docker ps \
      --filter "label=containerlab=$LABORATORIO" \
      --format '{{.Names}}' |
    wc -l
)

echo "Contenedores activos: $activos de $ESPERADOS"

if [ "$activos" -ne "$ESPERADOS" ]; then
    echo "FALLA: el despliegue no creó todos los contenedores"

    docker ps -a \
      --filter "label=containerlab=$LABORATORIO" \
      --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'

    exit 1
fi

echo
echo "OK: laboratorio desplegado correctamente"
echo "Firefox: https://127.0.0.1:3001"
