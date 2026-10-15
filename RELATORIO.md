
# Relatório Técnico: Infraestrutura de Rede Segmentada com Docker Compose

**Repositório do projeto:**  
https://github.com/samuelkpaiva/Trabalho_Parcial_SI.git

## 1. Definição do case

### 1.1 Apresentação da empresa

Este projeto considera uma empresa fictícia de pequeno porte que utiliza computadores e sistemas digitais para realizar suas atividades. Os funcionários precisam acessar um sistema web, enquanto informações internas ficam armazenadas em um banco de dados.

Mesmo sendo uma situação simulada, esse cenário é comum em empresas que precisam manter seus serviços disponíveis e evitar que pessoas ou sistemas sem autorização tenham acesso aos dados.

### 1.2 Necessidades do negócio

A empresa precisa oferecer acesso ao serviço web aos usuários autorizados e, ao mesmo tempo, proteger o banco de dados. Para isso, os serviços não devem ficar todos na mesma rede, nem aceitar qualquer tipo de conexão.

A proposta é montar um ambiente de testes com uma estação cliente, um servidor web, um banco de dados e um firewall responsável por controlar a comunicação entre as redes.

### 1.3 Objetivo do projeto

O objetivo é criar uma infraestrutura de rede segmentada usando Docker Compose. A simulação permite observar como o firewall controla o tráfego, libera uma comunicação necessária para o teste e bloqueia conexões que não foram autorizadas.

## 2. Diagnóstico: cenário atual e proposta de solução

### 2.1 Problemas considerados no cenário inicial

Para este estudo, considera-se uma rede sem separação adequada entre os computadores dos funcionários, os servidores web e os bancos de dados. Quando os serviços ficam próximos demais na rede e não existem regras claras de acesso, uma falha em um componente pode facilitar o acesso a outros sistemas.

Os principais problemas considerados são:

- **Falta de segmentação:** equipamentos e serviços com funções diferentes podem acabar compartilhando a mesma rede, mesmo quando não precisam se comunicar diretamente.
- **Controle de acesso insuficiente:** serviços podem ficar disponíveis para origens que não deveriam acessá-los.
- **Risco para os dados:** permitir que as estações dos funcionários acessem diretamente o banco de dados aumenta a exposição das informações.
- **Dificuldade para investigar incidentes:** sem regras claras e sem acompanhar os contadores ou registros, fica mais difícil entender quais conexões foram tentadas e quais foram bloqueadas.
- **Permissões desnecessárias:** manter portas e caminhos de comunicação abertos sem necessidade aumenta a superfície de ataque.

Esses pontos descrevem o cenário hipotético utilizado no trabalho, não uma auditoria de uma empresa real.

### 2.2 Solução proposta

A solução divide o ambiente em três redes Docker:

| Segmento | Rede | Equipamento ou serviço |
|---|---|---|
| LAN Cliente | `172.26.10.0/24` | Estação cliente |
| Rede de Servidores | `172.26.20.0/24` | Banco de dados PostgreSQL |
| DMZ | `172.26.30.0/24` | Servidor web Nginx |

O firewall possui uma interface em cada rede e controla o tráfego encaminhado entre elas.

Os endereços utilizados são:

| Componente | Endereço IP |
|---|---|
| Cliente | `172.26.10.10` |
| Gateway da LAN Cliente | `172.26.10.254` |
| PostgreSQL | `172.26.20.10` |
| Gateway da Rede de Servidores | `172.26.20.254` |
| Nginx | `172.26.30.10` |
| Gateway da DMZ | `172.26.30.254` |

O firewall recebe a capacidade `NET_ADMIN` para administrar as regras do `iptables`. O encaminhamento de pacotes IPv4 é habilitado pela configuração `net.ipv4.ip_forward=1` no Docker Compose.

A política da cadeia `FORWARD` é `DROP` por padrão. Isso significa que uma conexão entre redes só é permitida quando existe uma regra explícita autorizando-a.

Nesta implementação, é liberado o acesso HTTP pela porta TCP 80 da LAN Cliente para o servidor Nginx na DMZ. O tráfego de retorno de conexões autorizadas também é permitido por meio do estado `ESTABLISHED,RELATED`.

Não existe uma regra liberando o acesso da estação cliente ao PostgreSQL, nem uma regra permitindo que o servidor web inicie conexões com o banco. Assim, o banco permanece separado do serviço web.

**Por que o banco fica fora da DMZ?** O enunciado cita o banco de dados como um possível serviço da DMZ, mas, neste projeto, ele foi colocado em uma rede de servidores separada. A DMZ abriga os serviços que precisam ser alcançados por outras redes (no caso, o servidor web) e, por isso, é a zona mais exposta. O banco guarda as informações internas da empresa e não precisa ser alcançado pela estação cliente. Mantê-lo em um segmento próprio, sem nenhuma regra de acesso liberada, é mais seguro do que misturá-lo ao serviço exposto. Além disso, o Nginx do laboratório serve apenas uma página estática de demonstração e não consulta o banco, por isso a regra DMZ → PostgreSQL permanece em `DROP`. Em uma aplicação real, em que o servidor web consultasse o banco, bastaria acrescentar uma regra explícita permitindo somente TCP/5432 do Nginx para o PostgreSQL.

### 2.3 Benefícios esperados

Com essa organização, o projeto demonstra como a segmentação e o bloqueio por padrão ajudam a reduzir comunicações desnecessárias.

A separação das redes facilita a aplicação de regras específicas, a análise dos contadores do firewall e a realização de testes de conectividade.

A solução é uma demonstração acadêmica dos conceitos de firewall e segmentação. Ela não deve ser considerada, sem outras medidas e validações, uma arquitetura pronta para uso em produção.

## 3. Matriz de regras de segurança do firewall

As regras abaixo descrevem a política de segurança adotada no laboratório. A cadeia `FORWARD` permite o tráfego de retorno das conexões autorizadas e bloqueia novas conexões que não correspondam às regras permitidas.

| Origem | Destino | Porta/protocolo | Ação | Justificativa |
|---|---|---|---|---|
| LAN Cliente (`172.26.10.0/24`) | Nginx (`172.26.30.10`) | TCP 80 | ACCEPT | Permitir acesso à página web de demonstração. |
| LAN Cliente | Nginx na DMZ | TCP 443 | DROP por padrão | HTTPS não está configurado nesta versão. |
| LAN Cliente | PostgreSQL (`172.26.20.10`) | TCP 5432 | DROP por padrão | Impedir acesso direto da estação cliente ao banco. |
| LAN Cliente | Redes de servidores e DMZ | TCP 22 | DROP por padrão | Não há necessidade de permitir SSH neste exercício. |
| LAN Cliente | DMZ | Outras portas | DROP por padrão | Restringir o acesso ao serviço HTTP autorizado. |
| DMZ | LAN Cliente | Novas conexões | DROP por padrão | Impedir conexões iniciadas pelo servidor web para a LAN Cliente. |
| DMZ | PostgreSQL (`172.26.20.10`) | TCP 5432 | DROP por padrão | Não permitir acesso ao banco iniciado pelo servidor web. |
| Conexões autorizadas | Origem da conexão | `ESTABLISHED,RELATED` | ACCEPT | Permitir o retorno de conexões já autorizadas. |
| Qualquer rede conectada | Outra rede conectada | Demais conexões encaminhadas | DROP por padrão | Aplicar a política de negação padrão. |

A política descrita não significa que cada porta bloqueada tenha uma regra individual. No `iptables`, a política `DROP` da cadeia `FORWARD` descarta o tráfego encaminhado que não corresponde a uma regra de aceitação.

**Observação:** as ações indicadas como `DROP por padrão` representam o comportamento esperado da política de encaminhamento. Elas não significam que exista necessariamente uma regra específica para cada porta da tabela.

## 4. Metodologia de testes e validação

Esta seção descreve, passo a passo, como o avaliador deve subir o ambiente e testá-lo. Os testes estão organizados em três grupos: preparação do ambiente (4.1 e 4.2), **testes positivos**, que mostram o que deve funcionar (4.3 a 4.5), e **testes negativos**, que mostram o que deve ser bloqueado (4.6). O item 4.7 resume os critérios de validação.

### 4.1 Componentes da infraestrutura

O projeto utiliza quatro componentes principais:

- **Cliente:** estação de teste no endereço `172.26.10.10`.
- **Firewall:** gateway com os endereços `172.26.10.254`, `172.26.20.254` e `172.26.30.254`.
- **Servidor Nginx:** servidor web no endereço `172.26.30.10`.
- **PostgreSQL:** banco de dados no endereço `172.26.20.10`.

Os containers e as redes são configurados pelo arquivo `docker-compose.yml`. As regras de filtragem ficam no arquivo `firewall/firewall.sh`, executado quando o container do firewall inicia.

### 4.2 Inicialização do ambiente

Na pasta do projeto, execute:

```bash
docker compose up -d --build
```

**Observação sobre o Docker Engine 28 ou superior:** a partir da versão 28, o Docker passou a descartar, no próprio host, pacotes roteados para o IP de um container quando eles chegam por uma rede diferente daquela do container. Como neste projeto o tráfego do cliente atravessa o firewall para chegar ao Nginx e ao banco, esse comportamento padrão faz as conexões expirarem (*timeout*) antes mesmo de chegarem às regras do `iptables`. Por isso, as três redes do `docker-compose.yml` definem a opção `com.docker.network.bridge.gateway_mode_ipv4: nat-unprotected`, que desativa essa filtragem do Docker nessas redes. Todo o controle de acesso entre os segmentos continua sendo feito pelo firewall do projeto.

Para verificar o estado dos serviços:

```bash
docker compose ps
```

Os quatro serviços devem estar em execução. Caso algum serviço não inicie corretamente, consulte os logs:

```bash
docker compose logs
```

Para consultar somente os logs do firewall (o nome do serviço no Compose é `firewall`; o nome do container é `firewall_gateway`):

```bash
docker compose logs firewall
```

O comando equivalente pelo nome do container é `docker logs firewall_gateway`. Ele mostra as mensagens do script de inicialização, incluindo a lista de regras aplicada.

### 4.3 Teste positivo 1: acesso autorizado ao Nginx

Execute o seguinte comando:

```bash
docker exec cliente_lan curl -i --connect-timeout 5 http://172.26.30.10
```

**Resultado esperado:** resposta HTTP `200 OK`, acompanhada do conteúdo HTML da página de demonstração.

Esse teste verifica se a estação cliente consegue acessar o Nginx por meio do caminho de rede autorizado.

### 4.4 Teste positivo 2: verificação das regras do firewall

Para listar as regras e os contadores de pacotes:

```bash
docker exec firewall_gateway iptables -L -n -v
```

Verifique os seguintes pontos:

- A cadeia `FORWARD` deve ter política `DROP`.
- Deve existir uma regra permitindo TCP/80 da LAN Cliente para `172.26.30.10`.
- O contador de pacotes da regra de TCP/80 deve aumentar depois do teste HTTP.
- O tráfego de retorno `ESTABLISHED,RELATED` deve estar autorizado.

O aumento dos contadores ajuda a confirmar que a regra foi utilizada durante o teste.

**Sobre a regra de LOG:** o firewall possui uma regra com o alvo `LOG` no final da cadeia `FORWARD`. As mensagens dessa regra são enviadas ao log do kernel do host (por exemplo, `dmesg` no Linux) e não aparecem em `docker logs`. Dependendo do kernel, o registro também pode não funcionar dentro do container. Por isso, a validação neste trabalho é feita principalmente pelos **contadores** do `iptables`. Caso o kernel não suporte o alvo `LOG`, o script informa um aviso e continua aplicando as demais regras.

### 4.5 Teste positivo 3: verificação das rotas da estação cliente

Execute:

```bash
docker exec cliente_lan ip route
```

A tabela de rotas deve permitir que a estação cliente encaminhe o tráfego destinado às redes de servidores e DMZ pelo gateway `172.26.10.254`, conforme a configuração do ambiente.

As rotas esperadas para as redes remotas são:

- `172.26.20.0/24` via `172.26.10.254`.
- `172.26.30.0/24` via `172.26.10.254`.

A rota padrão exibida pelo container pode depender da configuração interna do Docker.

### 4.6 Testes negativos: acessos que devem ser bloqueados

Os testes abaixo são executados a partir da estação cliente e devem ser **bloqueados** pelo firewall. Como a ação adotada é `DROP`, o esperado é que o Nmap classifique as portas como `filtered`, com o motivo `no-response`.

**Teste negativo 1: acesso direto ao PostgreSQL (TCP 5432):**

```bash
docker exec cliente_lan nmap -Pn -p 5432 --reason --host-timeout 10s 172.26.20.10
```

**Resultado esperado:** `5432/tcp filtered postgresql no-response`. O estado `filtered` indica que as sondagens não receberam resposta que permita determinar se a porta está aberta ou fechada, que é o comportamento do `DROP`. O `Host is up` exibido pelo Nmap aparece apenas porque foi usada a opção `-Pn`, que dispensa a descoberta de host.

**Teste negativo 2: HTTPS no Nginx (TCP 443):**

```bash
docker exec cliente_lan nmap -Pn -p 443 --reason --host-timeout 10s 172.26.30.10
```

**Resultado esperado:** `443/tcp filtered https no-response`, pois somente a porta 80 foi liberada para o Nginx.

**Teste negativo 3: SSH nas redes de servidores e DMZ (TCP 22):**

```bash
docker exec cliente_lan nmap -Pn -p 22 --reason --host-timeout 10s 172.26.20.10 172.26.30.10
```

**Resultado esperado:** porta 22 `filtered` nos dois destinos.

**Confirmação de que o bloqueio foi feito pelo firewall:** um resultado `filtered` isolado não prova que o firewall bloqueou, porque qualquer perda de pacotes no caminho produz o mesmo resultado. Depois dos testes negativos, consulte a cadeia `FORWARD`:

```bash
docker exec firewall_gateway iptables -L FORWARD -n -v
```

O contador de pacotes da política `DROP`, exibido no cabeçalho da cadeia (`Chain FORWARD (policy DROP N packets, ...)`), deve ter aumentado, indicando que os pacotes chegaram ao firewall e foram descartados por ele. Os pacotes da regra de LOG, que é limitada a poucas mensagens por minuto, também podem aparecer nessa listagem.

**Teste de controle: o banco está em funcionamento:** para mostrar que o `filtered` vem do firewall e não de um banco parado, verifique o serviço dentro do próprio container do PostgreSQL:

```bash
docker exec banco_dados pg_isready -U admin -d empresa
```

**Resultado esperado:** `accepting connections`. Assim, o banco está ativo e apenas inacessível a partir da LAN Cliente.

O comando `nmap` já vem instalado na imagem do container cliente (`cliente/Dockerfile`), portanto não é necessário instalar nada adicional.

### 4.7 Critérios de validação

A implementação estará de acordo com o objetivo do exercício quando os seguintes critérios forem verificados:

- O Nginx responder ao acesso HTTP iniciado pela estação cliente.
- A cadeia `FORWARD` estiver configurada com política `DROP`.
- O contador da regra TCP/80 aumentar depois do teste autorizado.
- A tentativa de acesso da estação cliente ao PostgreSQL (5432) for filtrada pelo firewall (`filtered`).
- As tentativas de acesso às portas 443 e 22 também forem filtradas.
- O contador da política `DROP` da cadeia `FORWARD` aumentar depois dos testes negativos.
- O comando `pg_isready` confirmar que o PostgreSQL está em execução.
- Os serviços não tiverem portas publicadas no host sem necessidade.
- Os endereços IP utilizados nos arquivos de configuração e na documentação forem consistentes.

Os resultados reais devem ser conferidos durante a execução. Saídas do terminal e capturas de tela podem ser anexadas à entrega como evidências dos testes.

## 5. Conclusão

O projeto demonstra como uma infraestrutura simples pode ser organizada em redes separadas para reduzir a comunicação desnecessária entre estações de trabalho, servidores web e banco de dados.

O firewall controla o tráfego entre os segmentos, libera o acesso HTTP necessário para a demonstração e bloqueia as demais conexões encaminhadas por padrão.

A simulação permite validar as regras por meio de testes de conectividade e da análise dos contadores do `iptables`. Dessa forma, o trabalho apresenta uma aplicação prática dos conceitos de segmentação de rede, controle de acesso e política de negação padrão, indicando também as melhorias necessárias para um ambiente de produção.
