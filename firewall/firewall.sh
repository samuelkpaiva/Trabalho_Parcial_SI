#!/bin/sh

set -e

echo "[firewall] Aplicando regras de filtragem..."

# O encaminhamento IPv4 (net.ipv4.ip_forward=1) é configurado pelo Docker Compose.
# Não executar sysctl dentro do contêiner.

# Limpa as regras anteriores
iptables -F
iptables -X

# Políticas padrão: bloquear entradas e encaminhamentos
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Permite comunicação local
iptables -A INPUT -i lo -j ACCEPT

# Permite respostas de conexões já estabelecidas
iptables -A INPUT \
  -m conntrack \
  --ctstate ESTABLISHED,RELATED \
  -j ACCEPT

iptables -A FORWARD \
  -m conntrack \
  --ctstate ESTABLISHED,RELATED \
  -j ACCEPT

# Permite que a LAN cliente acesse o Nginx na DMZ pela porta HTTP
iptables -A FORWARD \
  -s 172.26.10.0/24 \
  -d 172.26.30.10 \
  -p tcp \
  --dport 80 \
  -m conntrack \
  --ctstate NEW \
  -j ACCEPT

# Registra tráfego encaminhado que não foi permitido.

iptables -A FORWARD \
  -m limit \
  --limit 5/min \
  --limit-burst 10 \
  -j LOG \
  --log-prefix "FIREWALL DROP: " \
  --log-level 4 || echo "[firewall] AVISO: alvo LOG não suportado neste kernel; seguindo sem LOG."

echo "[firewall] ip_forward = $(cat /proc/sys/net/ipv4/ip_forward)"
echo "[firewall] Regras aplicadas:"
iptables -L -n -v

echo "[firewall] Política FORWARD: DROP."
echo "[firewall] LAN Cliente (172.26.10.0/24) -> Nginx DMZ (172.26.30.10:80) liberado."

# Mantém o contêiner ativo
exec tail -f /dev/null
