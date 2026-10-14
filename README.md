# Lab Firewall Linux - Netfilter e iptables

Ambiente simples para o trabalho de Segurança da Informação.

## Cenário de aplicação

A simulação representa a TechStore Ceres, uma loja virtual de equipamentos de informática.

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

No meio fica o container do Firewall, que funciona como gateway real. Ele só deixa passar o que está liberado nas regras. O resto é bloqueado.

O cliente e os serviços da DMZ têm rotas estáticas apontando para o firewall. Assim o tráfego realmente passa por ele.

Tem um servidor web na DMZ (porta 80) e um PostgreSQL também na DMZ (porta 5432). O cliente consegue acessar só o web. O banco fica bloqueado de propósito.

## Como subir

Na pasta do projeto:

    docker compose up -d --build

O --build é necessário porque o firewall usa uma imagem própria (Dockerfile).

Para validar a sintaxe do compose antes de subir:

    docker compose config

Para ver se o firewall aplicou as regras:

    docker compose logs firewall

## Como testar

Entra no cliente:

    docker exec -it cliente sh

Instala as ferramentas de teste:

    apk add --no-cache curl nmap

Testes que devem funcionar:

    curl http://172.28.2.10
    ping -c 2 172.28.1.1
    ping -c 2 172.28.2.10

Testes que devem ser bloqueados:

    nmap -p 5432 172.28.2.20
    nmap -p 22,3306 172.28.2.10

## Para parar

    docker compose down

## Observações técnicas

- O firewall usa imagem própria com iptables, iproute2 e conntrack-tools já instalados.
- O script entrypoint.sh tem shebang #!/bin/sh e finais de linha Unix.
- Usa init: true e um loop persistente para o container não terminar.
- O depends_on espera o healthcheck do firewall (não só o start).
- Cliente e containers da DMZ têm rotas estáticas apontando para o firewall como gateway.
