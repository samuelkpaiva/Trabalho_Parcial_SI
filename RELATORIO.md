# Relatório Técnico: Infraestrutura de Rede Segmentada com Docker Compose

## 1. Definição do case

### 1.1 Apresentação da empresa

Este projeto considera uma empresa fictícia de pequeno porte que utiliza computadores e sistemas digitais para realizar suas atividades. Os funcionários precisam acessar um sistema web, enquanto algumas informações da empresa ficam armazenadas em um banco de dados interno.

Mesmo sendo uma situação simulada, esse cenário é comum em empresas que precisam manter seus serviços disponíveis e evitar que pessoas ou sistemas sem autorização tenham acesso aos dados.

### 1.2 Necessidades do negócio

A empresa precisa oferecer acesso ao serviço web aos usuários autorizados e, ao mesmo tempo, proteger o banco de dados. Para isso, os serviços não devem ficar todos na mesma rede, nem aceitar qualquer tipo de conexão.

A proposta é montar um ambiente de testes com uma estação cliente, um servidor web, um banco de dados e um firewall responsável por controlar a comunicação entre as redes.

### 1.3 Objetivo do projeto

O objetivo é criar uma infraestrutura de rede segmentada usando Docker Compose. A simulação permite observar como o firewall controla o tráfego, libera somente uma comunicação necessária para o teste e bloqueia conexões que não foram autorizadas.

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

A solução divide o ambiente em três redes Docker. A LAN Cliente, `172.20.10.0/24`, contém a estação usada nos testes. A Rede de Servidores, `172.20.20.0/24`, mantém o banco PostgreSQL. Já a DMZ, `172.20.30.0/24`, contém o servidor web Nginx.

O firewall possui uma interface em cada rede e controla o tráfego encaminhado entre elas. Para isso, o container recebe a capability `NET_ADMIN` e tem o encaminhamento de pacotes IPv4 habilitado por meio de `net.ipv4.ip_forward=1`.

A política de encaminhamento é `DROP` por padrão. Isso significa que uma conexão entre redes só é permitida quando existe uma regra explícita autorizando-a. Nesta versão, a única nova conexão liberada é o acesso HTTP pela porta TCP 80, da LAN Cliente para o Nginx na DMZ. O tráfego de retorno de conexões autorizadas também é permitido.

Não existe uma regra liberando o acesso da estação cliente ao PostgreSQL, nem uma regra permitindo que o servidor web inicie conexões com o banco. Dessa forma, o banco fica separado do serviço web e não é acessível diretamente pela LAN Cliente.

### 2.3 Benefícios esperados

Com essa organização, o projeto demonstra como a segmentação e o bloqueio por padrão ajudam a reduzir as comunicações desnecessárias. Também torna mais fácil testar regras específicas e observar seus contadores durante a execução.

A solução é uma demonstração acadêmica dos conceitos de firewall e segmentação. Ela não deve ser considerada, sem outras medidas e validações, uma arquitetura pronta para uso em produção.

## 3. Matriz de regras de segurança do firewall

As regras abaixo descrevem a política de segurança adotada no laboratório. O firewall libera apenas o tráfego necessário para o teste e bloqueia as demais conexões encaminhadas por padrão.

### Regra 1 — Acesso HTTP ao servidor web

- **Origem:** LAN Cliente (`172.20.10.0/24`).
- **Destino:** Nginx na DMZ (`172.20.30.10`).
- **Porta e protocolo:** TCP 80.
- **Ação:** ACCEPT.
- **Justificativa:** permitir que a estação de teste acesse a página web da empresa.

### Regra 2 — Acesso HTTPS não configurado

- **Origem:** LAN Cliente.
- **Destino:** Nginx na DMZ.
- **Porta e protocolo:** TCP 443.
- **Ação:** DROP por padrão.
- **Justificativa:** o HTTPS não foi configurado nesta versão do laboratório, portanto não há necessidade de liberar essa porta.

### Regra 3 — Acesso direto ao banco de dados

- **Origem:** LAN Cliente.
- **Destino:** PostgreSQL na rede de servidores (`172.20.20.10`).
- **Porta e protocolo:** TCP 5432.
- **Ação:** DROP por padrão.
- **Justificativa:** as estações dos funcionários não devem acessar diretamente o banco de dados.

### Regra 4 — Acesso administrativo por SSH

- **Origem:** LAN Cliente.
- **Destino:** redes de servidores ou DMZ.
- **Porta e protocolo:** TCP 22.
- **Ação:** DROP por padrão.
- **Justificativa:** não há necessidade de permitir administração remota por SSH neste exercício.

### Regra 5 — Outras portas da DMZ

- **Origem:** LAN Cliente.
- **Destino:** DMZ.
- **Porta e protocolo:** todas as portas que não foram liberadas explicitamente.
- **Ação:** DROP por padrão.
- **Justificativa:** limitar o acesso ao serviço que realmente precisa ser utilizado no teste.

### Regra 6 — Conexões iniciadas pela DMZ

- **Origem:** DMZ.
- **Destino:** LAN Cliente.
- **Porta e protocolo:** novas conexões, independentemente da porta.
- **Ação:** DROP por padrão.
- **Justificativa:** impedir que o servidor web inicie comunicações desnecessárias com as estações dos funcionários.

### Regra 7 — Acesso do servidor web ao banco

- **Origem:** DMZ.
- **Destino:** PostgreSQL (`172.20.20.10`).
- **Porta e protocolo:** TCP 5432.
- **Ação:** DROP por padrão.
- **Justificativa:** o servidor web não recebe permissão automática para acessar o banco. Caso uma aplicação intermediária seja criada, deverá ser definida uma regra específica para ela.

### Regra 8 — Tráfego de retorno

- **Origem e destino:** dependem da conexão previamente autorizada.
- **Porta e protocolo:** tráfego identificado como `ESTABLISHED,RELATED`.
- **Ação:** ACCEPT.
- **Justificativa:** permitir que as respostas de conexões autorizadas retornem ao solicitante sem liberar novas conexões indiscriminadamente.

### Regra 9 — Demais conexões encaminhadas

- **Origem e destino:** quaisquer redes conectadas ao firewall.
- **Porta e protocolo:** qualquer tráfego que não corresponda a uma regra autorizada.
- **Ação:** DROP por padrão.
- **Justificativa:** manter uma política de negação padrão e exigir uma justificativa para cada nova liberação.

A política descrita acima não significa que cada porta bloqueada tenha uma regra individual. No `iptables`, a política `DROP` da cadeia `FORWARD` descarta o tráfego encaminhado que não corresponde a uma regra de aceitação.

## 4. Implementação e validação

### 4.1 Componentes da infraestrutura

O projeto utiliza quatro componentes principais. A estação cliente, no endereço `172.20.10.10`, executa os testes de conectividade. O firewall usa os endereços `172.20.10.254`, `172.20.20.254` e `172.20.30.254`, um em cada rede. O servidor Nginx, em `172.20.30.10`, hospeda a página de demonstração. O PostgreSQL, em `172.20.20.10`, permanece na rede interna e não tem a porta publicada no computador anfitrião.

Os containers são configurados pelo arquivo `docker-compose.yml`. As regras do firewall ficam em `firewall/firewall.sh`, que é executado quando o container inicia.

### 4.2 Testes sugeridos

Depois de iniciar a infraestrutura com `docker compose up -d --build`, confira os containers com `docker compose ps`.

Em seguida, teste o acesso autorizado ao Nginx:

```bash
docker exec cliente_lan curl -i http://172.20.30.10
```

O resultado esperado é uma resposta HTTP `200 OK` acompanhada do conteúdo da página. Também é possível verificar as rotas configuradas na estação com `docker exec cliente_lan ip route`.

Para analisar as regras e os contadores do firewall, execute:

```bash
docker exec firewall_gateway iptables -L -n -v
```

Por fim, teste a tentativa de acesso à porta padrão do PostgreSQL:

```bash
docker exec cliente_lan nmap -Pn -p 5432 --reason 172.20.20.10
```

A conexão deve ser filtrada pela política do firewall. Para registrar a evidência corretamente, confira também as regras e os contadores do `iptables`. O fato de uma porta aparecer como fechada, isoladamente, não é suficiente para comprovar que o firewall bloqueou a tentativa.

O script também contém uma regra de log para parte do tráfego encaminhado que é bloqueado. Esses registros podem ser enviados ao log do kernel do host e não aparecer em `docker logs`. Por isso, os contadores do `iptables` são uma forma prática de acompanhar os testes.

### 4.3 Critérios de validação

A implementação será considerada de acordo com o objetivo do exercício quando:

- O Nginx responder ao acesso HTTP iniciado pela estação cliente.
- A cadeia `FORWARD` estiver configurada com política `DROP`.
- O contador da regra TCP/80 aumentar depois do teste autorizado.
- A tentativa de acesso da estação cliente ao PostgreSQL for filtrada.
- Nenhuma porta dos serviços estiver publicada no host por meio de `ports:`.

Os resultados reais devem ser conferidos durante a execução. As evidências, como saídas do terminal e capturas de tela, podem ser anexadas à entrega do trabalho.

## 5. Limitações e melhorias futuras

O projeto tem finalidade didática e demonstra o controle de tráfego entre containers. O servidor web não está publicado diretamente na rede física nem na Internet. Além disso, o acesso HTTP usa a porta 80 sem criptografia, o que é adequado apenas para o teste proposto.

Em uma versão mais próxima de um ambiente real, seria necessário configurar HTTPS, revisar as regras de tráfego de saída, proteger as credenciais, manter as imagens atualizadas e centralizar o monitoramento. Também seria recomendável reduzir as permissões concedidas aos containers que não precisam administrar a rede.

O banco de dados está isolado, mas ainda não existe uma aplicação intermediária autorizada a acessá-lo. Se essa parte for implementada no futuro, a regra deverá liberar apenas o endereço da aplicação e a porta necessária, sem abrir o banco para toda a DMZ.

## 6. Conclusão

O projeto mostra como uma infraestrutura simples pode ser organizada em redes separadas para reduzir a comunicação desnecessária entre estações de trabalho, servidores web e banco de dados. O firewall controla o tráfego entre os segmentos, libera o acesso HTTP necessário para a demonstração e bloqueia as demais conexões encaminhadas por padrão.

A simulação também permite validar as regras na prática por meio de testes de conectividade e da análise dos contadores do `iptables`. Dessa forma, o trabalho apresenta uma aplicação dos conceitos de segmentação de rede, controle de acesso e política de negação padrão, deixando indicadas as melhorias necessárias para um ambiente de produção.
