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

O banco de dados foi colocado em uma rede de servidores separada da DMZ de propósito: a DMZ abriga o serviço que precisa ser alcançado (o servidor web) e é a zona mais exposta, enquanto o banco guarda as informações internas e não deve ser acessado pelos clientes. O Nginx do laboratório serve apenas uma página estática e não consulta o banco, por isso não há regra liberando DMZ → PostgreSQL.

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
- Registrar parte do tráfego encaminhado que não foi permitido (regra `LOG`, limitada a poucas mensagens por minuto).

A regra de acesso HTTP permite a comunicação da rede `172.26.10.0/24` com o servidor `172.26.30.10`, usando a porta TCP 80.

As mensagens da regra `LOG` vão para o log do kernel do host (`dmesg` no Linux) e não aparecem em `docker logs`; dependendo do kernel, o registro pode nem funcionar dentro do container. Por isso, os testes deste projeto usam principalmente os contadores do `iptables` (`iptables -L -n -v`).

O PostgreSQL não possui uma porta publicada para acesso direto pelo computador host. O firewall também não libera novas conexões da rede dos clientes para o banco de dados.

## 6. Como executar o projeto

Antes de iniciar, verifique se o Docker e o Docker Compose estão instalados.

Na pasta que contém o arquivo `docker-compose.yml`, execute:

```bash
docker compose up -d --build
```

> **Docker Engine 28 ou superior:** o Docker passou a descartar, no host, pacotes roteados para o IP de um container quando chegam por outra rede. Como aqui o tráfego do cliente atravessa o firewall, isso causaria *timeout* nas conexões. Por isso as três redes do `docker-compose.yml` usam a opção `com.docker.network.bridge.gateway_mode_ipv4: nat-unprotected`. **Não remova essa opção.** O controle de acesso entre os segmentos continua sendo feito pelo firewall do projeto.

Opcionalmente, defina a senha do PostgreSQL em um arquivo `.env` (`POSTGRES_PASSWORD=sua_senha`); sem ele, é usada uma senha padrão de laboratório.

Para verificar o estado dos contêineres:

```bash
docker compose ps
```

Para visualizar os logs do firewall (mensagens do script de inicialização e lista de regras aplicada):

```bash
docker logs firewall_gateway
# ou, pelo nome do serviço no Compose:
docker compose logs firewall
```

Para encerrar o projeto:

```bash
docker compose down
```

## 7. Testes de conectividade

### Teste 1 (positivo) — Acesso HTTP ao servidor da DMZ

Execute:

```bash
docker exec cliente_lan curl -i --connect-timeout 5 http://172.26.30.10
```

Resultado esperado: resposta HTTP `200 OK` e exibição da página hospedada pelo Nginx.

Esse teste demonstra que o firewall permite o acesso HTTP autorizado entre a rede dos clientes e a DMZ.

### Teste 2 (positivo) — Verificar as rotas do cliente

Execute:

```bash
docker exec cliente_lan ip route
```

As rotas devem mostrar a rede local `172.26.10.0/24` e os caminhos para as redes `172.26.20.0/24` e `172.26.30.0/24` pelo gateway `172.26.10.254`.

### Teste 3 (positivo) — Conferir as regras do firewall

Execute:

```bash
docker exec firewall_gateway iptables -L -n -v
```

O resultado deve mostrar a política `DROP` na cadeia `FORWARD` e uma regra que permite o acesso TCP à porta 80 do servidor `172.26.30.10`, originado na rede `172.26.10.0/24`.

### Teste 4 (negativo) — Verificar o bloqueio de acesso ao PostgreSQL

Execute:

```bash
docker exec cliente_lan nmap -Pn -p 5432 --reason --host-timeout 10s 172.26.20.10
```

Resultado esperado: `5432/tcp filtered postgresql no-response`, indicando que o Nmap não recebeu resposta, que é o comportamento de um `DROP`.

Um `filtered` isolado não prova que foi o firewall que bloqueou. Para confirmar, veja o contador de pacotes da política `DROP` da cadeia `FORWARD`, que deve ter aumentado:

```bash
docker exec firewall_gateway iptables -L FORWARD -n -v
```

### Teste 5 (negativo) — HTTPS e SSH devem ser bloqueados

```bash
docker exec cliente_lan nmap -Pn -p 443 --reason --host-timeout 10s 172.26.30.10
docker exec cliente_lan nmap -Pn -p 22 --reason --host-timeout 10s 172.26.20.10 172.26.30.10
```

Resultado esperado: as portas 443 e 22 aparecem como `filtered` (`no-response`), pois somente a porta 80 do Nginx foi liberada.

### Teste 6 (controle) — O banco está em funcionamento

Para mostrar que o `filtered` do Teste 4 vem do firewall e não de um banco parado:

```bash
docker exec banco_dados pg_isready -U admin -d empresa
```

Resultado esperado: `accepting connections`.

## 8. Conclusão

O projeto demonstra como separar uma infraestrutura em diferentes segmentos de rede e utilizar regras de firewall para controlar a comunicação entre eles.

O teste HTTP confirma o acesso autorizado ao servidor web da DMZ, os testes de rotas e regras permitem verificar a configuração da infraestrutura, e os testes negativos, junto com os contadores do `iptables`, comprovam que as demais conexões são bloqueadas.

A atividade contribui para o aprendizado de redes de computadores, administração de sistemas Linux, Docker e conceitos básicos de segurança de redes.
