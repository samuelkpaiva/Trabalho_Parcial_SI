FROM alpine:3.22

RUN apk add --no-cache iptables iproute2

COPY firewall.sh /usr/local/sbin/firewall.sh
RUN chmod 750 /usr/local/sbin/firewall.sh

CMD ["/bin/sh", "/usr/local/sbin/firewall.sh"]
