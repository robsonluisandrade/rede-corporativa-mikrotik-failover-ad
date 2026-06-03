# ==============================================================================
# BLOCO 8 — Zabbix: Monitoramento da Infraestrutura de Rede
# ==============================================================================
#
# Hardware  : MikroTik hEX (RB750Gr3) — RouterOS 7.22.3
# Servidor  : Zabbix 7.0 LTS — Ubuntu Server 22.04 LTS
#             Rodando em VM Hyper-V no servidor AD (SRV-AD01)
#             IP do servidor Zabbix: 192.168.88.242
# Autor     : Robson Andrade
# Data      : Junho 2026
# Versao    : 1
#
# O que este bloco configura no MikroTik:
#   — Habilita o SNMP e cria community restrita ao IP do Zabbix
#   — Desabilita a community "public" padrao (boa pratica de seguranca)
#   — Libera SNMP (UDP 161) do servidor Zabbix ao proprio roteador
#   — Abre ICMP do Zabbix para todos os dispositivos (checagem de disponibilidade)
#   — Libera TCP 10050 do Zabbix aos agentes nos PCs e servidor AD
#   — Libera SNMP (UDP 161) do Zabbix ao NAS e impressoras monitoradas
#
# Dispositivos monitorados pelo Zabbix:
#   — MikroTik hEX            192.168.88.1   (SNMP v2c)
#   — SRV-AD01                192.168.88.234 (Zabbix Agent 2 — Windows)
#   — NAS-Synology            192.168.88.235 (SNMP v2c)
#   — PC-Comercial            192.168.88.155 (Zabbix Agent 2)
#   — PC-Compras              192.168.88.156 (Zabbix Agent 2)
#   — PC-Faturamento          192.168.88.157 (Zabbix Agent 2)
#   — PC-Financeiro           192.168.88.158 (Zabbix Agent 2)
#   — PC-Administracao        192.168.88.159 (Zabbix Agent 2)
#   — PC-Laboratorio          192.168.88.160 (Zabbix Agent 2)
#   — PC-Qualidade            192.168.88.161 (Zabbix Agent 2)
#   — Impressora-01           192.168.88.225 (SNMP v2c ou ICMP — Laser P&B)
#   — Impressora-05           192.168.88.229 (SNMP v2c ou ICMP — Multifuncional)
#
# ATENCAO — ordem de aplicacao dos blocos:
#   bloco1 -> bloco2 -> bloco3 -> bloco4 -> bloco5 -> bloco6 -> bloco7 -> bloco8
#
# Depois de aplicar, verifique:
#   /snmp print
#   /snmp community print
#   /ip firewall filter print
# ==============================================================================


# ==============================================================================
# SNMP no MikroTik — permite que o Zabbix leia dados do roteador
# ==============================================================================

# Habilita o servico SNMP com identificacao do ambiente
/snmp set enabled=yes contact="TI - Administrador" location="Rede Corporativa"

# Desabilita a community padrao "public" — nunca deixar aberta
/snmp community
set [ find default=yes ] name=public addresses="" disabled=yes \
    comment="Community padrao desabilitada — boa pratica de seguranca"

# Cria community dedicada com acesso restrito apenas ao IP do servidor Zabbix
# Somente o .242 consegue fazer consultas SNMP ao roteador
add name=empresa-zabbix addresses=192.168.88.242 \
    security=noauth read-access=yes write-access=no \
    comment="Community SNMP exclusiva para o servidor Zabbix (.242)"


# ==============================================================================
# Regras de Firewall — libera o servidor Zabbix na rede
# ==============================================================================
#
# ATENCAO: Estas regras devem ser inseridas ANTES da regra final
#          "Descarta tudo que nao foi autorizado" do bloco 5.
#          No Winbox: apos aplicar o script, arraste estas 4 regras para cima
#          das ultimas duas linhas da chain input.
# ==============================================================================

/ip firewall filter

# Regra 1: SNMP — Zabbix consulta o proprio MikroTik via SNMP (UDP 161)
add chain=input in-interface=bridge-lan \
    src-address=192.168.88.242 protocol=udp dst-port=161 \
    action=accept \
    comment="Zabbix — SNMP do roteador (UDP 161)"

# Regra 2: ICMP — Zabbix faz ping em todos os dispositivos para checar disponibilidade
add chain=forward in-interface=bridge-lan \
    src-address=192.168.88.242 protocol=icmp \
    action=accept \
    comment="Zabbix — ping para monitorar disponibilidade dos dispositivos"

# Regra 3: Agente Zabbix — coleta metricas dos PCs e servidor AD (TCP 10050)
add chain=forward in-interface=bridge-lan \
    src-address=192.168.88.242 dst-port=10050 protocol=tcp \
    action=accept \
    comment="Zabbix — acesso ao agente (porta 10050) nos PCs e AD"

# Regra 4: SNMP — Zabbix consulta NAS e impressoras monitoradas (UDP 161)
add chain=forward in-interface=bridge-lan \
    src-address=192.168.88.242 dst-port=161 protocol=udp \
    action=accept \
    comment="Zabbix — SNMP para NAS e impressoras (UDP 161)"


# ==============================================================================
# OBSERVACOES IMPORTANTES
# ==============================================================================
#
# 1. IP do servidor Zabbix: 192.168.88.242 (VM Ubuntu 22.04 — Hyper-V no SRV-AD01)
#    Garanta que este IP esteja na lista com-internet para ter acesso a rede:
#
#    /ip firewall address-list add list=com-internet \
#        address=192.168.88.242 comment="SRV-Zabbix"
#
# 2. Nos PCs Windows e no servidor AD, instale o Zabbix Agent 2 (nao o Agent 1).
#    Durante a instalacao (MSI), configure:
#
#    Server=192.168.88.242
#    ServerActive=192.168.88.242
#    Hostname=<nome-do-host-exatamente-como-cadastrado-no-zabbix>
#
#    Exemplo via PowerShell (Administrador):
#    msiexec /i zabbix_agent2-7.0.0-windows-amd64-openssl.msi /qn `
#        SERVER=192.168.88.242 SERVERACTIVE=192.168.88.242 HOSTNAME=PC-Comercial
#
# 3. Apos instalar o agente, libere a porta no firewall do Windows:
#
#    New-NetFirewallRule -DisplayName 'Zabbix Agent 2' `
#        -Direction Inbound -Protocol TCP -LocalPort 10050 `
#        -Action Allow -Profile Domain,Private
#
# 4. NAS Synology — habilitar SNMP pelo DSM:
#    Painel de Controle > Terminal e SNMP > Habilitar SNMP
#    Community: empresa-zabbix
#    Template recomendado no Zabbix: "Synology DiskStation by SNMP"
#
# 5. Impressoras — community SNMP:
#    Impressora-01 (.225) e Impressora-05 (.229) usam community "public" (padrao de
#    fabrica — nao ha como alterar no modelo). O acesso e controlado pelo firewall:
#    apenas o .242 consegue fazer consultas UDP 161 a elas.
#    Template recomendado: "Printer by SNMP" ou monitorar apenas por ICMP.
#
# 6. Verificacao rapida apos aplicar o bloco:
#
#    No servidor Zabbix (terminal Ubuntu):
#    snmpwalk -v2c -c empresa-zabbix 192.168.88.1 .1.3.6.1.2.1.1.1.0
#    (deve retornar o modelo e versao do RouterOS)
#
#    zabbix_get -s 192.168.88.155 -p 10050 -k system.hostname
#    (deve retornar "PC-Comercial" ou o hostname configurado)
# ==============================================================================
