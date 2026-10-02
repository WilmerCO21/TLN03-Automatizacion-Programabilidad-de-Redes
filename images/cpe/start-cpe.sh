#!/bin/sh
set -eu

echo "[CPE] Iniciando contenedor TLN03"

if [ -s /etc/keepalived/keepalived.conf ]; then
    echo "[CPE] Configuración Keepalived encontrada"
    keepalived --dont-fork --log-console --log-detail &
else
    echo "[CPE] Keepalived pendiente de configuración"
fi

exec /usr/local/bin/start.sh "$@"
