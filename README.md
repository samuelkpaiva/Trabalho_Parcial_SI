# Lab Firewall Linux - Netfilter e iptables

Ambiente simples para o trabalho de Segurança da Informação.

## Cenário de aplicação

A simulação representa a **TechStore Ceres**, uma loja virtual de equipamentos de informática.

Os funcionários (rede Cliente) precisam acessar o site e o sistema interno de consulta de produtos. O catálogo fica em um banco de dados PostgreSQL. Em um ambiente real sem segmentação, qualquer máquina da rede interna conseguiria tentar se conectar direto no banco, o que abre caminho para vazamento de dados, ataques de força bruta e movimentação lateral caso uma estação seja comprometida.

Problemas mapeados no cenário atual (sem firewall):

- Rede plana, sem separação entre estações de trabalho e servidores
- Banco de dados acessível por qualquer host da rede
- Falta de controle centralizado do tráfego
- Superfície de ataque maior do que o necessário

A proposta é segmentar a rede em duas zonas isoladas (Cliente e DMZ) e colocar um firewall no meio. O firewall só libera o acesso à porta 80 do servidor web. Qualquer tentativa de chegar no banco (porta 5432) ou em outras portas é bloqueada por padrão.

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
