# Windows Server 2019 + Hyper-V + VM Ubuntu Server

> Parte da série: Infraestrutura de Servidores — ambiente corporativo.  
> Contexto completo do projeto: [README principal](../../README.md)

---

## Por que essa combinação

A decisão de usar o Windows Server 2019 com Hyper-V foi tomada por uma razão prática: o servidor já existia, rodava Active Directory, DNS, SQL Server 2017 e o sistema de ponto, e tinha hardware sobrando. Comprar uma máquina separada para rodar o Zabbix não se justificava.

A solução foi ativar o Hyper-V diretamente no servidor AD e criar uma VM para o Ubuntu Server. O custo foi zero — o hardware suportou, a licença do Windows Server 2019 Datacenter cobre VMs ilimitadas, e a gestão ficou centralizada em uma máquina só.

Esse é um cenário comum em empresas de médio porte: o servidor faz tudo, e o desafio é organizar bem as responsabilidades de cada camada para que uma não prejudique a outra.

---

## O ambiente

| Componente        | Especificação                                           |
| ----------------- | ------------------------------------------------------- |
| Servidor físico   | SRV-AD01 — Windows Server 2019 (Desktop Experience)     |
| Função principal  | Active Directory, DNS, SQL Server 2017, Servidor de Arquivos |
| Hyper-V           | Habilitado como role adicional                          |
| VM criada         | Ubuntu Server 22.04 LTS — IP 192.168.88.242             |
| Uso da VM         | Servidor Zabbix 7.0 LTS com PostgreSQL 16               |
| Switch virtual    | External Switch — VM acessa a rede física diretamente   |

---

## Parte 1 — Instalação do Windows Server 2019

### Por que Desktop Experience e não Core?

O Windows Server tem duas opções de instalação: **Core** (sem interface gráfica, apenas linha de comando) e **Desktop Experience** (com interface gráfica completa). Para um ambiente onde o servidor também é gerenciado localmente por uma equipe pequena — sem time de infraestrutura dedicado — a Desktop Experience facilita a gestão diária via Gerenciador do Servidor, sem exigir que tudo seja feito via PowerShell ou SSH.

Em um ambiente maior, com gestão centralizada e automatizada, Core seria a escolha mais segura. Aqui, a praticidade pesou mais.

### Passo a passo da instalação

**1. Preparar a mídia de instalação**

Baixe a ISO diretamente da Microsoft (avaliação de 180 dias gratuita ou com licença):
```
https://www.microsoft.com/pt-br/evalcenter/evaluate-windows-server-2019
```

Crie um pendrive bootável com o Rufus (Windows) ou `dd` (Linux):
```bash
# Linux — substitua /dev/sdX pelo seu pendrive (confirme com lsblk antes)
sudo dd if=windows_server_2019.iso of=/dev/sdX bs=4M status=progress
```

**2. Boot e seleção de versão**

Na tela de seleção, escolha:
```
Windows Server 2019 Standard (Desktop Experience)
```
ou Datacenter, dependendo da licença disponível. A diferença prática para esse cenário é que o Datacenter permite VMs ilimitadas com a mesma licença.

**3. Particionamento**

Para um servidor que vai rodar AD + SQL Server + Hyper-V, o recomendado é separar o disco em partições:

| Partição | Tamanho sugerido | Uso |
| -------- | ---------------- | --- |
| C:\      | 100 GB           | Sistema operacional e programas |
| D:\      | restante         | Dados: VMs do Hyper-V, bancos SQL, arquivos |

Separar os dados do sistema facilita backups e evita que um crescimento de dados afete o SO.

**4. Configurações iniciais após a instalação**

```powershell
# Definir nome do servidor (reinicialização necessária)
Rename-Computer -NewName "SRV-AD01" -Restart

# Definir IP fixo (adapte ao seu ambiente)
New-NetIPAddress -InterfaceAlias "Ethernet" `
    -IPAddress 192.168.88.234 `
    -PrefixLength 24 `
    -DefaultGateway 192.168.88.1

# Definir DNS apontando para si mesmo (o servidor vai ser o DC)
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" `
    -ServerAddresses 127.0.0.1

# Ativar o Windows (substitua pela sua chave)
slmgr /ipk XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
slmgr /ato

# Atualizar o sistema
Install-Module PSWindowsUpdate -Force
Get-WindowsUpdate -Install -AcceptAll -AutoReboot
```

**5. Desabilitar o IE Enhanced Security Configuration**

Esse recurso bloqueia praticamente todos os downloads pelo navegador do servidor — o que é inconveniente na prática para baixar instaladores.

```
Gerenciador do Servidor → Servidor Local → IE Enhanced Security Configuration → Desligar para Administradores
```

**6. Habilitar o Remote Desktop**

```powershell
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
    -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
```

---

## Parte 2 — Instalação do Hyper-V

### O que é o Hyper-V

O Hyper-V é o hypervisor nativo da Microsoft, disponível no Windows Server sem custo adicional. Ele roda como camada entre o hardware e os sistemas operacionais, permitindo que múltiplas VMs compartilhem os recursos físicos da máquina.

A vantagem de usar o Hyper-V aqui em vez de instalar o Ubuntu diretamente no servidor é o isolamento: se a VM do Zabbix travar, o AD não é afetado. Se precisar reiniciar a VM, o servidor continua funcionando.

### Instalando o Hyper-V via PowerShell

```powershell
# Instalar a role do Hyper-V (reinicialização obrigatória ao final)
Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart
```

Ou via Gerenciador do Servidor:
```
Gerenciador do Servidor → Adicionar Funções e Recursos
→ Funções do Servidor → Hyper-V
→ Ferramentas de Gerenciamento → Gerenciador do Hyper-V
→ Instalar → Reiniciar
```

### Criando o Switch Virtual (External Switch)

O External Switch conecta as VMs diretamente à rede física — a VM recebe um IP da mesma faixa da rede e se comporta como um computador físico na rede.

```powershell
# Listar os adaptadores de rede disponíveis
Get-NetAdapter

# Criar o External Switch vinculado ao adaptador físico
# Substitua "Ethernet" pelo nome do adaptador que apareceu acima
New-VMSwitch -Name "Switch-Externo" `
    -NetAdapterName "Ethernet" `
    -AllowManagementOS $true
```

> ⚠️ `AllowManagementOS $true` mantém o servidor host com acesso à rede pelo mesmo adaptador. Sem isso, o servidor físico perde conectividade de rede ao criar o switch.

---

## Parte 3 — Criando a VM Ubuntu Server no Hyper-V

### Decisões de configuração da VM

Antes de criar, algumas decisões importantes:

**Geração 1 ou Geração 2?**
Geração 2 é a recomendada para sistemas modernos — suporta boot UEFI e tem melhor performance. Ubuntu Server 22.04 é totalmente compatível. Use Geração 2.

**Quantos recursos alocar?**
O Zabbix com PostgreSQL em um ambiente com 12 hosts monitorados e baixa frequência de coleta é leve. Alocar 2 vCPUs e 2 GB de RAM é suficiente para começar. O Hyper-V permite ajustar sem recriar a VM.

| Recurso    | Alocado | Observação                                          |
| ---------- | ------- | --------------------------------------------------- |
| vCPUs      | 2       | Suficiente para Zabbix + PostgreSQL em ambiente pequeno |
| RAM        | 2 GB    | RAM dinâmica habilitada — pode expandir se necessário |
| Disco      | 40 GB   | VHDX em D:\ (separado do sistema)                   |
| Rede       | Switch-Externo | VM recebe IP da rede 192.168.88.0/24         |
| Geração    | 2       | UEFI — mais moderno e performático                  |

### Criando a VM via PowerShell

```powershell
# Criar a VM
New-VM -Name "SRV-Zabbix" `
    -Generation 2 `
    -MemoryStartupBytes 2GB `
    -Path "D:\VMs" `
    -SwitchName "Switch-Externo"

# Criar o disco virtual em D:\ (separado do sistema)
New-VHD -Path "D:\VMs\SRV-Zabbix\SRV-Zabbix-disco.vhdx" `
    -SizeBytes 40GB -Dynamic

# Adicionar o disco à VM
Add-VMHardDiskDrive -VMName "SRV-Zabbix" `
    -Path "D:\VMs\SRV-Zabbix\SRV-Zabbix-disco.vhdx"

# Adicionar a ISO do Ubuntu Server como DVD de boot
# Baixe a ISO em: https://ubuntu.com/download/server
Add-VMDvdDrive -VMName "SRV-Zabbix" `
    -Path "D:\ISOs\ubuntu-22.04-live-server-amd64.iso"

# Configurar a ordem de boot: DVD primeiro, depois disco
$bootOrder = Get-VMFirmware -VMName "SRV-Zabbix"
Set-VMFirmware -VMName "SRV-Zabbix" `
    -BootOrder ($bootOrder.BootOrder | Sort-Object -Property BootType -Descending)

# Habilitar RAM dinâmica
Set-VMMemory -VMName "SRV-Zabbix" `
    -DynamicMemoryEnabled $true `
    -MinimumBytes 512MB `
    -MaximumBytes 4GB

# Ajustar vCPUs
Set-VMProcessor -VMName "SRV-Zabbix" -Count 2

# Desabilitar Secure Boot para compatibilidade com Ubuntu
Set-VMFirmware -VMName "SRV-Zabbix" `
    -SecureBootTemplate "MicrosoftUEFICertificateAuthority"
# Ou desabilitar completamente:
Set-VMFirmware -VMName "SRV-Zabbix" -EnableSecureBoot Off

# Iniciar a VM
Start-VM -Name "SRV-Zabbix"

# Abrir o console da VM
vmconnect localhost "SRV-Zabbix"
```

### Criando a VM via Gerenciador do Hyper-V (interface gráfica)

```
Gerenciador do Hyper-V → Novo → Máquina Virtual
→ Nome: SRV-Zabbix
→ Geração: Geração 2
→ Memória de inicialização: 2048 MB — marcar "Usar memória dinâmica"
→ Conexão de rede: Switch-Externo
→ Disco rígido virtual: criar novo — 40 GB — salvar em D:\VMs\
→ Opções de instalação: instalar SO de arquivo de imagem — selecionar a ISO do Ubuntu
→ Concluir

Antes de iniciar — clicar com botão direito → Configurações:
→ Segurança → Desmarcar "Habilitar Inicialização Segura" (ou trocar para CA UEFI)
→ Processador → aumentar para 2 processadores virtuais
→ OK → Iniciar → Conectar
```

---

## Parte 4 — Instalação do Ubuntu Server 22.04 LTS na VM

### Por que Ubuntu Server e não Desktop?

Ubuntu Server não tem interface gráfica — tudo é feito via linha de comando. Isso reduz o consumo de RAM (sem ambiente gráfico rodando), diminui a superfície de ataque (menos pacotes instalados) e é o padrão para servidores Linux em produção.

O Zabbix, PostgreSQL e qualquer outro serviço que vá rodar nessa VM são gerenciados via SSH — a ausência de interface gráfica não é uma limitação, é uma escolha consciente.

### Instalação

**1. Na tela de boas-vindas**, selecione o idioma (English é recomendado para servidores — mensagens de erro e documentação são melhores em inglês).

**2. Layout de teclado:** Brazilian Portuguese se preferir, ou English (US).

**3. Tipo de instalação:** Ubuntu Server (sem as ferramentas Snap extras — mais enxuto).

**4. Configuração de rede:**
Na tela de rede, configure o IP fixo da VM:
```
Subnet:  192.168.88.0/24
Address: 192.168.88.242
Gateway: 192.168.88.1
DNS:     192.168.88.234, 1.1.1.1
```
> O IP `.242` já estava reservado no DHCP do MikroTik desde o bloco 2. Configure o IP fixo diretamente no Ubuntu para não depender do DHCP.

**5. Particionamento:** Use o disco inteiro — o instalador vai criar a estrutura padrão automaticamente. Para uma VM de uso único (Zabbix), não há necessidade de particionar manualmente.

**6. Perfil do servidor:**
```
Nome do servidor:  srv-zabbix
Nome do usuário:   adminzabbix   (evite "admin" ou "root" — boa prática)
Senha:             (senha forte — anote em local seguro)
```

**7. Instalação do OpenSSH:** Marque **Install OpenSSH server** — é como você vai gerenciar o servidor remotamente, sem precisar do console do Hyper-V.

**8. Pacotes adicionais (Snaps):** Não selecione nenhum — os serviços serão instalados manualmente depois.

**9. Aguarde a instalação e reinicie.** Quando pedir para remover a mídia de instalação:
```powershell
# No PowerShell do Windows Server, remover a ISO:
Remove-VMDvdDrive -VMName "SRV-Zabbix" -ControllerNumber 0 -ControllerLocation 1
```
Ou pelo Gerenciador do Hyper-V: Configurações da VM → DVD → Remover mídia.

### Primeiros comandos após o boot

Conecte via SSH de qualquer máquina da rede:
```bash
ssh adminzabbix@192.168.88.242
```

```bash
# Atualizar o sistema completamente
sudo apt update && sudo apt upgrade -y

# Instalar utilitários essenciais
sudo apt install -y curl wget nano net-tools htop unzip

# Verificar o IP fixo
ip a

# Confirmar conectividade com o gateway (MikroTik)
ping -c 4 192.168.88.1

# Confirmar resolução de DNS
nslookup google.com
```

### Configurar IP fixo permanentemente (Netplan)

O instalador deve ter configurado o IP fixo. Confirme e, se necessário, ajuste:

```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

O arquivo deve ficar assim:
```yaml
network:
  version: 2
  ethernets:
    eth0:                          # confirme o nome da interface com: ip a
      addresses:
        - 192.168.88.242/24
      routes:
        - to: default
          via: 192.168.88.1
      nameservers:
        addresses:
          - 192.168.88.234         # DNS principal: servidor AD
          - 1.1.1.1                # DNS secundário: Cloudflare
      dhcp4: false
```

```bash
# Aplicar as configurações
sudo netplan apply

# Verificar
ip a && ip route
```

### Configurar o fuso horário

```bash
# Verificar fuso atual
timedatectl

# Definir para Manaus (UTC-4, sem horário de verão)
sudo timedatectl set-timezone America/Manaus   # ajuste para o seu fuso (ex: America/Sao_Paulo)

# Confirmar
timedatectl
```

### Configurações de segurança básica do SSH

```bash
sudo nano /etc/ssh/sshd_config
```

Ajuste as linhas:
```
PermitRootLogin no           # nunca permitir login direto como root
PasswordAuthentication yes   # manter sim por ora; trocar por chave SSH futuramente
MaxAuthTries 3               # bloqueia após 3 tentativas erradas
```

```bash
sudo systemctl restart ssh
```

---

## O que vem depois

Com o Ubuntu Server no ar e acessível via SSH, a VM está pronta para receber os serviços. Os próximos passos estão documentados nos arquivos desta pasta:

- [`ubuntu-server-bancos-de-dados.md`](ubuntu-server-bancos-de-dados.md) — instalação do MySQL, PostgreSQL e SQL Server no Ubuntu
- [`zabbix-instalacao.md`](zabbix-instalacao.md) — instalação e configuração completa do Zabbix 7.0 LTS
- [`linux-docker-homelab.md`](linux-docker-homelab.md) — Docker no home lab: MySQL, PostgreSQL, SQL Server e Zabbix em containers

---

## O que aprendi nessa etapa

O ponto que mais me custou tempo foi o **Secure Boot**. O Hyper-V de Geração 2 vem com Secure Boot habilitado por padrão, e a ISO do Ubuntu não é assinada com o certificado Microsoft padrão. O resultado: a VM iniciava, mostrava o logo do Hyper-V e travava sem mensagem de erro clara.

A solução é trocar o template do Secure Boot de `MicrosoftWindows` para `MicrosoftUEFICertificateAuthority` — ou simplesmente desabilitar o Secure Boot para VMs Linux. Nenhum dos dois reduz a segurança de forma significativa em um ambiente interno.

O segundo ponto foi a **ordem de boot**. Após criar a VM e adicionar a ISO, a ordem padrão colocava o disco antes do DVD. A VM tentava bootar do disco vazio, ficava em loop. Ajustar a ordem de boot para DVD primeiro antes da primeira inicialização é obrigatório.

Esses dois detalhes não estão em destaque na documentação oficial — aparecem quando você está com a mão na massa.

---

## Tecnologias

`Windows Server 2019` `Hyper-V` `Virtual Switch` `VHDX` `Ubuntu Server 22.04 LTS` `Netplan` `OpenSSH` `PowerShell`

---

*Robson Andrade · [linkedin.com/in/robsonandradee](https://www.linkedin.com/in/robsonandradee) · robsonluisandrade@gmail.com*
