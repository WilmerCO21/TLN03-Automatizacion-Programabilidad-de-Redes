#!/bin/sh
set -eu

echo "[WEB] Iniciando servidor TLN03 con FRR"

nginx

(
    estado_anterior=""

    while :; do
        if curl --noproxy '*' \
             --connect-timeout 1 \
             --max-time 2 \
             -fsS http://127.0.0.1/ \
             >/dev/null 2>&1; then
            estado_actual="activo"

            ip address replace \
              203.0.113.10/32 \
              dev lo 2>/dev/null || true

            ip -6 address replace \
              2001:db8:500::10/128 \
              dev lo 2>/dev/null || true
        else
            estado_actual="caido"

            ip address del \
              203.0.113.10/32 \
              dev lo 2>/dev/null || true

            ip -6 address del \
              2001:db8:500::10/128 \
              dev lo 2>/dev/null || true
        fi

        if [ "$estado_actual" != "$estado_anterior" ]; then
            echo "[WEB] Estado de Nginx: $estado_actual"
            estado_anterior="$estado_actual"
        fi

        sleep 2
    done
) &

exec /usr/local/bin/start.sh "$@"
