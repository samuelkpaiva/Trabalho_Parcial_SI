#!/bin/sh
set -eu

CLIENT_NET="172.20.10.0/24"
SERVER_NET="172.20.20.0/24"
DMZ_NET="172.20.30.0/24"

echo "[firewall] Ativando roteamento IPv4..."
sysctl -w net.ipv4.ip_forward=1

# Laboratório descartável: limpa as regras FILTER padrão ao iniciar.
iptables -F
iptables -X

# Políticas padrão restritivas para tráfego destinado/encaminhado.
iptables -P INPUT DROP
iptables -P FORWARD DROP
# O firewall precisa resolver tarefas próprias, como inicialização.
iptables -P OUTPUT ACCEPT

# Loopback e tráfego de retorno destinado ao próprio firewall.
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Permite respostas de conexões que foram autorizadas anteriormente.
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# LAN Cliente -> Nginx na DMZ: somente HTTP/TCP 80.
iptables -A FORWARD \
  -s "$CLIENT_NET" -d 172.20.30.10 \
  -p tcp --dport 80 \
  -m conntrack --ctstate NEW \
  -j ACCEPT

# Não há liberação de LAN Cliente para a rede interna de servidores.
# Não há liberação da DMZ para o banco de dados (TCP 5432).
# Essas conexões são bloqueadas pela política FORWARD DROP.

# Registra tentativas encaminhadas bloqueadas, limitando o volume de logs.
iptables -A FORWARD \
  -m limit --limit 5/min --limit-burst 10 \
  -j LOG --log-prefix "FIREWALL DROP: " --log-level 4

echo "[firewall] Regras aplicadas:"
iptables -L -n -v
echo "[firewall] Política FORWARD: DROP; LAN Cliente -> Nginx DMZ TCP/80 liberado."

# Mantém o container vivo para inspeção e preserva as regras de kernel.
exec sleep infinity
