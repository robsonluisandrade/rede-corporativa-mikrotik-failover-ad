# Docker no Home Lab — MySQL, PostgreSQL, SQL Server e Zabbix em Containers

> Ambiente de testes e aprendizado — notebook pessoal com Linux.  
> Para o ambiente corporativo (instalação nativa na VM): [ubuntu-server-bancos-de-dados.md](ubuntu-server-bancos-de-dados.md)  
> Contexto completo do projeto: [README principal](../../README.md)

---

## Por que Docker no home lab

O ambiente corporativo roda os serviços instalados nativamente — Zabbix e PostgreSQL direto no Ubuntu Server da VM. No home lab, a abordagem é diferente: tudo roda em containers Docker.

A razão é prática: um notebook com 4-8 GB de RAM não aguenta múltiplos serviços rodando ao mesmo tempo com conforto. Com Docker, cada serviço sobe só quando precisa, ocupa o que precisa e é descartável — se algo der errado, `docker rm` e recomeça do zero sem reinstalar nada.

Além disso, o Docker permite reproduzir rapidamente qualquer combinação de banco + versão + configuração para testar antes de aplicar no ambiente corporativo.

---

## O ambiente

| Componente      | Especificação                                   |
| --------------- | ----------------------------------------------- |
| Máquina         | Notebook pessoal — Samsung                      |
| Sistema         | Ubuntu (bare metal — sem VM)                    |
| RAM             | 4 GB (limitação real — influencia as escolhas)  |
| Docker          | Docker Engine + Docker Compose                  |
| Gerenciamento   | Docker CLI + Docker Compose                     |
| Containers      | MySQL, PostgreSQL, SQL Server, Zabbix           |

> **Nota sobre RAM:** com 4 GB, não rode todos os containers ao mesmo tempo. O SQL Server sozinho pede ~1,5 GB. A estratégia é subir só o que vai usar em cada sessão de trabalho.

---

## Parte 1 — Instalação do Docker

### Instalação do Docker Engine

Não use o `docker.io` do repositório padrão do Ubuntu — ele costuma estar desatualizado. Use o repositório oficial da Docker:

```bash
# Remover versões antigas (se houver)
sudo apt remove docker docker-engine docker.io containerd runc 2>/dev/null

# Instalar dependências
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

# Adicionar a chave GPG oficial da Docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Adicionar o repositório
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar o Docker Engine e o Compose plugin
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### Permitir executar Docker sem sudo

```bash
# Adicionar seu usuário ao grupo docker
sudo usermod -aG docker $USER

# Aplicar sem precisar fazer logout
newgrp docker

# Verificar
docker --version
docker compose version
```

### Verificar a instalação

```bash
# Testar com o container hello-world
docker run hello-world

# Listar containers em execução
docker ps

# Listar todos os containers (incluindo parados)
docker ps -a

# Listar imagens baixadas
docker images
```

---

## Parte 2 — Estrutura de pastas

Antes de criar os containers, organize uma pasta central para todos os projetos Docker. Isso facilita backups e manutenção:

```bash
mkdir -p ~/docker/{mysql,postgres,sqlserver,zabbix}
```

Cada subpasta terá um `docker-compose.yml` próprio + volumes persistentes. Assim é possível subir e derrubar cada serviço independentemente.

---

## Parte 3 — MySQL no Docker

### Subindo o MySQL

```bash
mkdir -p ~/docker/mysql
nano ~/docker/mysql/docker-compose.yml
```

```yaml
# ~/docker/mysql/docker-compose.yml
services:
  mysql:
    image: mysql:8.0
    container_name: mysql-lab
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: SenhaRoot@2026
      MYSQL_DATABASE: lab_banco
      MYSQL_USER: lab_usuario
      MYSQL_PASSWORD: SenhaLab@2026
    ports:
      - "3306:3306"       # host:container — acessa pela porta 3306 do notebook
    volumes:
      - ./dados:/var/lib/mysql    # persiste os dados fora do container
    command: --default-authentication-plugin=mysql_native_password
```

```bash
cd ~/docker/mysql

# Subir o container em background
docker compose up -d

# Verificar se subiu
docker compose ps

# Ver os logs
docker compose logs -f mysql
```

### Conectar ao MySQL

```bash
# Pelo terminal do container
docker exec -it mysql-lab mysql -u root -p
# Senha: SenhaRoot@2026

# De fora do container (com cliente mysql instalado no host)
mysql -h 127.0.0.1 -P 3306 -u root -p
```

### Comandos do dia a dia

```bash
# Subir
docker compose up -d

# Parar (mantém os dados)
docker compose stop

# Parar e remover o container (mantém os dados nos volumes)
docker compose down

# Remover tudo incluindo os dados
docker compose down -v

# Ver logs em tempo real
docker compose logs -f

# Entrar no container
docker exec -it mysql-lab bash

# Backup
docker exec mysql-lab mysqldump -u root -pSenhaRoot@2026 lab_banco > backup_mysql.sql

# Restaurar
docker exec -i mysql-lab mysql -u root -pSenhaRoot@2026 lab_banco < backup_mysql.sql
```

---

## Parte 4 — PostgreSQL no Docker

```bash
mkdir -p ~/docker/postgres
nano ~/docker/postgres/docker-compose.yml
```

```yaml
# ~/docker/postgres/docker-compose.yml
services:
  postgres:
    image: postgres:16
    container_name: postgres-lab
    restart: unless-stopped
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: SenhaPostgres@2026
      POSTGRES_DB: lab_banco
    ports:
      - "5432:5432"
    volumes:
      - ./dados:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
```

```bash
cd ~/docker/postgres
docker compose up -d
docker compose ps
```

### Conectar ao PostgreSQL

```bash
# Pelo terminal do container
docker exec -it postgres-lab psql -U postgres

# De fora (com psql instalado no host)
psql -h 127.0.0.1 -p 5432 -U postgres
```

```sql
-- Criar banco e usuário de teste
CREATE DATABASE teste_banco;
CREATE USER teste_user WITH PASSWORD 'teste_senha';
GRANT ALL PRIVILEGES ON DATABASE teste_banco TO teste_user;
\l
\q
```

### Comandos do dia a dia

```bash
# Subir / parar
docker compose up -d
docker compose stop

# Backup
docker exec postgres-lab pg_dump -U postgres lab_banco > backup_postgres.sql

# Restaurar
docker exec -i postgres-lab psql -U postgres lab_banco < backup_postgres.sql

# Logs
docker compose logs -f
```

---

## Parte 5 — SQL Server no Docker

> ⚠️ **RAM:** o SQL Server exige no mínimo 2 GB de RAM por container. Com 4 GB no notebook, não rode junto com outros containers pesados.

```bash
mkdir -p ~/docker/sqlserver
nano ~/docker/sqlserver/docker-compose.yml
```

```yaml
# ~/docker/sqlserver/docker-compose.yml
services:
  sqlserver:
    image: mcr.microsoft.com/mssql/server:2022-latest
    container_name: sqlserver-lab
    restart: unless-stopped
    environment:
      ACCEPT_EULA: "Y"
      MSSQL_SA_PASSWORD: "SenhaSA@Forte2026"
      MSSQL_PID: "Developer"          # edição gratuita para desenvolvimento
    ports:
      - "1433:1433"
    volumes:
      - ./dados:/var/opt/mssql/data
    # Limitar RAM para conviver com outros serviços no notebook com 4 GB
    deploy:
      resources:
        limits:
          memory: 1.5G
```

```bash
cd ~/docker/sqlserver

# A primeira vez demora — a imagem tem ~1.5 GB
docker compose up -d

# Acompanhar o log até aparecer "SQL Server is now ready for client connections"
docker compose logs -f sqlserver
```

### Conectar ao SQL Server

```bash
# Pelo terminal do container (sqlcmd)
docker exec -it sqlserver-lab /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U SA -P 'SenhaSA@Forte2026' -C

# De fora do container (com sqlcmd instalado no host ou via Azure Data Studio)
sqlcmd -S 127.0.0.1,1433 -U SA -P 'SenhaSA@Forte2026' -C
```

```sql
-- Criar banco de teste
CREATE DATABASE LabBanco;
GO

-- Usar o banco
USE LabBanco;
GO

-- Criar tabela de teste
CREATE TABLE Produtos (
    Id INT PRIMARY KEY IDENTITY,
    Nome NVARCHAR(100),
    Preco DECIMAL(10,2)
);
GO

-- Inserir dados
INSERT INTO Produtos (Nome, Preco) VALUES ('Produto A', 99.90);
GO

-- Consultar
SELECT * FROM Produtos;
GO

EXIT
```

### Comandos do dia a dia

```bash
# Subir / parar
docker compose up -d
docker compose stop

# Backup via sqlcmd dentro do container
docker exec sqlserver-lab /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U SA -P 'SenhaSA@Forte2026' -C \
    -Q "BACKUP DATABASE LabBanco TO DISK='/var/opt/mssql/data/LabBanco.bak' WITH FORMAT"

# Logs
docker compose logs -f
```

---

## Parte 6 — Zabbix no Docker

O Zabbix via Docker é útil para testes, aprender a configurar e experimentar versões novas antes de atualizar o ambiente corporativo. O stack completo precisa de três containers: banco de dados (PostgreSQL), servidor Zabbix e frontend web.

```bash
mkdir -p ~/docker/zabbix
nano ~/docker/zabbix/docker-compose.yml
```

```yaml
# ~/docker/zabbix/docker-compose.yml
services:

  postgres-zabbix:
    image: postgres:16
    container_name: zabbix-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: zabbix
      POSTGRES_PASSWORD: ZabbixSenha@2026
      POSTGRES_DB: zabbix
    volumes:
      - ./dados-postgres:/var/lib/postgresql/data
    networks:
      - zabbix-net

  zabbix-server:
    image: zabbix/zabbix-server-pgsql:ubuntu-7.0-latest
    container_name: zabbix-server
    restart: unless-stopped
    environment:
      DB_SERVER_HOST: postgres-zabbix
      POSTGRES_USER: zabbix
      POSTGRES_PASSWORD: ZabbixSenha@2026
      POSTGRES_DB: zabbix
      ZBX_HOSTNAME: Zabbix-Docker-Lab
    ports:
      - "10051:10051"          # porta do servidor Zabbix
    depends_on:
      - postgres-zabbix
    networks:
      - zabbix-net

  zabbix-web:
    image: zabbix/zabbix-web-apache-pgsql:ubuntu-7.0-latest
    container_name: zabbix-web
    restart: unless-stopped
    environment:
      DB_SERVER_HOST: postgres-zabbix
      POSTGRES_USER: zabbix
      POSTGRES_PASSWORD: ZabbixSenha@2026
      POSTGRES_DB: zabbix
      ZBX_SERVER_HOST: zabbix-server
      PHP_TZ: America/Manaus   # ajuste para o seu fuso (ex: America/Sao_Paulo)
    ports:
      - "8080:8080"            # acessa em http://localhost:8080
    depends_on:
      - zabbix-server
    networks:
      - zabbix-net

  zabbix-agent:
    image: zabbix/zabbix-agent2:ubuntu-7.0-latest
    container_name: zabbix-agent
    restart: unless-stopped
    environment:
      ZBX_HOSTNAME: Zabbix-Docker-Lab
      ZBX_SERVER_HOST: zabbix-server
    networks:
      - zabbix-net

networks:
  zabbix-net:
    driver: bridge
```

```bash
cd ~/docker/zabbix

# Subir todo o stack
docker compose up -d

# Acompanhar — aguardar o zabbix-server mostrar "server #0 started"
docker compose logs -f zabbix-server

# Verificar todos os containers do stack
docker compose ps
```

**Acesso ao frontend:**
```
http://localhost:8080
Usuário: Admin
Senha:   zabbix
```

> **Diferença importante:** neste ambiente Docker, a porta do frontend é `8080` (não 80 como na VM corporativa) para não conflitar com outros serviços que possam usar a porta 80 no notebook.

### Comandos do dia a dia

```bash
# Subir o stack inteiro
docker compose up -d

# Parar o stack inteiro (mantém dados)
docker compose stop

# Ver status de todos os containers
docker compose ps

# Ver logs de um container específico
docker compose logs -f zabbix-server
docker compose logs -f zabbix-web

# Reiniciar só o servidor (sem derrubar o banco)
docker compose restart zabbix-server

# Atualizar para nova versão (troca a tag da imagem e recria)
docker compose pull
docker compose up -d
```

---

## Parte 7 — Gerenciando múltiplos containers

### Ver o que está rodando

```bash
# Todos os containers ativos
docker ps

# Com uso de recursos em tempo real
docker stats

# Espaço em disco usado pelo Docker
docker system df
```

### Estratégia com 4 GB de RAM

Com pouca RAM, a regra é: **suba só o que vai usar agora**.

```bash
# Parar tudo que não está sendo usado
cd ~/docker/mysql && docker compose stop
cd ~/docker/sqlserver && docker compose stop

# Subir o que precisa
cd ~/docker/postgres && docker compose up -d
cd ~/docker/zabbix && docker compose up -d
```

### Limpeza periódica

```bash
# Remover containers parados
docker container prune

# Remover imagens não usadas
docker image prune

# Remover volumes órfãos (cuidado — apaga dados!)
docker volume prune

# Limpeza geral (tudo não usado)
docker system prune
```

---

## Comparativo — Docker vs Instalação Nativa

| Aspecto                  | Docker (home lab)           | Nativo (VM corporativa)          |
| ------------------------ | --------------------------- | -------------------------------- |
| Tempo para subir         | 30 segundos                 | Serviço já rodando               |
| Atualização de versão    | Trocar a tag da imagem      | apt upgrade + configurações      |
| Isolamento entre serviços| Total — cada container é isolado | Processos separados, porta própria |
| Consumo de RAM           | Leve (só o processo + overhead mínimo) | Leve                    |
| Persistência de dados    | Volumes mapeados no host    | Diretório do banco                |
| Facilidade de reset      | `docker compose down -v`    | Reinstalar o banco               |
| Indicado para produção   | Sim, com orquestração       | Sim                              |
| Indicado para testes     | ✅ Ideal                    | Funciona, mas mais pesado        |
| Curva de aprendizado     | Adicional (Docker/Compose)  | Mais direto                      |

**Conclusão prática:** Docker no home lab para testar, aprender e experimentar versões. Instalação nativa na VM corporativa para produção — menos camadas, mais previsível, mais fácil de dar suporte para quem vai herdar o servidor.

---

## O que aprendi nessa etapa

Trabalhar com Docker no home lab me ensinou duas coisas que não ficam claras na teoria.

A primeira é sobre **volumes**. Na primeira vez que rodei `docker compose down`, perdi todos os dados do banco — o container foi removido e os dados junto. O `-v` no `docker compose down -v` remove os volumes também. Sem a flag, os dados persistem. Com ela, some tudo. Aprendi isso da forma difícil, num banco de testes que levou 30 minutos para popular.

A solução foi mapear os volumes para pastas locais (`./dados:/var/lib/mysql`). Assim, mesmo que o container seja destruído, os arquivos do banco continuam na pasta do projeto. Backup fica trivial: é só copiar a pasta.

A segunda foi sobre **ordem de dependência**. No docker-compose do Zabbix, o servidor depende do banco, e o frontend depende do servidor. O `depends_on` garante a ordem de inicialização, mas não garante que o banco esteja *pronto para receber conexões* quando o servidor tentar conectar. O Zabbix server tentava conectar ao PostgreSQL antes do banco terminar de inicializar e falhava nos primeiros segundos.

A solução foi o `healthcheck` no container do PostgreSQL — o servidor Zabbix só inicia depois que o healthcheck confirma que o banco está aceitando conexões. Sem isso, é comum ver o container do Zabbix server reiniciando algumas vezes antes de estabilizar.

---

## Tecnologias

`Docker Engine` `Docker Compose` `MySQL 8.0` `PostgreSQL 16` `SQL Server 2022` `Zabbix 7.0 LTS` `Ubuntu` `Linux`

---

*Robson Andrade · [linkedin.com/in/robsonandradee](https://www.linkedin.com/in/robsonandradee) · robsonluisandrade@gmail.com*
