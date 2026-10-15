# Infraestrutura de Rede Segura com Docker

## 1. Sobre o projeto

Este projeto simula a infraestrutura de rede de uma pequena empresa usando Docker e Docker Compose. O objetivo é demonstrar a segmentação de redes, o uso de um firewall e o controle de acesso entre diferentes setores da infraestrutura.

A rede foi dividida em três segmentos: rede dos clientes, rede dos servidores e DMZ, onde fica o servidor web.

## 2. Objetivos

- Separar os dispositivos em redes distintas.
- Configurar um firewall para controlar o tráfego entre as redes.
- Permitir o acesso HTTP do cliente ao servidor web da DMZ.
- Bloquear conexões não autorizadas entre os segmentos.
- Testar as regras de segurança usando ferramentas de rede.

## 3. Estrutura da rede

A infraestrutura utiliza três redes Docker independentes.

**Rede dos clientes — LAN Cliente**

- Sub-rede: `172.26.10.0/24`
- Cliente: `172.26.10.10`
- Gateway/Firewall: `172.26.10.254`

**Rede dos servidores**

- Sub-rede: `172.26.20.0/24`
- PostgreSQL: `172.26.20.10`
- Gateway/Firewall: `172.26.20.254`

**DMZ — Servidor Web**

- Sub-rede: `172.26.30.0/24`
- Nginx: `172.26.30.10`
- Gateway/Firewall: `172.26.30.254`

O firewall possui uma interface em cada rede e controla a comunicação entre os segmentos.

## 4. Tecnologias utilizadas

- Docker
- Docker Compose
- Linux
- iptables
- Nginx
- PostgreSQL
- curl
- Nmap

## 5. Regras do firewall

O firewall utiliza o `iptables` para controlar o tráfego de rede.

A política padrão da cadeia `INPUT` é bloquear conexões de entrada não autorizadas. A cadeia `FORWARD` também utiliza a política padrão de bloqueio.

As principais regras são:

- Permitir o tráfego pela interface de loopback.
- Permitir pacotes relacionados a conexões já estabelecidas.
- Permitir que a rede dos clientes acesse o Nginx da DMZ pela porta TCP 80.
- Bloquear outros encaminhamentos que não correspondam às regras autorizadas.
- Registrar parte do tráfego encaminhado que não foi permitido.

A regra de acesso HTTP permite a comunicação da rede `172.26.10.0/24` com o servidor `172.26.30.10`, usando a porta TCP 80.

O PostgreSQL não possui uma porta publicada para acesso direto pelo computador host. O firewall também não libera novas conexões da rede dos clientes para o banco de dados.

## 6. Como executar o projeto

Antes de iniciar, verifique se o Docker e o Docker Compose estão instalados.

Na pasta que contém o arquivo `docker-compose.yml`, execute:

```bash
docker compose up -d --build
```

Para verificar o estado dos contêineres:

```bash
docker compose ps
```

Para visualizar os logs do firewall:

```bash
docker logs firewall_gateway
```

Para encerrar o projeto:

```bash
docker compose down
```

## 7. Testes de conectividade

### Teste 1 — Acesso HTTP ao servidor da DMZ

Execute:

```bash
docker exec cliente_lan curl -i --connect-timeout 5 http://172.26.30.10
```

Resultado esperado: resposta HTTP `200 OK` e exibição da página hospedada pelo Nginx.

Esse teste demonstra que o firewall permite o acesso HTTP autorizado entre a rede dos clientes e a DMZ.

### Teste 2 — Verificar as rotas do cliente

Execute:

```bash
docker exec cliente_lan ip route
```

As rotas devem mostrar a rede local `172.26.10.0/24` e os caminhos para as redes `172.26.20.0/24` e `172.26.30.0/24` pelo gateway `172.26.10.254`.

### Teste 3 — Conferir as regras do firewall

Execute:

```bash
docker exec firewall_gateway iptables -L -n -v
```

O resultado deve mostrar a política `DROP` na cadeia `FORWARD` e uma regra que permite o acesso TCP à porta 80 do servidor `172.26.30.10`, originado na rede `172.26.10.0/24`.

### Teste 4 — Verificar o bloqueio de acesso ao PostgreSQL

Execute:

```bash
docker exec cliente_lan nmap -Pn -p 5432 --reason --host-timeout 10s 172.26.20.10
```

Resultado esperado: a porta pode aparecer como `filtered`, indicando que o Nmap não conseguiu determinar seu estado devido à filtragem ou à ausência de resposta.

Esse resultado é compatível com o bloqueio de conexões não autorizadas pelo firewall. Para confirmar o funcionamento do banco, é necessário realizar também um teste a partir da rede dos servidores.

## 8. Segurança e limitações

O projeto é um laboratório acadêmico e não deve ser considerado uma solução pronta para produção.

O ambiente demonstra segmentação de rede e filtragem de tráfego, mas não substitui uma avaliação completa de segurança.

A senha do PostgreSQL deve ser configurada localmente por meio do arquivo `.env`, criado a partir do `.env.example`. O arquivo `.env` não deve ser publicado no GitHub.

As redes Docker utilizam as sub-redes `172.26.10.0/24`, `172.26.20.0/24` e `172.26.30.0/24` para evitar sobreposição com outras redes já existentes no ambiente de desenvolvimento.

## 9. Conclusão

O projeto demonstra como separar uma infraestrutura em diferentes segmentos de rede e utilizar regras de firewall para controlar a comunicação entre eles.

O teste HTTP confirma o acesso autorizado ao servidor web da DMZ, enquanto os testes de rotas e regras permitem verificar a configuração da infraestrutura.

A atividade contribui para o aprendizado de redes de computadores, administração de sistemas Linux, Docker e conceitos básicos de segurança de redes.
