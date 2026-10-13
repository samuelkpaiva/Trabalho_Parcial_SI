# Relatório Técnico – Firewall Linux, Netfilter & iptables

**Disciplina:** Segurança da Informação  
**Instituição:** Instituto Federal Goiano – Campus Ceres  
**Tema:** Firewall Linux, Arquitetura Netfilter & Iptables  

---

## 1. Definição do Case

**Empresa fictícia:** TechStore Ceres – loja virtual de equipamentos de informática.

**Contexto do negócio:**  
A empresa possui um site institucional e um sistema interno de consulta de produtos. Os funcionários (rede Cliente) precisam acessar o servidor web da aplicação. O banco de dados que armazena o catálogo deve permanecer isolado e nunca ser acessado diretamente pelos clientes/funcionários.

**Serviços que precisam operar:**
- Servidor Web (Nginx) – porta 80/443
- Banco de dados PostgreSQL – porta 5432 (apenas uso interno futuro de aplicações)

---

## 2. Diagnóstico: Cenário Atual vs. Proposta de Solução

### Cenário Atual (Problemas Mapeados)
- Rede plana (todos os hosts na mesma rede lógica).
- Qualquer máquina consegue tentar conectar no banco de dados.
- Ausência de segmentação → aumento da superfície de ataque.
- Sem controle centralizado de tráfego (sem firewall de perímetro interno).

### Proposta de Solução
- Segmentação em duas redes bridge isoladas do Docker:
  - **LAN Cliente** (172.28.1.0/24)
  - **DMZ** (172.28.2.0/24)
- Container Firewall atua como gateway/roteador entre as duas redes.
- Políticas **DROP por padrão** + liberações explícitas (modelo de menor privilégio).
- Cliente só consegue acessar o servidor web; acesso ao banco é bloqueado.

---

## 3. Matriz de Regras de Segurança (Firewall)

| Origem          | Destino     | Porta/Protocolo | Ação   | Justificativa do Negócio                     |
|-----------------|-------------|-----------------|--------|----------------------------------------------|
| Rede Cliente    | DMZ (Web)   | TCP 80/443      | ACCEPT | Funcionários precisam acessar o sistema web  |
| Rede Cliente    | DMZ (DB)    | TCP 5432        | DROP   | Cliente não deve acessar o banco diretamente |
| Qualquer        | Qualquer    | Qualquer        | DROP   | Política padrão de segurança                 |
| Estabelecidas   | Qualquer    | Qualquer        | ACCEPT | Permite respostas das conexões legítimas     |

---

## 4. Metodologia de Testes e Validação

### Passo a passo para o avaliador

1. Subir o ambiente:
   ```bash
   docker compose up -d
   ```

2. Verificar se o firewall aplicou as regras:
   ```bash
   docker logs firewall
   ```

3. Entrar no cliente:
   ```bash
   docker exec -it cliente sh
   apk add --no-cache curl nmap
   ```

### Testes Positivos (devem funcionar)
- `curl http://172.28.2.10` → retorna a página HTML
- `ping -c 2 172.28.1.1` → responde
- `ping -c 2 172.28.2.10` → responde

### Testes Negativos (devem ser bloqueados)
- `nmap -p 5432 172.28.2.20` → porta filtrada / sem resposta
- `nmap -p 22,3306 172.28.2.10` → portas filtradas

---

## Observação técnica
O container Firewall possui `cap_add: [NET_ADMIN]` e `sysctl net.ipv4.ip_forward=1` conforme exigido para funcionar como roteador entre as redes Docker.
