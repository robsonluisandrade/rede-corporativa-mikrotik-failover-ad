# Infraestrutura de Servidores

> Série de documentação complementar ao projeto de reestruturação de rede corporativa.  
> Contexto completo: [README principal](../../README.md)

---

## O que está documentado aqui

Esta pasta cobre a camada de servidores do projeto — do sistema operacional aos serviços rodando em produção e em laboratório.

O projeto tem dois ambientes distintos, documentados separadamente:

**Ambiente corporativo:** Windows Server 2019 como base, Hyper-V para virtualização, VM Ubuntu Server para o Zabbix instalado nativamente com PostgreSQL.

**Home lab:** notebook pessoal com Linux, Docker para rodar MySQL, PostgreSQL, SQL Server e Zabbix em containers — ambiente de testes, aprendizado e experimentação antes de aplicar no corporativo.

---

## Arquivos desta pasta

| Arquivo | O que cobre |
| ------- | ----------- |
| [`windows-server-hyper-v.md`](windows-server-hyper-v.md) | Instalação do Windows Server 2019 (Desktop Experience), ativação do Hyper-V, criação do Virtual Switch externo, criação e configuração da VM Ubuntu Server 22.04 |
| [`ubuntu-server-bancos-de-dados.md`](ubuntu-server-bancos-de-dados.md) | Instalação nativa de PostgreSQL 16, MySQL 8.0 e SQL Server 2022 no Ubuntu Server — configuração, gestão de usuários, backup e comandos do dia a dia |
| [`zabbix-instalacao.md`](zabbix-instalacao.md) | Instalação completa do Zabbix 7.0 LTS com PostgreSQL, configuração do frontend web, adição dos 12 hosts monitorados (MikroTik, AD, NAS, PCs, impressoras), instalação do Agent 2 nos PCs Windows e configuração de alertas por e-mail |
| [`linux-docker-homelab.md`](linux-docker-homelab.md) | Docker Engine + Docker Compose no Linux, containers de MySQL, PostgreSQL, SQL Server e Zabbix, estratégia de volumes persistentes, gestão de recursos com RAM limitada e comparativo Docker vs instalação nativa |

---

## Relação entre os ambientes

```
AMBIENTE CORPORATIVO
│
├── SRV-AD01 (Windows Server 2019)
│   ├── Active Directory + DNS
│   ├── SQL Server 2017 (ERP + Sistema de Ponto)
│   ├── RustDesk Server
│   ├── Tailscale
│   └── Hyper-V
│       └── VM: SRV-Zabbix (Ubuntu Server 22.04)
│           ├── Zabbix Server 7.0 LTS
│           ├── PostgreSQL 16
│           └── Apache 2 (frontend web)
│
HOME LAB (notebook pessoal — Linux)
│
└── Docker Engine
    ├── mysql-lab         (MySQL 8.0)
    ├── postgres-lab      (PostgreSQL 16)
    ├── sqlserver-lab     (SQL Server 2022 Developer)
    └── zabbix stack
        ├── zabbix-postgres
        ├── zabbix-server
        ├── zabbix-web
        └── zabbix-agent
```

---

## Por onde começar

Se o objetivo é reproduzir o ambiente corporativo:

1. [`windows-server-hyper-v.md`](windows-server-hyper-v.md) — instalar o Windows Server, ativar o Hyper-V e criar a VM
2. [`ubuntu-server-bancos-de-dados.md`](ubuntu-server-bancos-de-dados.md) — instalar o PostgreSQL na VM (os outros bancos são opcionais)
3. [`zabbix-instalacao.md`](zabbix-instalacao.md) — instalar e configurar o Zabbix

Se o objetivo é testar localmente sem infraestrutura:

1. [`linux-docker-homelab.md`](linux-docker-homelab.md) — instalar o Docker e subir qualquer serviço em minutos

---

*Robson Andrade · [linkedin.com/in/robsonandradee](https://www.linkedin.com/in/robsonandradee) · robsonluisandrade@gmail.com*
