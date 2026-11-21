#!/bin/bash
# Entrypoint kompatibel Pterodactyl: menjalankan env STARTUP.
set -o pipefail

cd /home/container || exit 1

INTERNAL_IP=$(ip route get 1 2>/dev/null | awk '{print $(NF-2);exit}')
export INTERNAL_IP

PARSED=$(echo "${STARTUP:-}" | sed -e 's/{{/${/g' -e 's/}}/}/g')

if [ -z "$PARSED" ]; then
  echo "[entrypoint] STARTUP kosong, masuk shell."
  exec bash
fi

printf "\033[1m\033[33mcontainer~ \033[0m"
echo "$PARSED"

eval "$PARSED"
