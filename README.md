# Infraestrutura de Rede Segura com Docker Compose

Este projeto foi criado para demonstrar, na prática, como separar uma rede em partes diferentes e controlar a comunicação entre elas. A simulação representa uma empresa de pequeno porte que possui estações de trabalho, um servidor web e um banco de dados interno.

Toda a estrutura é executada localmente com Docker Compose. Assim, é possível testar as regras de rede sem precisar montar vários computadores ou servidores físicos.

## Como a rede foi organizada

A infraestrutura possui três redes separadas:

- **LAN Cliente (`172.20.10.0/24`):** contém a estação usada para executar os testes.
- **Rede de Servidores (`172.20.20.0/24`):** mantém o banco PostgreSQL, que não deve ser acessado diretamente pela estação cliente.
- **DMZ (`172.20.30.0/24`):** contém o servidor web Nginx. A DMZ funciona como uma área separada para o serviço web, sem colocar o banco de dados na mesma rede.

O firewall está conectado às três redes e controla o tráfego que passa de uma para outra. A estação cliente e o Nginx possuem rotas configuradas para que a comunicação entre segmentos passe pelo firewall.

## O que o firewall permite e bloqueia

As regras foram configuradas para bloquear, por padrão, o tráfego encaminhado entre as redes. A única nova conexão liberada neste exemplo é o acesso HTTP, pela porta TCP 80, da LAN Cliente para o servidor Nginx na DMZ.

O firewall também permite o tráfego de retorno de conexões autorizadas. Já o acesso da estação cliente ao banco PostgreSQL e as conexões iniciadas da DMZ para a rede interna não são liberados.

O container do firewall usa a capability `NET_ADMIN`, necessária para configurar as regras de rede, e habilita o encaminhamento IPv4 com `net.ipv4.ip_forward=1`.

## Arquivos do projeto

- `docker-compose.yml`: define os containers e as redes Docker.
- `cliente/Dockerfile`: prepara a estação de testes com ferramentas como `curl` e `nmap`.
- `firewall/Dockerfile`: instala as ferramentas necessárias para aplicar as regras de firewall.
- `firewall/firewall.sh`: configura o roteamento e as regras do `iptables`.
- `dmz/Dockerfile`: cria a imagem do servidor web.
- `dmz/index.html`: página simples usada para testar o acesso HTTP.
- `RELATORIO_TECNICO.md`: apresenta o contexto do projeto, os problemas considerados, a solução proposta e os testes.
- `.env.example`: exemplo de configuração da senha do banco de dados.

## Antes de iniciar

Você precisa ter o Docker instalado e uma versão do Docker Compose que aceite o comando `docker compose`.

Na pasta do projeto, copie o arquivo de exemplo das variáveis de ambiente:

```bash
cp .env.example .env
```

Abra o arquivo `.env` e altere a senha de exemplo. Não use a senha de demonstração em ambientes reais e não publique um arquivo `.env` com credenciais verdadeiras.

## Como iniciar a infraestrutura

No terminal, dentro da pasta do projeto, execute:

```bash
docker compose up -d --build
```

Para conferir se os containers iniciaram, use:

```bash
docker compose ps
```

## Como testar

Primeiro, teste se a estação consegue acessar a página hospedada no Nginx:

```bash
docker exec cliente_lan curl -i --connect-timeout 5 http://172.20.30.10
```

Se tudo estiver funcionando, a resposta deve incluir o status `HTTP/1.1 200 OK` e o conteúdo da página.

Para conferir as rotas da estação cliente, execute:

```bash
docker exec cliente_lan ip route
```

Para visualizar as regras do firewall e seus contadores:

```bash
docker exec firewall_gateway iptables -L -n -v
```

Também é possível testar a tentativa de acesso à porta padrão do PostgreSQL:

```bash
docker exec cliente_lan nmap -Pn -p 5432 --reason --host-timeout 10s 172.20.20.10
```

A intenção é que essa conexão seja filtrada pelo firewall. Para confirmar o resultado, confira também as regras e os contadores do `iptables`. Uma porta aparecer como fechada, por si só, não comprova que foi o firewall que bloqueou a conexão.

O script inclui uma regra de log para o tráfego encaminhado que é bloqueado. Esses registros são enviados ao log do kernel e podem não aparecer em `docker logs`. Para uma primeira verificação, consulte os contadores com `iptables -L -n -v`. Em sistemas Linux, os registros do kernel também podem estar disponíveis por meio de `dmesg` ou `journalctl -k`, dependendo da configuração e das permissões.

## Como encerrar

Para parar e remover os containers e as redes criadas pelo Compose, execute:

```bash
docker compose down
```

Se também quiser apagar o volume de dados do PostgreSQL, use:

```bash
docker compose down -v
```

Esse último comando remove os dados persistidos do banco. Use-o somente se não precisar deles.

## Alguns pontos importantes

Este é um laboratório didático, não uma configuração pronta para produção. O Nginx não está publicado diretamente no computador anfitrião nem na Internet; o teste de acesso é feito entre os containers.

A regra HTTP usa a porta 80 sem criptografia, por isso serve apenas para demonstrar o funcionamento. Em um ambiente real, seria necessário planejar HTTPS, revisar as regras de entrada e saída, proteger as credenciais, manter as imagens atualizadas e acompanhar os registros de segurança.

Nesta versão, o banco PostgreSQL fica isolado e não existe uma aplicação intermediária autorizada a acessá-lo. Caso essa aplicação seja adicionada no futuro, o firewall deverá permitir somente o endereço e a porta estritamente necessários.

## Como publicar no GitHub

Crie um repositório vazio no GitHub. Depois, abra o terminal na pasta do projeto e execute os comandos abaixo, substituindo a URL pela do seu repositório:

```bash
git init
git add .
git commit -m "Adiciona laboratório de rede segura com Docker Compose"
git branch -M main
git remote add origin https://github.com/SEU-USUARIO/SEU-REPOSITORIO.git
git push -u origin main
```

Antes de enviar os arquivos, confira se o `.env` não está sendo incluído. O `.gitignore` já está configurado para ignorá-lo.
