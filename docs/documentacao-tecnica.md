# Documentação Técnica de Infraestrutura

> Arquitetura completa implementada no projeto de reestruturação de rede corporativa.  
> *(Dados fictícios para fins de portfólio — empresa, dispositivos e MACs são exemplos)*

---

## 1. Identificação do Ambiente

| Atributo | Valor |
|---|---|
| Roteador | MikroTik hEX (RB750Gr3) — RouterOS 7.22.3 |
| Rede LAN | 192.168.88.0/24 — Gateway: 192.168.88.1 |
| Servidor AD | SRV-AD01 (192.168.88.234) |
| NAS | NAS-Synology (192.168.88.235) |
| Domínio | empresa.local |
| ERP | Sistema ERP corporativo (SQL Server 2017) |
| Sistema de Ponto | Sistema de Controle de Ponto |
| Acesso remoto TI | Tailscale VPN + RustDesk self-hosted |
| Backup nuvem | OneDrive (rotina) + Google Drive (cloud sync) |

---

## 2. Servidor AD — SRV-AD01

### Especificações

| Atributo | Valor |
|---|---|
| Hostname | SRV-AD01 |
| Sistema operacional | Windows Server 2019 |
| Função | Controlador de Domínio (DC), DNS, Servidor de Arquivos |
| IP | 192.168.88.234 — **fixo no SO, nunca via DHCP** |
| MAC* | AA:BB:CC:00:02:01 |
| DNS Forwarders | 1.1.1.1 e 8.8.8.8 |
| SQL Server | 2017 (ERP + Sistema de Ponto) |
| Tailscale | Instalado — login persistente, reconexão automática |
| RustDesk | Servidor instalado — gerencia acesso remoto das estações |

### Por que IP fixo no SO e não no DHCP?

O servidor AD é o ponto central de DNS da rede. Se o DHCP do MikroTik ficar indisponível por qualquer motivo, o servidor AD continua respondendo no mesmo IP — sem depender de nenhum outro serviço. A reserva DHCP no MikroTik existe apenas como documentação.

---

## 3. Usuários do Domínio — empresa.local

Gerenciado em: Ferramentas Administrativas → Usuários e Computadores do Active Directory

| Usuário (login) | Tipo | Obs |
|---|---|---|
| Administrador | Conta interna | Conta padrão do AD — uso restrito |
| usuario.ti | Usuário — TI | Administrador de TI |
| usuario.dir01 | Usuário — Diretoria | |
| usuario.dir02 | Usuário — Diretoria | |
| usuario.comercial | Usuário | |
| usuario.compras | Usuário | |
| usuario.faturamento | Usuário | |
| usuario.financeiro | Usuário | |
| usuario.administracao | Usuário | |
| usuario.laboratorio | Usuário | |
| usuario.qualidade | Usuário | |
| scanner | Usuário de serviço | Conta para digitalização — sem login interativo |
| Convidado | Conta interna | Desabilitada |

---

## 4. Grupos de Segurança

Prefixo `EmpresaGrp` identifica grupos corporativos criados para o projeto.

| Grupo | Finalidade |
|---|---|
| TODOSEmpresa | Grupo geral — todos os usuários da empresa |
| LABORATORIOEmpresa | Usuários do setor Laboratório |
| PORTARIAEmpresa | Usuários da Portaria |
| QUALIDADEEmpresa | Usuários do setor Qualidade/SGQ |
| RECEBIMENTOEmpresa | Usuários do setor Recebimento |

---

## 5. Computadores Ingressados no Domínio

| Nome da máquina | IP | MAC* | Setor |
|---|---|---|---|
| SRV-AD01 | 192.168.88.234 | AA:BB:CC:00:02:01 | Servidor AD (IP fixo no SO) |
| PC-Comercial | 192.168.88.155 | AA:BB:CC:03:00:01 | Comercial — Fibra |
| PC-Compras | 192.168.88.156 | AA:BB:CC:03:00:02 | Compras — Fibra |
| PC-Faturamento | 192.168.88.157 | AA:BB:CC:03:00:03 | Faturamento — Fibra |
| PC-Financeiro | 192.168.88.158 | AA:BB:CC:03:00:04 | Financeiro — Fibra |
| PC-Administracao | 192.168.88.159 | AA:BB:CC:03:00:05 | Administração — Fibra |
| PC-Laboratorio | 192.168.88.160 | AA:BB:CC:03:00:06 | Laboratório — Fibra |
| PC-Qualidade | 192.168.88.161 | AA:BB:CC:03:00:07 | Qualidade — Fibra |
| Notebook-Diretoria-01 | 192.168.88.120 | AA:BB:CC:04:00:01 | Diretoria — Fibra |
| Notebook-TI-01-cabo | 192.168.88.125 | AA:BB:CC:04:01:01 | TI (cabo) — Fibra |
| Notebook-TI-01-wifi | 192.168.88.127 | AA:BB:CC:04:01:03 | TI (Wi-Fi) — Fibra |
| Notebook-Diretoria-02-cabo | 192.168.88.134 | AA:BB:CC:04:02:07 | Diretoria — Fibra |
| Notebook-Diretoria-02-wifi | 192.168.88.135 | AA:BB:CC:04:02:08 | Diretoria — Fibra |

---

## 6. Infraestrutura de Rede

### 6.1 NAS Synology

| Atributo | Valor |
|---|---|
| Hostname | NAS-Synology |
| IP | 192.168.88.235 |
| MAC* | AA:BB:CC:00:01:01 |
| Internet | Starlink (saída preferencial para backup em nuvem) |
| Domínio | Ingressado no domínio empresa.local |
| Backup destino 1 | OneDrive — seg/qua/sex incremental, sáb/dom full |
| Backup destino 2 | Google Drive — Cloud Sync contínuo |
| WordPress | Instalado — MariaDB 10 + PHP 8.2 (portal em desenvolvimento) |

### 6.2 NVR e Câmeras

| Dispositivo | IP | MAC* | Obs |
|---|---|---|---|
| NVR-CFTV | 192.168.88.236 | AA:BB:CC:00:01:02 | Internet via Starlink |
| Camera-01 | 192.168.88.195 | AA:BB:CC:02:00:01 | Sem internet — rede local |
| Camera-02 | 192.168.88.196 | AA:BB:CC:02:00:02 | Sem internet — rede local |
| Camera-03 | 192.168.88.197 | AA:BB:CC:02:00:03 | Sem internet — rede local |
| Camera-04 | 192.168.88.198 | AA:BB:CC:02:00:04 | Sem internet — rede local |
| Camera-05 | 192.168.88.199 | AA:BB:CC:02:00:05 | Sem internet — rede local |
| Camera-06 | 192.168.88.200 | AA:BB:CC:02:00:06 | Sem internet — rede local |
| Camera-07 | 192.168.88.201 | AA:BB:CC:02:00:07 | Sem internet — rede local |
| Camera-08 | 192.168.88.202 | AA:BB:CC:02:00:08 | Sem internet — rede local |
| Camera-09 | 192.168.88.203 | AA:BB:CC:02:00:09 | Sem internet — rede local |
| Camera-10 | 192.168.88.204 | AA:BB:CC:02:00:10 | Sem internet — rede local |
| Camera-11 | 192.168.88.205 | AA:BB:CC:02:00:11 | Sem internet — rede local |
| Camera-12 | 192.168.88.206 | AA:BB:CC:02:00:12 | Sem internet — rede local |
| Camera-13 | 192.168.88.207 | AA:BB:CC:02:00:13 | Sem internet — rede local |
| Camera-14 | 192.168.88.208 | AA:BB:CC:02:00:14 | Sem internet — rede local |
| Camera-15 | 192.168.88.209 | AA:BB:CC:02:00:15 | Sem internet — rede local |
| Camera-16 | 192.168.88.210 | AA:BB:CC:02:00:16 | Sem internet — rede local |

### 6.3 Access Points e Portaria

| Dispositivo | IP | MAC* | Link |
|---|---|---|---|
| AP-Producao | 192.168.88.237 | AA:BB:CC:00:01:03 | Fibra |
| AP-Escritorio | 192.168.88.238 | AA:BB:CC:00:01:04 | Fibra |
| AP-Deposito | 192.168.88.239 | AA:BB:CC:00:01:05 | Fibra |
| AP-Portaria | 192.168.88.240 | AA:BB:CC:00:01:06 | Fibra |

### 6.4 Impressoras e Relógio de Ponto

| Dispositivo | IP | MAC* | Obs |
|---|---|---|---|
| Impressora-01 | 192.168.88.225 | AA:BB:CC:01:01:01 | Sem internet — rede local |
| Impressora-02 | 192.168.88.226 | AA:BB:CC:01:01:02 | Sem internet — rede local |
| Impressora-03 | 192.168.88.227 | AA:BB:CC:01:01:03 | Sem internet — rede local |
| Impressora-04 | 192.168.88.228 | AA:BB:CC:01:01:04 | Sem internet — rede local |
| Impressora-05 | 192.168.88.229 | AA:BB:CC:01:01:05 | Sem internet — rede local |
| Relogio-Ponto | 192.168.88.230 | AA:BB:CC:01:02:01 | **IP FIXO NO DISPOSITIVO** |

---

## 7. Links de Internet e Failover

| Link | Interface | Gateway | Uso principal |
|---|---|---|---|
| Fibra ISP | ether2 (WAN2) | 192.168.1.254 | PCs, notebooks, diretoria, APs |
| Starlink | ether1 (WAN1) | 192.168.1.1 | NVR, NAS — backup geral |
| WAN3 | ether3 | — | Reservada — pré-configurada |

O Netwatch monitora cada link a cada 10 segundos. Se um link não responder em 3 segundos por 3 vezes consecutivas, o script desativa a rota automaticamente. Quando o link volta, a rota é reabilitada.

| Evento | Comportamento automático |
|---|---|
| Fibra cai | Todo o tráfego migra para o Starlink |
| Fibra volta | Balanceamento original restaurado |
| Starlink cai | NVR e NAS migram para a Fibra |
| Starlink volta | NVR e NAS voltam para o Starlink |

---

## 8. QoS — Controle de Banda

### 8.1 Fibra (400 Mbps)

| Prioridade | Dispositivos |
|---|---|
| 1 — Máxima | Servidor AD (192.168.88.234) |
| 2 — Alta | PCs do domínio + Diretoria e TI (lista acesso-winbox) |
| 4 — Normal | Celulares e demais dispositivos |

### 8.2 Starlink (400 Mbps)

| Período | Prioridade 1 | Prioridade 2 | Prioridade 3 |
|---|---|---|---|
| Dia (06h–18h) | NVR (câmeras) | NAS (mín 20M, máx 100M) | Celulares (teto 30 Mbps) |
| Noite (18h–06h) | NAS (backup, banda total) | NVR (câmeras) | Celulares (teto 30 Mbps) |

### 8.3 Integração com failover

| Situação | QoS |
|---|---|
| Fibra normal | Celulares na Starlink limitados a 30 Mbps |
| Fibra fora | Teto dos celulares removido automaticamente |
| Fibra restaurada | Teto de 30 Mbps restaurado |

### 8.4 Scheduler

| Horário | Evento |
|---|---|
| 06:00 todo dia | NVR volta para prioridade 1 — câmeras têm precedência |
| 18:00 todo dia | NAS sobe para prioridade 1 — backup noturno com banda garantida |

---

## 9. Acesso Remoto

### 9.1 Tailscale VPN

O servidor AD e o notebook de TI estão conectados à rede Tailscale. O serviço está configurado como Automático no Windows Server 2019, com login persistente — reconecta automaticamente após qualquer reinicialização sem depender de auth keys com expiração.

### 9.2 RustDesk — Acesso às Estações

Servidor RustDesk instalado no SRV-AD01. Todos os computadores e notebooks têm o cliente configurado para apontar para o **IP Tailscale** do servidor — isso permite acesso tanto de dentro da rede quanto de fora, pelo mesmo endereço, sem mudar configuração.

Terceiros (suporte externo): acesso disponível via AnyDesk, com senha de autorização exigida pelo administrador a cada sessão.

---

## 10. GPO — Padronização das Estações

| GPO / Política | O que faz |
|---|---|
| Script de Logon (PS1) | Copia e atualiza ERP.exe por controle de versão por data; cria atalhos no perfil de cada usuário |
| Mapeamento de unidades | Pastas do NAS mapeadas como unidade de rede no login |
| Atalhos na Área de Trabalho | ERP, pastas da rede, Meu Computador, Lixeira |
| Restrição de instalação | Usuários comuns não instalam software sem autorização |
| Edge — política corporativa | Página inicial e configurações padrão para o ambiente |

**Ponto crítico do script:** o script roda em `Configuração do Usuário → Scripts (Logon)` — não em Configuração do Computador. Isso garante que ele execute no contexto de cada usuário que está fazendo login, independente de qual máquina. Sem isso, atalhos eram criados apenas para o primeiro usuário de cada máquina.

---

## 11. E-mail Corporativo

Outlook Classic configurado em todas as máquinas do domínio via IMAP/SMTP com o provedor de hospedagem. Anteriormente o acesso era feito exclusivamente pelo webmail.

---

## 12. Organização da Rede — Faixas de IP

| Faixa | Grupo | Comportamento |
|---|---|---|
| .2 — .59 | Desconhecidos | Sem internet + sem acesso a nenhum dispositivo interno |
| .60 — .119 | Autorizados Starlink | Internet via Starlink — autorização manual |
| .120 — .154 | Diretoria, TI e Autorizados | Internet via Fibra |
| .155 — .194 | PCs do domínio | Internet via Fibra |
| .195 — .224 | Câmeras IP | Sem internet — rede local apenas |
| .225 — .233 | Impressoras e Relógio | Sem internet — rede local apenas |
| .234 | Servidor AD | IP fixo no SO — nunca alterar |
| .235 — .253 | Infraestrutura | NVR/NAS: Starlink — APs: Fibra |

---

*\* MACs neste documento são fictícios para fins de portfólio.*

*Documentação Técnica — MikroTik hEX — 192.168.88.0/24 — Maio 2026*  
*Robson Andrade | robsonluisandrade@gmail.com*
