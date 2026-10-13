# Lab Firewall Linux - Netfilter e iptables

Ambiente simples para o trabalho de Segurança da Informação.

## O que tem aqui

Duas redes isoladas:

- Rede do Cliente (172.28.1.0/24)
- Rede DMZ (172.28.2.0/24)

No meio fica o container do Firewall, que funciona como gateway. Ele só deixa passar o que está liberado nas regras. O resto é bloqueado.

Tem um servidor web na DMZ (porta 80) e um PostgreSQL também na DMZ (porta 5432). O cliente consegue acessar só o web. O banco fica bloqueado de propósito.

## Como subir

Na pasta do projeto:

```bash
docker compose up -d
```

Para ver se o firewall aplicou as regras:

```bash
docker logs firewall
```

## Como testar

Entra no cliente:

```bash
docker exec -it cliente sh
```

Instala as ferramentas de teste:

```bash
apk add --no-cache curl nmap
```

Testes que devem funcionar:

```bash
curl http://172.28.2.10
ping -c 2 172.28.1.1
ping -c 2 172.28.2.10
```

Testes que devem ser bloqueados:

```bash
nmap -p 5432 172.28.2.20
nmap -p 22,3306 172.28.2.10
```

## Para parar

```bash
docker compose down
```

## Observação

O container do firewall usa NET_ADMIN e tem o encaminhamento de pacotes ligado (ip_forward=1). As regras sobem sozinhas pelo script entrypoint.sh.
