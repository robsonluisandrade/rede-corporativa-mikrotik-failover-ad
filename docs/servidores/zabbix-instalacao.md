# Zabbix 7.0 LTS — Instalação e Configuração Completa

> Instalado na VM Ubuntu Server 22.04 LTS (Hyper-V — IP 192.168.88.242).  
> Parte da série: [Infraestrutura de Servidores](windows-server-hyper-v.md)  
> Contexto completo do projeto: [README principal](../../README.md)

---

## Por que o Zabbix

Com a rede reestruturada, o failover funcionando, o domínio no ar e o QoS controlando a banda, ainda faltava uma camada: **saber o que está acontecendo antes que alguém reclame**.

Disco cheio no servidor, impressora offline, interface WAN caída às 2h da manhã — sem monitoramento, todos esses problemas são descobertos pelo sintoma, não pela causa. O Zabbix resolve isso: coleta métricas continuamente, compara com limiares configurados e dispara alertas antes que o problema afete os usuários.

A escolha pelo Zabbix em vez de Nagios, Prometheus ou Grafana foi direta: suporte nativo a SNMP (essencial para monitorar o MikroTik e o Synology), Agent 2 com instalador MSI para Windows, templates prontos para os dispositivos do ambiente, e uma comunidade ativa com documentação em português.

---

## O ambiente

| Componente       | Especificação                                        |
| ---------------- | ---------------------------------------------------- |
| Servidor         | Ubuntu Server 22.04 LTS — VM Hyper-V no SRV-AD01     |
| IP               | 192.168.88.242                                       |
| Zabbix           | 7.0 LTS                                              |
| Banco de dados   | PostgreSQL 16                                        |
| Web server       | Apache 2                                             |
| PHP              | 8.1                                                  |
| Frontend         | http://192.168.88.242/zabbix                         |

---

## Parte 1 — Instalação do Servidor Zabbix

### Passo 1 — Adicionar o repositório oficial do Zabbix

Não use o pacote do repositório padrão do Ubuntu — ele costuma ter versões desatualizadas. Use sempre o repositório oficial do Zabbix:

```bash
# Baixar e instalar o pacote de repositório
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-1+ubuntu22.04_all.deb
sudo dpkg -i zabbix-release_7.0-1+ubuntu22.04_all.deb

# Atualizar a lista de pacotes
sudo apt update
```

### Passo 2 — Instalar o Zabbix Server, Frontend e Agent

```bash
sudo apt install -y \
    zabbix-server-pgsql \
    zabbix-frontend-php \
    php8.1-pgsql \
    zabbix-apache-conf \
    zabbix-sql-scripts \
    zabbix-agent2
```

Explicação de cada pacote:
- `zabbix-server-pgsql` — o processo principal do Zabbix, compilado com suporte a PostgreSQL
- `zabbix-frontend-php` — interface web em PHP
- `php8.1-pgsql` — driver PHP para conectar ao PostgreSQL
- `zabbix-apache-conf` — configuração automática do Apache para o Zabbix
- `zabbix-sql-scripts` — scripts SQL para criar a estrutura do banco
- `zabbix-agent2` — agente de monitoramento local (para monitorar o próprio servidor)

### Passo 3 — Criar o banco de dados no PostgreSQL

```bash
# Acessar o PostgreSQL como superusuário
sudo -u postgres psql
```

```sql
-- Criar usuário do Zabbix
CREATE USER zabbix WITH PASSWORD 'ZabbixSenhaForte2026!';

-- Criar banco de dados
CREATE DATABASE zabbix OWNER zabbix;

-- Sair
\q
```

```bash
# Importar o schema inicial do Zabbix
# Este comando pode demorar 2-3 minutos — normal
zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | sudo -u zabbix psql zabbix
```

Verifique se a importação funcionou:
```bash
sudo -u postgres psql -d zabbix -c "\dt" | head -20
# Deve listar dezenas de tabelas (actions, alerts, auditlog, etc.)
```

### Passo 4 — Configurar o Zabbix Server

```bash
sudo nano /etc/zabbix/zabbix_server.conf
```

Localize e ajuste as linhas abaixo (remova o `#` das que estiverem comentadas):

```ini
DBHost=localhost
DBName=zabbix
DBUser=zabbix
DBPassword=ZabbixSenhaForte2026!

# Ajustes de performance para ambiente pequeno (12 hosts)
StartPollers=5
StartPingers=1
StartTrappers=5
CacheSize=32M
HistoryCacheSize=16M
TrendCacheSize=4M
ValueCacheSize=8M

# Log
LogFileSize=50
```

### Passo 5 — Configurar o fuso horário no PHP

```bash
sudo nano /etc/zabbix/apache.conf
```

Localize a linha do fuso horário e ajuste:
```apache
php_value date.timezone America/Manaus   # ajuste para o seu fuso
```

### Passo 6 — Configurar o Zabbix Agent local

```bash
sudo nano /etc/zabbix/zabbix_agent2.conf
```

Ajuste:
```ini
Server=127.0.0.1
ServerActive=127.0.0.1
Hostname=SRV-Zabbix
```

### Passo 7 — Iniciar e habilitar todos os serviços

```bash
sudo systemctl restart zabbix-server zabbix-agent2 apache2
sudo systemctl enable zabbix-server zabbix-agent2 apache2
```

### Passo 8 — Verificar se tudo subiu

```bash
# Verificar os três serviços
sudo systemctl status zabbix-server
sudo systemctl status zabbix-agent2
sudo systemctl status apache2

# Verificar se o servidor está escutando nas portas corretas
sudo ss -tlnp | grep -E "10051|10050|80"
# 10051 = porta do servidor Zabbix (recebe dados dos agentes ativos)
# 10050 = porta do agente
# 80    = Apache (frontend web)

# Verificar o log do servidor por erros
sudo tail -30 /var/log/zabbix/zabbix_server.log
```

---

## Parte 2 — Configuração pelo Frontend Web

### Primeiro acesso

Abra o navegador em qualquer máquina da rede:
```
http://192.168.88.242/zabbix
```

**Assistente de instalação (na primeira vez):**

1. **Verifique os pré-requisitos** — todos devem estar verdes. Se algum estiver vermelho, instale o pacote indicado.
2. **Configuração do banco:**
   - Database type: PostgreSQL
   - Host: localhost
   - Port: 5432
   - Database name: zabbix
   - User: zabbix
   - Password: (a senha definida no passo 3)
3. **Nome do servidor Zabbix:** `SRV-Zabbix`
4. **Fuso horário:** America/Manaus (ajuste para o seu fuso)
5. **Tema padrão:** Blue (ou Dark, dependendo da preferência)
6. **Concluir a instalação**

**Login inicial:**
```
Usuário: Admin
Senha:   zabbix
```

> ⚠️ Troque a senha imediatamente após o primeiro login:  
> Menu superior direito → Perfil → Senha

### Configuração de língua (opcional)

O Zabbix tem interface em português. Para ativar:
```bash
# Instalar o locale pt_BR
sudo locale-gen pt_BR.UTF-8
sudo update-locale

# Reiniciar o Apache
sudo systemctl restart apache2
```

No frontend: User Settings → Language → Portuguese (pt_BR)

---

## Parte 3 — Adicionando Hosts para Monitoramento

### Organizar em grupos antes de adicionar hosts

Antes de adicionar os hosts, crie grupos para organizar:

```
Configuração → Grupos de hosts → Criar grupo de hosts
```

Grupos recomendados para esse ambiente:
- `Rede` — MikroTik
- `Servidores` — SRV-AD01
- `NAS` — NAS-Synology
- `Workstations` — PCs do domínio
- `Impressoras` — Impressora-01, Impressora-05

### Adicionando o MikroTik (SNMP v2c)

```
Configuração → Hosts → Criar host
```

**Aba Host:**
| Campo | Valor |
|---|---|
| Nome do host | MikroTik-HEX |
| Grupos | Rede |
| Interface | SNMP — IP: 192.168.88.1 — Porta: 161 |
| Versão SNMP | SNMPv2 |
| Community | {$SNMP_COMMUNITY} |

**Aba Macros:**
| Macro | Valor |
|---|---|
| {$SNMP_COMMUNITY} | empresa-zabbix |

**Aba Templates:**
Busque e adicione: `MikroTik SNMP`

> Se o template não aparecer, importe-o:  
> `Configuração → Templates → Importar` — baixe de: https://git.zabbix.com/projects/ZBX/repos/zabbix/browse/templates/net/mikrotik

### Adicionando o Servidor AD (Zabbix Agent 2)

**Aba Host:**
| Campo | Valor |
|---|---|
| Nome do host | SRV-AD01 |
| Grupos | Servidores |
| Interface | Agent — IP: 192.168.88.234 — Porta: 10050 |

**Aba Templates:** `Windows by Zabbix Agent`

### Adicionando o NAS Synology (SNMP v2c)

**Aba Host:**
| Campo | Valor |
|---|---|
| Nome do host | NAS-Synology |
| Grupos | NAS |
| Interface | SNMP — IP: 192.168.88.235 — Porta: 161 |
| Versão SNMP | SNMPv2 |

**Aba Macros:** `{$SNMP_COMMUNITY}` = `empresa-zabbix`

**Aba Templates:** `Synology DiskStation by SNMP`

### Adicionando os PCs do domínio (Zabbix Agent 2)

Repita para cada PC, ajustando o nome e o IP:

| Nome do host     | IP              |
| ---------------- | --------------- |
| PC-Comercial     | 192.168.88.155  |
| PC-Compras       | 192.168.88.156  |
| PC-Faturamento   | 192.168.88.157  |
| PC-Financeiro    | 192.168.88.158  |
| PC-Administracao | 192.168.88.159  |
| PC-Laboratorio   | 192.168.88.160  |
| PC-Qualidade     | 192.168.88.161  |

Para cada um:
- Interface: Agent — IP correspondente — Porta: 10050
- Template: `Windows by Zabbix Agent`

### Adicionando as impressoras (SNMP / ICMP)

**Aba Host:**
| Campo | Valor |
|---|---|
| Nome do host | Impressora-01 |
| Grupos | Impressoras |
| Interface | SNMP — IP: 192.168.88.225 — Porta: 161 |
| Versão SNMP | SNMPv2 |

**Aba Macros:** `{$SNMP_COMMUNITY}` = `public`

**Aba Templates:** `Printer by SNMP`

> Se a impressora não responder via SNMP, adicione também uma interface ICMP e use o template `ICMP Ping` — pelo menos detecta quando a impressora vai offline.

---

## Parte 4 — Instalação do Zabbix Agent 2 nos PCs Windows

Execute em cada PC do domínio como Administrador.

### Download

```
https://www.zabbix.com/download_agents
Versão: 7.0 LTS | OS: Windows | Componente: Agent 2 | Arquitetura: amd64
```

### Instalação silenciosa via PowerShell (recomendada)

```powershell
# Substitua PC-Comercial pelo hostname exato de cada máquina
msiexec /i zabbix_agent2-7.0.0-windows-amd64-openssl.msi /qn `
    SERVER=192.168.88.242 `
    SERVERACTIVE=192.168.88.242 `
    HOSTNAME=PC-Comercial `
    ENABLEPATH=1

# Verificar se o serviço subiu
Get-Service -Name 'Zabbix Agent 2'

# Iniciar se necessário
Start-Service -Name 'Zabbix Agent 2'
Set-Service -Name 'Zabbix Agent 2' -StartupType Automatic
```

### Liberar a porta no Windows Firewall

```powershell
New-NetFirewallRule -DisplayName 'Zabbix Agent 2' `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 10050 `
    -Action Allow `
    -Profile Domain,Private
```

### Verificar a comunicação pelo servidor Zabbix

```bash
# No servidor Zabbix (Ubuntu), testar cada agente:
zabbix_get -s 192.168.88.155 -p 10050 -k system.hostname
# Resposta esperada: PC-Comercial

zabbix_get -s 192.168.88.155 -p 10050 -k system.uname
# Resposta: Windows versão do SO

zabbix_get -s 192.168.88.155 -p 10050 -k vm.memory.size[available]
# Resposta: bytes de RAM disponível
```

---

## Parte 5 — Alertas por E-mail

### Configurar o servidor de e-mail

```
Administração → Tipos de mídia → Email
```

| Parâmetro   | Valor                              |
| ----------- | ---------------------------------- |
| SMTP server | smtp.seudominio.com.br             |
| SMTP port   | 587                                |
| SMTP helo   | seudominio.com.br                  |
| De          | zabbix@seudominio.com.br           |
| Segurança   | STARTTLS                           |
| Autenticação| Nome de usuário + senha            |

Clique em **Testar** para confirmar o envio antes de salvar.

### Vincular e-mail ao usuário Admin

```
Administração → Usuários → Admin → Aba Mídia
→ Adicionar → Tipo: Email → Endereço: seu@email.com → Adicionar
```

### Gatilhos recomendados para ativar alertas

| Dispositivo       | Condição                          | Severidade |
| ----------------- | --------------------------------- | ---------- |
| Todos os hosts    | Host inacessível por 5 min        | Alta       |
| SRV-AD01          | CPU > 85% por 10 min              | Média      |
| SRV-AD01          | Espaço em disco C:\ < 10 GB       | Alta       |
| SRV-AD01          | Serviço "Active Directory" parado | Desastre   |
| NAS-Synology      | Disco com falha (SMART)           | Desastre   |
| NAS-Synology      | Uso de volume > 80%               | Média      |
| NAS-Synology      | Temperatura > 55°C                | Alta       |
| PCs do domínio    | Espaço em disco < 5 GB            | Alta       |
| PCs do domínio    | RAM disponível < 200 MB           | Média      |
| Impressoras       | Host inacessível (offline)        | Média      |
| MikroTik          | Interface WAN caída               | Alta       |
| MikroTik          | CPU > 90% por 5 min               | Média      |

Os templates incluídos já trazem a maioria desses gatilhos pré-configurados. Revise e ajuste os limiares para o seu ambiente em **Configuração → Hosts → [host] → Gatilhos**.

---

## Parte 6 — Verificação e Diagnóstico

### Checklist após configuração completa

```bash
# 1. Status dos serviços no servidor
sudo systemctl status zabbix-server zabbix-agent2 apache2 postgresql

# 2. Log do servidor — verificar erros
sudo tail -50 /var/log/zabbix/zabbix_server.log

# 3. Testar SNMP do MikroTik
snmpwalk -v2c -c empresa-zabbix 192.168.88.1 .1.3.6.1.2.1.1.1.0
# Esperado: STRING com o modelo e versão do RouterOS

# 4. Testar SNMP do Synology
snmpwalk -v2c -c empresa-zabbix 192.168.88.235 .1.3.6.1.2.1.1.1.0
# Esperado: STRING com o modelo do Synology

# 5. Testar agente no SRV-AD01
zabbix_get -s 192.168.88.234 -p 10050 -k system.hostname
# Esperado: SRV-AD01

# 6. Testar agente em um PC
zabbix_get -s 192.168.88.155 -p 10050 -k system.hostname
# Esperado: PC-Comercial

# 7. Testar SNMP das impressoras (community public)
snmpwalk -v2c -c public 192.168.88.225 .1.3.6.1.2.1.1.1.0
snmpwalk -v2c -c public 192.168.88.229 .1.3.6.1.2.1.1.1.0

# 8. Verificar porta do servidor Zabbix
sudo ss -tlnp | grep 10051
```

### No frontend — verificar status dos hosts

```
Monitoramento → Hosts
```

Todos os 12 hosts devem aparecer com o ícone verde (disponível). Um ícone vermelho indica problema de comunicação — verifique firewall, community SNMP ou serviço do agente.

### Problemas comuns e soluções

**Host aparece como inacessível mesmo com ping funcionando:**
```bash
# Verificar se a porta do agente está aberta no PC Windows
# Execute no servidor Zabbix:
nc -zv 192.168.88.155 10050
# Se der "Connection refused": regra de firewall faltando no Windows
# Se der "Connection timed out": firewall bloqueando antes de chegar
```

**SNMP timeout no MikroTik:**
```bash
# Verificar se as regras do bloco 8 estão aplicadas e posicionadas corretamente
# No MikroTik via Terminal:
/ip firewall filter print
# A regra "Zabbix — SNMP do roteador" deve aparecer ANTES das regras de drop
```

**Zabbix server não inicia:**
```bash
sudo tail -100 /var/log/zabbix/zabbix_server.log | grep -i error
# Erros comuns: senha errada do banco, banco não criado, porta 10051 já em uso
```

---

## O que aprendi nessa etapa

A instalação do Zabbix em si é direta — o repositório oficial funciona bem e o assistente web é claro. O que deu trabalho foi o **ajuste fino dos templates**.

Os templates do Zabbix vêm com limiares padrão pensados para servidores de grande porte: disco > 80% já dispara alerta crítico, RAM > 90% também. Em uma workstation com disco de 120 GB onde o usuário guarda muita coisa, 80% de uso é normal — não é uma emergência. Precisei revisar e ajustar os limiares de cada grupo de hosts para que os alertas fossem relevantes, não apenas barulho.

O segundo aprendizado foi sobre os **templates do MikroTik**. O template oficial do Zabbix para MikroTik (via SNMP) traz dezenas de itens de coleta, incluindo temperatura dos chips, throughput por interface, tabela de rotas e uso de memória. Mas alguns itens tinham OIDs ligeiramente diferentes da versão do RouterOS instalada — coletavam sem dados e geravam warnings no log. Resolvi desabilitando os itens que não retornavam dados no ambiente específico, sem remover o template inteiro.

A primeira semana de monitoramento trouxe dois alertas reais antes de qualquer usuário perceber — que já estão documentados no README principal.

---

## Tecnologias

`Zabbix 7.0 LTS` `PostgreSQL 16` `Apache 2` `PHP 8.1` `SNMP v2c` `Zabbix Agent 2` `Ubuntu Server 22.04` `PowerShell` `MikroTik SNMP` `Synology DSM`

---

*Robson Andrade · [linkedin.com/in/robsonandradee](https://www.linkedin.com/in/robsonandradee) · robsonluisandrade@gmail.com*
