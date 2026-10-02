#!/bin/sh
set -eu

obtener_gateway() {
    awk '
    {
        for (i = 1; i <= NF; i++) {
            if ($i == "via" && (i + 1) <= NF) {
                print $(i + 1)
                exit
            }
        }
    }
    '
}

gateway4=$(
    ip -4 route show default dev eth1 |
    obtener_gateway
)

gateway6=$(
    ip -6 route show default dev eth1 |
    obtener_gateway
)

[ -n "${gateway4:-}" ] || exit 1
[ -n "${gateway6:-}" ] || exit 1

ping -I eth1 -c 1 -W 1 "$gateway4" >/dev/null 2>&1 &&
ping -6 -I eth1 -c 1 -W 1 "$gateway6" >/dev/null 2>&1
