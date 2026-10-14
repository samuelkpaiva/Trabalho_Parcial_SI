# Dockerfile do Firewall
# Imagem própria com as ferramentas necessárias já instaladas

FROM alpine:3.20

# Instala iptables, iproute2 e conntrack-tools
RUN apk add --no-cache \
    iptables \
    iproute2 \
    conntrack-tools \
    curl

# Copia o script de entrada
COPY entrypoint.sh /entrypoint.sh

# Garante permissão de execução
RUN chmod +x /entrypoint.sh

# Define o ponto de entrada
ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
