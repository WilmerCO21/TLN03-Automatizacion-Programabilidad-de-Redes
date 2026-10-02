#!/usr/bin/env bash
set -Eeuo pipefail

RAIZ=$(
    cd "$(dirname "${BASH_SOURCE[0]}")/.."
    pwd
)

echo "=== DESCARGANDO IMÁGENES BASE ==="

docker pull frr:10.7.1-ssh

docker pull \
  lscr.io/linuxserver/firefox:1157.0build1-1xtradeb1.2404.1-ls125

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
  tln03-cpe:1.0 \
  tln03-web:1.0 \
  lscr.io/linuxserver/firefox:1157.0build1-1xtradeb1.2404.1-ls125 \
  --format '{{index .RepoTags 0}} -> {{.Id}}'

echo
echo "OK: imágenes preparadas correctamente"
