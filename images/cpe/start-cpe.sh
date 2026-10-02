#!/bin/sh
set -eu

echo "[CPE] Iniciando contenedor TLN03"

if [ -s /etc/keepalived/keepalived.conf ]; then
    echo "[CPE] Configuración Keepalived encontrada"

    (
        intentos=0

        echo "[CPE] Esperando interfaz LAN eth2"

        until ip link show eth2 >/dev/null 2>&1 &&
              ip -4 address show dev eth2 2>/dev/null |
              grep -q 'inet '; do

            intentos=$((intentos + 1))

            if [ "$intentos" -ge 60 ]; then
                echo "[CPE] FALLA: eth2 no quedó configurada"
                exit 1
            fi

            sleep 1
        done

        echo "[CPE] eth2 disponible; iniciando Keepalived"

        exec keepalived \
          --dont-fork \
          --log-console \
          --log-detail \
          -f /etc/keepalived/keepalived.conf
    ) &
else
    echo "[CPE] Keepalived pendiente de configuración"
fi

exec /usr/local/bin/start.sh "$@"
