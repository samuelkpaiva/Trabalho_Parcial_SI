#!/bin/sh
# entrypoint.sh - Aplica regras iptables e mantém o container vivo
# Finais de linha Unix (LF) e shebang correto

set -e

echo "[FIREWALL] Iniciando configuração..."


# Habilita encaminhamento de pacotes

echo 1 > /proc/sys/net/ipv4/ip_forward

# Política padrão: DROP em tudo

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT


# Limpa regras antigas

iptables -F
iptables -X
iptables -t nat -F

# Permite loopback

iptables -A INPUT -i lo -j ACCEPT


# Permite conexões já estabelecidas e relacionadas

iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT


# Regras de FORWARD (tráfego entre redes)


# Cliente -> DMZ Web (portas 80 e 443)
iptables -A FORWARD -s 172.28.1.0/24 -d 172.28.2.10 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -s 172.28.1.0/24 -d 172.28.2.10 -p tcp --dport 443 -j ACCEPT

# Cliente -> DMZ DB (porta 5432) - bloqueio explícito
iptables -A FORWARD -s 172.28.1.0/24 -d 172.28.2.20 -p tcp --dport 5432 -j DROP

# Permite ICMP (ping) do Cliente para o Firewall e para a Web
iptables -A INPUT -s 172.28.1.0/24 -p icmp -j ACCEPT
iptables -A FORWARD -s 172.28.1.0/24 -d 172.28.2.10 -p icmp -j ACCEPT

echo "[FIREWALL] Regras aplicadas com sucesso."
echo "[FIREWALL] Política: DROP por default | Liberações explícitas ativas"
echo "[FIREWALL] Mantendo o container em execução..."

# Loop persistente - o container não pode terminar
while true; do
    sleep 3600
done
