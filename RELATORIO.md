# Relatório Técnico — Infraestrutura de Rede Segmentada e Segura com Docker Compose

## 1. Definição do Case

### 1.1 Descrição da empresa

O estudo considera uma empresa de pequeno porte que utiliza sistemas informatizados para suas atividades administrativas e operacionais. As estações de trabalho acessam um sistema web corporativo, enquanto serviços internos armazenam e processam informações importantes para o negócio.

A empresa é hipotética, mas representa situações comuns em organizações que precisam manter seus serviços disponíveis e proteger seus dados contra acessos não autorizados.

### 1.2 Contexto do negócio

A empresa precisa disponibilizar um sistema web aos funcionários e manter os serviços de dados protegidos. Uma eventual publicação para usuários externos deverá ocorrer por meio de regras de entrada controladas, não por exposição direta dos serviços internos.

Serviços considerados:
- Estação de trabalho para simular um funcionário.
- Firewall para controlar o tráfego entre redes.
- Servidor web Nginx na DMZ.
- PostgreSQL em uma rede interna isolada.
- Ferramentas para verificar conectividade, portas e regras de filtragem.

### 1.3 Objetivo

Projetar e simular, utilizando Docker Compose, uma infraestrutura de rede segmentada, com controle de acesso entre os componentes, política de bloqueio por padrão e liberações explícitas dos serviços necessários.

## 2. Diagnóstico: Cenário Atual vs. Proposta de Solução

### 2.1 Cenário atual: problemas mapeados

Considera-se inicialmente uma infraestrutura sem separação adequada por níveis de confiança. A ausência de segmentação e regras de acesso pode facilitar conexões indevidas, ampliar a exposição dos serviços e dificultar a investigação de incidentes.

Problemas considerados:
- **Falta de segmentação:** estações, serviços web e bancos de dados podem ficar expostos a caminhos de comunicação desnecessários.
- **Controle de acesso insuficiente:** serviços podem aceitar conexões de redes que não precisam utilizá-los.
- **Exposição de dados:** permitir acesso direto ao banco a partir das estações aumenta a superfície de ataque.
- **Monitoramento limitado:** sem contadores ou registros, é mais difícil analisar tentativas bloqueadas.
- **Privilégio excessivo:** permissões e portas desnecessárias aumentam o impacto de um comprometimento.

### 2.2 Proposta de solução

A solução utiliza Docker Compose para criar redes virtuais separadas e executar cada componente em um container independente:

- **LAN Cliente — `172.20.10.0/24`:** estação de trabalho.
- **Rede de Servidores — `172.20.20.0/24`:** PostgreSQL interno.
- **DMZ — `172.20.30.0/24`:** Nginx web.
- **Firewall:** container conectado aos três segmentos, com roteamento IPv4 e regras iptables.

A política de encaminhamento (`FORWARD`) é `DROP` por padrão. A única conexão nova liberada neste laboratório é TCP/80 da LAN Cliente para o Nginx na DMZ. O tráfego de retorno de conexões autorizadas é permitido por `ESTABLISHED,RELATED`. Não existe liberação de acesso da LAN Cliente ou da DMZ para o banco PostgreSQL.

A DMZ separa o serviço web do banco de dados. Assim, mesmo que o servidor web seja o destino de uma conexão autorizada, ele não recebe permissão automática para acessar o segmento de servidores.

### 2.3 Benefícios esperados

- Controle explícito do tráfego entre segmentos.
- Menor exposição do banco de dados.
- Demonstração prática de `DROP` por padrão.
- Facilidade para reproduzir e registrar testes.
- Base didática para evoluir a arquitetura com aplicação intermediária, HTTPS e monitoramento.

A simulação local não substitui auditoria de segurança ou configuração de produção.

## 3. Matriz de Regras de Segurança (Firewall)

| Origem | Destino | Porta/Protocolo | Ação | Justificativa |
|---|---|---|---|---|
| LAN Cliente | Nginx na DMZ | TCP 80 | ACCEPT | Permitir acesso HTTP ao site de teste. |
| LAN Cliente | Nginx na DMZ | TCP 443 | DROP por padrão | HTTPS não foi configurado neste laboratório. |
| LAN Cliente | PostgreSQL interno | TCP 5432 | DROP por padrão | Estações não devem consultar o banco diretamente. |
| LAN Cliente | Servidores internos | TCP 22 | DROP por padrão | Não há autorização para administração via SSH. |
| LAN Cliente | DMZ | Demais portas | DROP por padrão | Permitir apenas o serviço explicitamente autorizado. |
| DMZ | Rede Cliente | Novas conexões | DROP por padrão | Impedir conexões iniciadas pela DMZ para a LAN. |
| DMZ | PostgreSQL interno | TCP 5432 | DROP por padrão | O Nginx não deve acessar o banco diretamente. |
| Aplicação autorizada (futura) | PostgreSQL interno | TCP 5432 | Não implementado | Uma aplicação dedicada deverá receber uma regra específica se for adicionada. |
| Conexões autorizadas | Retorno da conexão | Estado `ESTABLISHED,RELATED` | ACCEPT | Permitir respostas das conexões autorizadas. |
| Qualquer origem encaminhada | Qualquer destino não autorizado | Qualquer protocolo | DROP por padrão | Aplicar a política de negação padrão. |

**Nota:** `DROP` por padrão significa que os pacotes encaminhados sem uma regra de aceitação são descartados. Não é necessário criar uma regra individual para cada porta bloqueada.

A tabela apresenta a política do laboratório. As regras explicitamente implementadas estão em `firewall/firewall.sh`.

## 4. Implementação e validação

### 4.1 Componentes

| Componente | Endereço | Função |
|---|---|---|
| Estação cliente | `172.20.10.10` | Executar testes com curl e nmap. |
| Firewall — interface cliente | `172.20.10.254` | Gateway da LAN Cliente. |
| Firewall — interface servidores | `172.20.20.254` | Gateway da rede interna. |
| PostgreSQL | `172.20.20.10:5432` | Banco de dados interno sem porta publicada no host. |
| Firewall — interface DMZ | `172.20.30.254` | Gateway da DMZ. |
| Nginx | `172.20.30.10:80` | Servidor web de teste. |

### 4.2 Procedimentos de teste

1. Iniciar a infraestrutura com `docker compose up -d --build`.
2. Conferir os containers com `docker compose ps`.
3. Consultar as rotas da estação com `docker exec cliente_lan ip route`.
4. Consultar regras e contadores com `docker exec firewall_gateway iptables -L -n -v`.
5. Testar o HTTP autorizado com `docker exec cliente_lan curl -i http://172.20.30.10`.
6. Testar a porta PostgreSQL com `docker exec cliente_lan nmap -Pn -p 5432 --reason 172.20.20.10`.
7. Reconsultar os contadores e registrar capturas de tela dos resultados.

### 4.3 Critérios de aceitação

- O Nginx responde com HTTP `200 OK` quando acessado da LAN Cliente.
- A política `FORWARD` está configurada como `DROP`.
- O contador da regra HTTP aumenta após o teste.
- O acesso da LAN Cliente ao PostgreSQL é filtrado.
- Nenhuma porta de serviço é publicada no host por meio de `ports:`.

Uma porta fechada ou a ausência de um serviço, isoladamente, não comprova o bloqueio do firewall. A validação deve considerar as regras e seus contadores.

## 5. Limitações e melhorias futuras

- O laboratório não publica o Nginx na rede física nem na Internet; ele demonstra comunicação entre segmentos Docker.
- A regra `OUTPUT ACCEPT` permite conexões originadas pelo firewall.
- O alvo `LOG` do iptables envia registros ao log do kernel do host; eles podem não aparecer em `docker logs`.
- Para produção, devem ser avaliados HTTPS, regras de saída, gestão segura de credenciais, atualizações, restrição de capacidades, monitoramento centralizado e testes adicionais.
- Em uma versão endurecida, configure rotas sem conceder `NET_ADMIN` aos containers cliente e Nginx.
- O PostgreSQL está isolado e não possui uma aplicação intermediária autorizada nesta versão. Se uma aplicação for criada, deve-se liberar apenas seu endereço de origem para TCP/5432.

## 6. Conclusão

O projeto demonstra uma arquitetura básica de defesa em profundidade por segmentação: a estação cliente, o servidor web e o banco de dados estão em redes diferentes, e o tráfego entre redes é encaminhado pelo firewall. A política de bloqueio por padrão reduz as conexões permitidas ao mínimo necessário para o teste HTTP, mantendo o banco de dados inacessível a partir da LAN Cliente e da DMZ.

Os resultados finais devem ser preenchidos com as evidências efetivamente obtidas durante a execução dos testes.
