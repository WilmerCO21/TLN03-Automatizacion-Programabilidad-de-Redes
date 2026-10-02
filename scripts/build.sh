#!/usr/bin/env bash
set -Eeuo pipefail

RAIZ=$(
    cd "$(dirname "${BASH_SOURCE[0]}")/.."
    pwd
)

IMAGEN_FRR="frr:10.7.1-ssh"
ARCHIVO_FRR="$RAIZ/images/base/frr_10.7.1-ssh.tar"
IMAGEN_FIREFOX="lscr.io/linuxserver/firefox:1157.0build1-1xtradeb1.2404.1-ls125"

echo "=== PREPARANDO IMAGEN FRR DEL CURSO ==="

if docker image inspect "$IMAGEN_FRR" >/dev/null 2>&1; then
    echo "OK: $IMAGEN_FRR ya está disponible"
elif [ -f "$ARCHIVO_FRR" ]; then
    echo "Cargando imagen proporcionada por el profesor:"
    echo "$ARCHIVO_FRR"

    docker load \
      --input "$ARCHIVO_FRR"

    if ! docker image inspect "$IMAGEN_FRR" >/dev/null 2>&1; then
        echo "FALLA: el archivo fue cargado, pero no creó:"
        echo "$IMAGEN_FRR"
        exit 1
    fi

    echo "OK: $IMAGEN_FRR cargada correctamente"
else
    echo "FALLA: no está disponible la imagen $IMAGEN_FRR"
    echo
    echo "Descarga del Drive del profesor el archivo:"
    echo "frr_10.7.1-ssh.tar"
    echo
    echo "Colócalo en:"
    echo "$ARCHIVO_FRR"
    echo
    echo "Después ejecuta nuevamente:"
    echo "./scripts/build.sh"
    exit 1
fi

echo
echo "=== DESCARGANDO IMAGEN DE FIREFOX ==="

docker pull "$IMAGEN_FIREFOX"

echo
echo "=== CONSTRUYENDO IMAGEN CPE ==="

docker build \
  --tag tln03-cpe:1.0 \
  "$RAIZ/images/cpe"

echo
echo "=== CONSTRUYENDO IMAGEN WEB ==="

docker build \
  --tag tln03-web:1.0 \
  "$RAIZ/images/web"

echo
echo "=== IMÁGENES DISPONIBLES ==="

docker image inspect \
  "$IMAGEN_FRR" \
  tln03-cpe:1.0 \
  tln03-web:1.0 \
  "$IMAGEN_FIREFOX" \
  --format '{{index .RepoTags 0}} -> {{.Id}}'

echo
echo "OK: imágenes preparadas correctamente"
