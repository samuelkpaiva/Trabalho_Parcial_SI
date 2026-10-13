#!/bin/sh
# entrypoint.sh - Aplica regras iptables no container Firewall
# Comentários em cada linha para facilitar o entendimento

echo "[FIREWALL] Iniciando configuração..."

# Instala iptables e ferramentas básicas (Alpine vem limpo)
apk add --no-cache iptables iproute2 curl > /dev/null 2>&1

# ============================================================
# POLÍTICA PADRÃO: DROP em tudo (segurança por default)
# ============================================================
iptables -P INPUT DROP          # descarta qualquer pacote que chegue ao próprio firewall
iptables -P FORWARD DROP        # descarta qualquer pacote que tente atravessar (rotear)
iptables -P OUTPUT ACCEPT       # permite saída do próprio firewall (para updates etc.)

# ============================================================
# LIMPA REGRAS ANTIGAS (garante estado limpo a cada subida)
# ============================================================
iptables -F                     # limpa todas as regras das chains
iptables -X                     # remove chains customizadas (se houver)
iptables -t nat -F              # limpa tabela NAT

# ============================================================
# PERMITE LOOPBACK (comunicação interna do container)
# ============================================================
iptables -A INPUT -i lo -j ACCEPT

# ============================================================
# PERMITE CONEXÕES JÁ ESTABELECIDAS / RELACIONADAS
# (essencial para respostas de requisições)
# ============================================================
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# ============================================================
# REGRAS DE FORWARD (tráfego entre redes)
# ============================================================

# Cliente (172.28.1.0/24) -> DMZ Web (172.28.2.10) nas portas 80 e 443
iptables -A FORWARD -s 172.28.1.0/24 -d 172.28.2.10 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -s 172.28.1.0/24 -d 172.28.2.10 -p tcp --dport 443 -j ACCEPT

# Cliente NÃO pode acessar o banco (porta 5432) - regra explícita de DROP
# (já é DROP por default, mas deixamos explícito para documentação)
iptables -A FORWARD -s 172.28.1.0/24 -d 172.28.2.20 -p tcp --dport 5432 -j DROP

# Bloqueia qualquer outro tráfego do Cliente para a DMZ (além do que foi liberado)
# (já coberto pelo DROP default, mas reforça)
# iptables -A FORWARD -s 172.28.1.0/24 -d 172.28.2.0/24 -j DROP

# ============================================================
# PERMITE PING (ICMP) do Cliente para o Firewall e para a Web (opcional de lab)
# ============================================================
iptables -A INPUT -s 172.28.1.0/24 -p icmp -j ACCEPT
iptables -A FORWARD -s 172.28.1.0/24 -d 172.28.2.10 -p icmp -j ACCEPT

# ============================================================
# LOG de pacotes bloqueados (opcional - ajuda no debug)
# ============================================================
# iptables -A FORWARD -j LOG --log-prefix "FIREWALL-DROP: " --log-level 4

echo "[FIREWALL] Regras aplicadas com sucesso!"
echo "[FIREWALL] Política: DROP por default | Liberações explícitas ativas"

# Mantém o container vivo (sem isso ele sai)
exec sleep infinity
