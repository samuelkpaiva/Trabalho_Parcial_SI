# Infraestrutura de Rede Segmentada com Docker Compose

Projeto acadêmico que simula uma empresa com três segmentos de rede, um firewall Linux, um servidor web na DMZ e um banco PostgreSQL isolado.

## Arquitetura

| Segmento/componente | Endereço | Função |
|---|---|---|
| LAN Cliente | `172.20.10.0/24` | Estação de trabalho de teste |
| Estação cliente | `172.20.10.10` | `curl`, `nmap`, ferramentas de rede |
| Firewall — LAN | `172.20.10.254` | Gateway da LAN Cliente |
| Rede de Servidores | `172.20.20.0/24` | Serviços internos |
| Firewall — servidores | `172.20.20.254` | Gateway da rede interna |
| PostgreSQL | `172.20.20.10:5432` | Banco isolado, sem porta publicada no host |
| DMZ | `172.20.30.0/24` | Serviço web intermediário |
| Firewall — DMZ | `172.20.30.254` | Gateway da DMZ |
| Nginx | `172.20.30.10:80` | Página HTTP de demonstração |

## Regras implementadas

- `INPUT DROP`: bloqueia conexões novas destinadas ao próprio firewall, exceto loopback e tráfego de retorno.
- `FORWARD DROP`: bloqueia por padrão o tráfego roteado entre segmentos.
- Permite novas conexões TCP/80 da LAN Cliente (`172.20.10.0/24`) para o Nginx (`172.20.30.10`).
- Permite tráfego de retorno de conexões estabelecidas ou relacionadas.
- Não libera a LAN Cliente para a rede de servidores.
- Não libera a DMZ para o PostgreSQL.
- Registra, com limite de frequência, tráfego encaminhado que chega ao bloqueio padrão.
- Nenhum serviço publica portas no host (`ports:` não é usado).

**Nota:** a política `OUTPUT ACCEPT` permite tráfego originado pelo próprio firewall. Esta é uma simulação didática, não uma configuração pronta para produção.

## Requisitos

- Docker Engine com Docker Compose v2 (`docker compose`)
- Permissão para executar containers e configurar redes Docker

## Iniciar

Na pasta do projeto:

```bash
cp .env.example .env
```

Edite `.env` e troque a senha de exemplo. Depois:

```bash
docker compose up -d --build
docker compose ps
```

## Testes

### 1. Acesso autorizado ao Nginx

```bash
docker exec cliente_lan curl -i --connect-timeout 5 http://172.20.30.10
```

Resultado esperado: `HTTP/1.1 200 OK` e o HTML da página.

### 2. Verificar rotas da estação cliente

```bash
docker exec cliente_lan ip route
```

Devem existir rotas para `172.20.20.0/24` e `172.20.30.0/24` via `172.20.10.254`.

### 3. Verificar regras e contadores do firewall

```bash
docker exec firewall_gateway iptables -L -n -v
```

A cadeia `FORWARD` deve ter política `DROP`. Após o teste HTTP, o contador da regra TCP/80 deve aumentar.

### 4. Testar o bloqueio de acesso ao banco

```bash
docker exec cliente_lan nmap -Pn -p 5432 --reason --host-timeout 10s 172.20.20.10
```

A conexão deve ser filtrada pelo firewall. Confirme o contador/log da regra `FORWARD`; um resultado de porta fechada, isoladamente, não prova filtragem por firewall.

### 5. Ver logs do container

```bash
docker logs firewall_gateway
```

O alvo `LOG` do iptables escreve no log do kernel do host, e não necessariamente em `docker logs`. Para verificar contadores, use `iptables -L -n -v`; em Linux, os registros do kernel podem ser consultados com ferramentas como `dmesg` ou `journalctl -k`, dependendo das permissões e da configuração do host.

### 6. Encerrar o laboratório

```bash
docker compose down
```

Para remover também o volume de dados do PostgreSQL, use `docker compose down -v`. Isso apaga os dados persistidos do banco.

## Observações técnicas

- O firewall precisa estar conectado às três redes; os outros containers ficam conectados somente ao segmento necessário.
- O cliente e o Nginx recebem rotas estáticas para que o tráfego entre os segmentos retorne pelo firewall.
- `NET_ADMIN` é concedido apenas aos containers que configuram rotas ou regras de firewall. Na versão de laboratório, cliente e Nginx recebem essa capacidade para instalar rotas no início; em uma versão endurecida, configure as rotas por outro mecanismo e remova `NET_ADMIN` desses serviços.
- As redes Docker `bridge` não substituem um firewall de host e não protegem contra administradores do host ou containers privilegiados.
- O Nginx não está publicado para a rede física ou para a Internet. O acesso demonstrado é entre containers. A publicação externa exigiria um desenho e regras de entrada adicionais.
- A regra TCP/80 é HTTP sem TLS, adequada apenas para demonstração. Para uso real, configure HTTPS, autenticação, gestão de segredos, atualização de imagens, limites de recursos, logs centralizados e testes de segurança.

## Estrutura

```text
.
├── docker-compose.yml
├── .env.example
├── .gitignore
├── README.md
├── RELATORIO_TECNICO.md
├── cliente/
│   └── Dockerfile
├── firewall/
│   ├── Dockerfile
│   └── firewall.sh
└── dmz/
    ├── Dockerfile
    └── index.html
```

## Publicar no GitHub

Crie um repositório vazio no GitHub. Na pasta do projeto:

```bash
git init
git add .
git commit -m "Adiciona laboratório de rede segmentada com Docker Compose"
git branch -M main
git remote add origin https://github.com/SEU-USUARIO/SEU-REPOSITORIO.git
git push -u origin main
```

Substitua a URL pelo endereço real do seu repositório. Não envie o arquivo `.env` com senhas reais.
