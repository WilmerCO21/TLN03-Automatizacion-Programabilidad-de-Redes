#!/usr/bin/env bash
set -Eeuo pipefail

RAIZ=$(
    cd "$(dirname "${BASH_SOURCE[0]}")/.."
    pwd
)

TOPOLOGIA="$RAIZ/pc01/pc01.yml"

echo "=== DESTRUYENDO LABORATORIO TLN03 ==="

cd "$RAIZ/pc01"

sudo containerlab destroy \
  -t "$TOPOLOGIA" \
  --cleanup

echo
echo "=== COMPROBANDO CONTENEDORES ==="

restantes=$(
    docker ps -a \
      --filter label=containerlab=pc01 \
      --format '{{.Names}}'
)

if [ -z "$restantes" ]; then
    echo "OK: no quedan contenedores del laboratorio"
else
    echo "ADVERTENCIA: todavía aparecen estos contenedores:"
    echo "$restantes"
    exit 1
fi

echo
echo "El puente br-empresa y las imágenes Docker se conservaron."

echo
echo "=== MEMORIA DISPONIBLE ==="

free -h
