#!/bin/sh
# entrypoint.sh do cliente
# Adiciona rota estática para a DMZ passando pelo firewall

set -e

echo "[CLIENTE] Configurando rota para a DMZ via firewall..."

# Rota para a rede DMZ (172.28.2.0/24) via o IP do firewall na LAN
ip route add 172.28.2.0/24 via 172.28.1.1 || true

echo "[CLIENTE] Rota configurada. Mantendo container vivo..."
exec sleep infinity
