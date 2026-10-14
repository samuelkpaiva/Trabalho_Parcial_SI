#!/bin/sh
# entrypoint.sh do dmz-web
# Adiciona rota estática de retorno para a rede Cliente via firewall

set -e

echo "[DMZ-WEB] Configurando rota de retorno para a rede Cliente..."

# Rota para a rede Cliente (172.28.1.0/24) via o IP do firewall na DMZ
ip route add 172.28.1.0/24 via 172.28.2.1 || true

echo "[DMZ-WEB] Rota configurada. Iniciando Nginx..."
exec nginx -g "daemon off;"
