# Bancos de Dados no Ubuntu Server — MySQL, PostgreSQL e SQL Server

> Instalação nativa no Ubuntu Server 22.04 LTS (VM Hyper-V).  
> Para instalação via Docker no home lab, veja: [linux-docker-homelab.md](linux-docker-homelab.md)  
> Contexto completo do projeto: [README principal](../../README.md)

---

## Por que instalar três bancos?

Cada banco tem um perfil diferente, e conhecer os três na prática — instalação, configuração, gestão de usuários, backup — é uma habilidade relevante para qualquer profissional de infraestrutura.

| Banco       | Perfil de uso                                          |
| ----------- | ------------------------------------------------------ |
| PostgreSQL  | Banco principal do Zabbix; robusto, open source, padrão em muitos sistemas corporativos |
| MySQL       | O banco mais comum em aplicações web (WordPress, sistemas internos legados) |
| SQL Server  | Banco do ERP corporativo (SQL Server 2017 no SRV-AD01); documentar a versão Linux para comparativo |

> **Nota:** o SQL Server do ambiente corporativo roda no Windows Server (SRV-AD01). Aqui documentamos a instalação da versão Linux — útil para ambientes onde não há licença Windows disponível.

---

## PostgreSQL 16

### Por que o PostgreSQL para o Zabbix?

O Zabbix suporta MySQL, PostgreSQL e Oracle. O PostgreSQL foi escolhido por performance em escrita intensiva — o Zabbix grava dados de monitoramento constantemente, e o PostgreSQL lida melhor com esse padrão de acesso do que o MySQL em volumes maiores.

### Instalação

```bash
# Adicionar o repositório oficial do PostgreSQL (sempre mais atualizado que o Ubuntu)
sudo apt install -y curl ca-certificates
sudo install -d /usr/share/postgresql-common/pgdg
curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail \
    https://www.postgresql.org/media/keys/ACCC4CF8.asc

sudo sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] \
    https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list'

sudo apt update
sudo apt install -y postgresql-16

# Verificar se o serviço iniciou
sudo systemctl status postgresql
```

### Configuração inicial

```bash
# Acessar o prompt do PostgreSQL como usuário postgres
sudo -u postgres psql

# Definir senha para o superusuário postgres
ALTER USER postgres WITH PASSWORD 'senha_forte_aqui';

# Sair
\q
```

### Criar banco e usuário para uma aplicação

```bash
sudo -u postgres psql
```

```sql
-- Criar usuário dedicado (nunca use postgres direto em aplicações)
CREATE USER app_usuario WITH PASSWORD 'senha_app';

-- Criar banco de dados
CREATE DATABASE app_banco OWNER app_usuario;

-- Conceder permissões
GRANT ALL PRIVILEGES ON DATABASE app_banco TO app_usuario;

-- Verificar
\l        -- lista os bancos
\du       -- lista os usuários
\q
```

### Permitir conexões remotas (se necessário)

Por padrão, o PostgreSQL só aceita conexões locais. Para permitir conexões de outros IPs da rede:

```bash
# Editar o arquivo de configuração principal
sudo nano /etc/postgresql/16/main/postgresql.conf
```
Altere a linha:
```
listen_addresses = 'localhost'
```
Para:
```
listen_addresses = '*'          # aceita de qualquer IP
# ou restrinja a uma faixa:
listen_addresses = '192.168.88.0/24'
```

```bash
# Editar o controle de acesso por host
sudo nano /etc/postgresql/16/main/pg_hba.conf
```
Adicione ao final:
```
# Permite conexão de qualquer host da rede local com senha
host    all    all    192.168.88.0/24    scram-sha-256
```

```bash
sudo systemctl restart postgresql
```

### Comandos de gestão do dia a dia

```bash
# Status do serviço
sudo systemctl status postgresql

# Iniciar / parar / reiniciar
sudo systemctl start postgresql
sudo systemctl stop postgresql
sudo systemctl restart postgresql

# Conectar a um banco específico
sudo -u postgres psql -d nome_do_banco

# Listar bancos
sudo -u postgres psql -c "\l"

# Listar usuários
sudo -u postgres psql -c "\du"

# Ver tamanho dos bancos
sudo -u postgres psql -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) FROM pg_database ORDER BY pg_database_size(pg_database.datname) DESC;"
```

### Backup e restauração

```bash
# Backup de um banco específico (formato texto)
sudo -u postgres pg_dump nome_do_banco > /backup/nome_do_banco_$(date +%Y%m%d).sql

# Backup de todos os bancos
sudo -u postgres pg_dumpall > /backup/todos_os_bancos_$(date +%Y%m%d).sql

# Restaurar
sudo -u postgres psql nome_do_banco < /backup/nome_do_banco_20260601.sql
```

---

## MySQL 8.0

### Instalação

```bash
# Instalar o MySQL Server
sudo apt install -y mysql-server

# Verificar status
sudo systemctl status mysql

# Habilitar para iniciar com o sistema (geralmente já vem habilitado)
sudo systemctl enable mysql
```

### Configuração inicial de segurança

```bash
# Script interativo que remove configurações inseguras padrão
sudo mysql_secure_installation
```

O script vai perguntar:
- **Validate Password Plugin:** recomendo `Y` — força senhas fortes
- **Change root password:** `Y` — defina uma senha forte
- **Remove anonymous users:** `Y`
- **Disallow root login remotely:** `Y` — root só localmente
- **Remove test database:** `Y`
- **Reload privilege tables:** `Y`

### Acessar o MySQL

```bash
# Com senha root definida:
mysql -u root -p

# Sem senha (se ainda não configurou):
sudo mysql
```

### Criar banco e usuário para uma aplicação

```sql
-- Criar banco de dados
CREATE DATABASE app_banco CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Criar usuário com acesso apenas ao banco criado
-- O '%' permite conexão de qualquer host; restrinja se preferir
CREATE USER 'app_usuario'@'%' IDENTIFIED BY 'senha_app';

-- Conceder permissões
GRANT ALL PRIVILEGES ON app_banco.* TO 'app_usuario'@'%';

-- Aplicar as mudanças
FLUSH PRIVILEGES;

-- Verificar
SHOW DATABASES;
SELECT user, host FROM mysql.user;

EXIT;
```

### Permitir conexões remotas

```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

Altere:
```
bind-address = 127.0.0.1
```
Para:
```
bind-address = 0.0.0.0
```

```bash
sudo systemctl restart mysql

# Abrir porta no firewall do Ubuntu (UFW)
sudo ufw allow from 192.168.88.0/24 to any port 3306
```

### Comandos de gestão do dia a dia

```bash
# Status
sudo systemctl status mysql

# Iniciar / parar / reiniciar
sudo systemctl start mysql
sudo systemctl stop mysql
sudo systemctl restart mysql

# Conectar
mysql -u root -p

# Ver bancos
SHOW DATABASES;

# Ver usuários
SELECT user, host FROM mysql.user;

# Ver tamanho dos bancos
SELECT table_schema AS banco,
       ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS tamanho_MB
FROM information_schema.tables
GROUP BY table_schema
ORDER BY tamanho_MB DESC;
```

### Backup e restauração

```bash
# Backup de um banco
mysqldump -u root -p nome_do_banco > /backup/nome_do_banco_$(date +%Y%m%d).sql

# Backup de todos os bancos
mysqldump -u root -p --all-databases > /backup/todos_$(date +%Y%m%d).sql

# Restaurar
mysql -u root -p nome_do_banco < /backup/nome_do_banco_20260601.sql
```

---

## SQL Server 2022 (Linux)

### Por que SQL Server no Linux?

O SQL Server roda no Linux desde a versão 2017 — suportando Ubuntu, RHEL e outras distribuições. Para ambientes que já usam SQL Server no Windows mas querem reduzir custos de licenciamento ou migrar para Linux gradualmente, é uma alternativa real.

A versão **Developer Edition** é gratuita e completa — mesmas funcionalidades da Enterprise, mas licenciada apenas para desenvolvimento e testes. É o que usamos aqui.

### Instalação

```bash
# Adicionar o repositório oficial da Microsoft
curl -sSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor \
    -o /usr/share/keyrings/microsoft-prod.gpg

curl -sSL https://packages.microsoft.com/config/ubuntu/22.04/mssql-server-2022.list \
    | sudo tee /etc/apt/sources.list.d/mssql-server-2022.list

sudo apt update

# Instalar o SQL Server 2022
sudo apt install -y mssql-server
```

### Configuração inicial

```bash
# Script de configuração — define edição, senha do SA e aceita o EULA
sudo /opt/mssql/bin/mssql-conf setup
```

O script vai perguntar:
- **Edição:** escolha `2` para Developer Edition (gratuita para desenvolvimento)
- **Aceitar o EULA:** `Yes`
- **Senha do SA:** defina uma senha forte (mínimo 8 caracteres, maiúscula, minúscula, número e símbolo)

```bash
# Verificar se o serviço iniciou
sudo systemctl status mssql-server

# Habilitar para iniciar com o sistema
sudo systemctl enable mssql-server
```

### Instalar as ferramentas de linha de comando (sqlcmd)

```bash
curl -sSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor \
    -o /usr/share/keyrings/microsoft-prod.gpg

curl -sSL https://packages.microsoft.com/config/ubuntu/22.04/prod.list \
    | sudo tee /etc/apt/sources.list.d/mssql-release.list

sudo apt update
sudo ACCEPT_EULA=Y apt install -y mssql-tools18 unixodbc-dev

# Adicionar o sqlcmd ao PATH permanentemente
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
source ~/.bashrc
```

### Conectar e criar banco

```bash
# Conectar como SA
sqlcmd -S localhost -U SA -P 'sua_senha' -C
```

```sql
-- Criar banco de dados
CREATE DATABASE AppBanco;
GO

-- Criar usuário
CREATE LOGIN app_usuario WITH PASSWORD = 'Senha@Forte123';
GO

USE AppBanco;
CREATE USER app_usuario FOR LOGIN app_usuario;
ALTER ROLE db_owner ADD MEMBER app_usuario;
GO

-- Verificar bancos
SELECT name FROM sys.databases;
GO

-- Sair
EXIT
```

### Permitir conexões remotas

```bash
# Abrir a porta 1433 no UFW
sudo ufw allow from 192.168.88.0/24 to any port 1433

# Confirmar que o SQL Server está ouvindo na porta
sudo ss -tlnp | grep 1433
```

### Comandos de gestão do dia a dia

```bash
# Status
sudo systemctl status mssql-server

# Iniciar / parar / reiniciar
sudo systemctl start mssql-server
sudo systemctl stop mssql-server
sudo systemctl restart mssql-server

# Conectar via sqlcmd
sqlcmd -S localhost -U SA -P 'sua_senha' -C

# Ver bancos
sqlcmd -S localhost -U SA -P 'sua_senha' -C -Q "SELECT name FROM sys.databases"

# Ver versão
sqlcmd -S localhost -U SA -P 'sua_senha' -C -Q "SELECT @@VERSION"
```

### Backup e restauração

```sql
-- Conectado via sqlcmd:

-- Backup completo
BACKUP DATABASE AppBanco
TO DISK = '/var/opt/mssql/backup/AppBanco_20260601.bak'
WITH FORMAT, COMPRESSION;
GO

-- Restaurar
RESTORE DATABASE AppBanco
FROM DISK = '/var/opt/mssql/backup/AppBanco_20260601.bak'
WITH REPLACE;
GO
```

```bash
# Criar pasta de backup com permissão correta
sudo mkdir -p /var/opt/mssql/backup
sudo chown mssql:mssql /var/opt/mssql/backup
```

---

## Comparativo rápido — quando usar cada banco

| Critério              | PostgreSQL         | MySQL              | SQL Server (Linux)        |
| --------------------- | ------------------ | ------------------ | ------------------------- |
| Licença               | Open source        | Open source (GPL)  | Gratuito só Dev Edition   |
| Performance em escrita| Excelente          | Boa                | Excelente                 |
| Performance em leitura| Excelente          | Excelente          | Excelente                 |
| Uso com Zabbix        | ✅ Recomendado      | ✅ Suportado        | ❌ Não suportado           |
| Uso com WordPress     | ✅ Suportado        | ✅ Padrão de mercado| ❌ Não suportado           |
| Integração .NET / ERP | Possível           | Possível           | ✅ Nativo                  |
| Ferramentas gráficas  | pgAdmin, DBeaver   | MySQL Workbench    | Azure Data Studio, SSMS   |
| Consumo de RAM        | Baixo              | Baixo              | Alto (mínimo ~1 GB)       |
| Curva de aprendizado  | Média              | Baixa              | Média                     |

---

## O que aprendi nessa etapa

A instalação dos três bancos em si não tem nenhum segredo — os repositórios oficiais são bem documentados e os pacotes instalam sem problemas no Ubuntu 22.04.

O que me ensinou algo foi trabalhar com os **três ao mesmo tempo na mesma máquina**. Cada banco usa uma porta diferente (PostgreSQL: 5432, MySQL: 3306, SQL Server: 1433), mas todos compartilham a RAM. Com 2 GB alocados na VM, rodar os três simultaneamente ficou apertado — o SQL Server sozinho pede mais de 1 GB.

A solução foi ajustar o limite de memória do SQL Server:

```bash
# Limitar o SQL Server a 512 MB de RAM
sudo /opt/mssql/bin/mssql-conf set memory.memorylimitmb 512
sudo systemctl restart mssql-server
```

Isso não é recomendado em produção, mas em um ambiente de laboratório com múltiplos serviços na mesma VM, é o que viabiliza o funcionamento de todos ao mesmo tempo.

---

## Tecnologias

`Ubuntu Server 22.04` `PostgreSQL 16` `MySQL 8.0` `SQL Server 2022 (Linux)` `sqlcmd` `pg_dump` `mysqldump` `UFW`

---

*Robson Andrade · [linkedin.com/in/robsonandradee](https://www.linkedin.com/in/robsonandradee) · robsonluisandrade@gmail.com*
