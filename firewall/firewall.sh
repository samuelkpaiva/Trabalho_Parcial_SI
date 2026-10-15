
#!/bin/sh

set -e

echo "[firewall] Ativando roteamento IPv4..."

# O encaminhamento IPv4 é configurado pelo Docker Compose.
# Não executar sysctl dentro do contêiner.

# Limpa as regras anteriores
iptables -F
iptables -X

# Políticas padrão
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Permite tráfego local
iptables -A INPUT -i lo -j ACCEPT

# Permite respostas de conexões já estabelecidas
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Permite ICMP, incluindo ping para o firewall
iptables -I INPUT -p icmp -j ACCEPT

# Permite respostas de conexões encaminhadas
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Permite HTTP do cliente para o servidor Nginx na DMZ
iptables -A FORWARD \
    -s 172.26.10.0/24 \
    -d 172.26.30.10 \
    -p tcp --dport 80 \
    -m conntrack --ctstate NEW \
    -j ACCEPT

# Registra parte do tráfego encaminhado que será bloqueado
iptables -A FORWARD \
    -m limit --limit 5/min --limit-burst 10 \
    -j LOG --log-prefix "FIREWALL DROP: " --log-level 4

echo "[firewall] Regras aplicadas:"
iptables -L -n -v

echo "[firewall] Política FORWARD: DROP."
echo "[firewall] ICMP permitido para o firewall."
echo "[firewall] LAN Cliente (172.26.10.0/24) -> Nginx DMZ (172.26.30.10:80) liberado."
