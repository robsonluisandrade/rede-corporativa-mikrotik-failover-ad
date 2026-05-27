# ==============================================================================
# BLOCO 7 — QoS com Queue Tree, PCQ e Scheduler
# ==============================================================================
#
# Hardware : MikroTik hEX (RB750Gr3)
# RouterOS : 7.22.3 stable
# Autor    : Robson Andrade
# Data     : Maio 2026
# Versão   : 2
#
# Por que QoS foi necessário:
#   Com dois links de 400 Mbps e mais de 30 dispositivos simultâneos, sem QoS
#   qualquer dispositivo poderia monopolizar o link inteiro. O caso mais crítico
#   era o backup noturno do NAS, que competia diretamente com a gravação das
#   câmeras na Starlink. Câmeras travavam, frames eram perdidos, e o backup
#   não tinha garantia de concluir dentro da janela noturna.
#
# Lógica implementada:
#   Fibra    → AD (1) > PCs e notebooks do domínio (2) > celulares (4)
#   Starlink → NVR (1) > NAS (2) > celulares (3) durante o dia
#   Starlink → NAS (1) > NVR (2) > celulares (3) durante a noite (backup)
#
# O Scheduler inverte as prioridades automaticamente às 06h e às 18h.
# O failover remove o teto dos celulares quando a Fibra cai, para não
# prejudicar quem migrou para o link de backup.
#
# Histórico de versões:
#   v1 — Maio 2026 — Versão inicial
#   v2 — Maio 2026 — IP do relógio de ponto atualizado de .211 para .230
#                    Ajuste de cabeçalho e histórico no padrão dos demais blocos
#
# Depois de aplicar, verifique:
#   /queue type print
#   /queue tree print
#   /system script print
#   /system scheduler print
# ==============================================================================

# ==============================================================================
# TIPOS DE FILA — PCQ divide a banda igualmente entre os dispositivos
# ==============================================================================
# pcq-rate=0 significa sem teto individual (divisão justa pelo PCQ)
# pcq-rate=30M no celular-starlink limita cada celular a 30 Mbps
/queue type
add name=pcq-download-fibra    kind=pcq pcq-classifier=dst-address pcq-rate=0   pcq-limit=50KiB pcq-total-limit=2000KiB
add name=pcq-upload-fibra      kind=pcq pcq-classifier=src-address pcq-rate=0   pcq-limit=50KiB pcq-total-limit=2000KiB
add name=pcq-download-starlink kind=pcq pcq-classifier=dst-address pcq-rate=0   pcq-limit=50KiB pcq-total-limit=2000KiB
add name=pcq-upload-starlink   kind=pcq pcq-classifier=src-address pcq-rate=0   pcq-limit=50KiB pcq-total-limit=2000KiB
add name=pcq-celular-starlink  kind=pcq pcq-classifier=dst-address pcq-rate=30M pcq-limit=50KiB pcq-total-limit=2000KiB

# ==============================================================================
# MANGLE — marcação de pacotes por Address-List e IP específico
# ==============================================================================
# Fibra:    AD > PCs (domínio + diretoria + winbox) > demais com-internet
# Starlink: NVR > NAS > celulares autorizados
# Relógio de ponto (.230) está em sem-internet — não entra no QoS da WAN
# ==============================================================================
/ip firewall mangle

# --- Fibra ---
add chain=forward dst-address=192.168.88.234       in-interface=ether2  \
    action=mark-packet new-packet-mark=fibra-ad         passthrough=no  \
    comment="QoS Fibra — Servidor AD (prioridade maxima)"
add chain=forward src-address=192.168.88.234        out-interface=ether2 \
    action=mark-packet new-packet-mark=fibra-ad-up      passthrough=no

add chain=forward dst-address-list=acesso-winbox    in-interface=ether2  \
    action=mark-packet new-packet-mark=fibra-pcs        passthrough=no  \
    comment="QoS Fibra — PCs e notebooks (dominio, diretoria, TI)"
add chain=forward src-address-list=acesso-winbox    out-interface=ether2 \
    action=mark-packet new-packet-mark=fibra-pcs-up     passthrough=no

add chain=forward dst-address-list=com-internet     in-interface=ether2  \
    packet-mark=no-mark \
    action=mark-packet new-packet-mark=fibra-celulares  passthrough=no  \
    comment="QoS Fibra — Celulares e demais com internet"
add chain=forward src-address-list=com-internet     out-interface=ether2 \
    packet-mark=no-mark \
    action=mark-packet new-packet-mark=fibra-celulares-up passthrough=no

# --- Starlink ---
add chain=forward dst-address=192.168.88.236        in-interface=ether1  \
    action=mark-packet new-packet-mark=starlink-nvr     passthrough=no  \
    comment="QoS Starlink — NVR CFTV (cameras em tempo real)"
add chain=forward src-address=192.168.88.236        out-interface=ether1 \
    action=mark-packet new-packet-mark=starlink-nvr-up  passthrough=no

add chain=forward dst-address=192.168.88.235        in-interface=ether1  \
    action=mark-packet new-packet-mark=starlink-nas         passthrough=no  \
    comment="QoS Starlink — NAS Synology (backup em nuvem)"
add chain=forward src-address=192.168.88.235        out-interface=ether1 \
    action=mark-packet new-packet-mark=starlink-nas-up      passthrough=no

add chain=forward dst-address-list=com-internet     in-interface=ether1  \
    packet-mark=no-mark \
    action=mark-packet new-packet-mark=starlink-celulares   passthrough=no  \
    comment="QoS Starlink — Celulares autorizados (teto 30 Mbps)"
add chain=forward src-address-list=com-internet     out-interface=ether1 \
    packet-mark=no-mark \
    action=mark-packet new-packet-mark=starlink-celulares-up passthrough=no

# ==============================================================================
# QUEUE TREE — hierarquia de filas
# ==============================================================================
# Ajuste max-limit para a banda contratada de cada link.
# Exemplo: 400M para 400 Mbps.
# ==============================================================================
/queue tree

# Fibra — prioridades fixas (AD sempre primeiro, celulares sempre por último)
add name=fibra-root         parent=ether2        max-limit=400M
add name=fibra-root-up      parent=ether2        max-limit=400M
add name=fibra-ad           parent=fibra-root    priority=1 queue=pcq-download-fibra packet-mark=fibra-ad
add name=fibra-ad-up        parent=fibra-root-up priority=1 queue=pcq-upload-fibra   packet-mark=fibra-ad-up
add name=fibra-pcs          parent=fibra-root    priority=2 queue=pcq-download-fibra packet-mark=fibra-pcs
add name=fibra-pcs-up       parent=fibra-root-up priority=2 queue=pcq-upload-fibra   packet-mark=fibra-pcs-up
add name=fibra-celulares    parent=fibra-root    priority=4 queue=pcq-download-fibra packet-mark=fibra-celulares
add name=fibra-celulares-up parent=fibra-root-up priority=4 queue=pcq-upload-fibra   packet-mark=fibra-celulares-up

# Starlink — prioridades no modo DIA (Scheduler altera às 06h e 18h)
# Modo dia: NVR (1) > NAS (2) > celulares (3)
# Modo noite: NAS (1) > NVR (2) > celulares (3)
add name=starlink-root          parent=ether1        max-limit=400M
add name=starlink-root-up       parent=ether1        max-limit=400M
add name=starlink-nvr           parent=starlink-root    priority=1 queue=pcq-download-starlink packet-mark=starlink-nvr
add name=starlink-nvr-up        parent=starlink-root-up priority=1 queue=pcq-upload-starlink   packet-mark=starlink-nvr-up
add name=starlink-nas           parent=starlink-root    priority=2 queue=pcq-download-starlink packet-mark=starlink-nas    min-limit=20M max-limit=100M
add name=starlink-nas-up        parent=starlink-root-up priority=2 queue=pcq-upload-starlink   packet-mark=starlink-nas-up min-limit=20M max-limit=100M
add name=starlink-celulares     parent=starlink-root    priority=3 queue=pcq-celular-starlink   packet-mark=starlink-celulares
add name=starlink-celulares-up  parent=starlink-root-up priority=3 queue=pcq-upload-starlink    packet-mark=starlink-celulares-up

# ==============================================================================
# SCRIPTS DO SCHEDULER — automação de horários e integração com failover
# ==============================================================================
/system script

# Ativado às 18h — NAS vira prioridade 1 para o backup noturno.
# Janela de backup: 18h às 06h. NVR continua gravando com prioridade 2.
add name=qos-noite policy=read,write,policy,test dont-require-permissions=yes \
    comment="QoS noite — NAS tem prioridade para backup (18h-06h)" \
    source="/queue tree set starlink-nvr priority=2\r\n\
/queue tree set starlink-nvr-up priority=2\r\n\
/queue tree set starlink-nas priority=1\r\n\
/queue tree set starlink-nas-up priority=1\r\n\
/queue tree set starlink-nas max-limit=400M\r\n\
/queue tree set starlink-nas-up max-limit=400M\r\n\
:log info \"QoS noite ativo — NAS com prioridade para backup\""

# Ativado às 06h — NVR volta a prioridade 1 para as câmeras durante o dia.
add name=qos-dia policy=read,write,policy,test dont-require-permissions=yes \
    comment="QoS dia — NVR tem prioridade (06h-18h)" \
    source="/queue tree set starlink-nvr priority=1\r\n\
/queue tree set starlink-nvr-up priority=1\r\n\
/queue tree set starlink-nas priority=2\r\n\
/queue tree set starlink-nas-up priority=2\r\n\
/queue tree set starlink-nas max-limit=100M\r\n\
/queue tree set starlink-nas-up max-limit=100M\r\n\
:log info \"QoS dia ativo — NVR com prioridade\""

# Acionado pelo failover (bloco 6) quando a Fibra cai (3 falhas consecutivas).
# Remove o teto de 30 Mbps dos celulares para não prejudicar quem migrou.
add name=qos-failover-on policy=read,write,policy,test dont-require-permissions=yes \
    comment="QoS failover ON — remove teto dos celulares na Starlink" \
    source="/queue type set pcq-celular-starlink pcq-rate=0\r\n\
/queue tree set starlink-nvr priority=2\r\n\
/queue tree set starlink-nas priority=3\r\n\
/queue tree set starlink-celulares priority=4\r\n\
:log warning \"QoS failover ativo — teto dos celulares removido\""

# Acionado quando a Fibra volta — restaura o teto de 30 Mbps.
add name=qos-failover-off policy=read,write,policy,test dont-require-permissions=yes \
    comment="QoS failover OFF — restaura teto de 30 Mbps nos celulares" \
    source="/queue type set pcq-celular-starlink pcq-rate=30M\r\n\
/queue tree set starlink-nvr priority=1\r\n\
/queue tree set starlink-nas priority=2\r\n\
/queue tree set starlink-celulares priority=3\r\n\
:log info \"QoS failover desligado — teto dos celulares restaurado\""

# Atualiza os scripts do bloco 6 para chamar o QoS durante o failover
/system script set fibra-down source=":global fibraFalhas\r\n\
:if ([:typeof \$fibraFalhas] = \"nothing\") do={ :set fibraFalhas 0 }\r\n\
:set fibraFalhas (\$fibraFalhas + 1)\r\n\
:log warning (\"Fibra — falha \" . \$fibraFalhas . \" de 3\")\r\n\
:if (\$fibraFalhas >= 3) do={\r\n\
:set fibraFalhas 0\r\n\
/ip route set [find comment=\"WAN2-Fibra-ISP-Principal\"] disabled=yes\r\n\
/system script run qos-failover-on\r\n\
:log warning \"FAILOVER ATIVADO — rota Fibra desabilitada\"\r\n\
}"

/system script set fibra-up source=":global fibraFalhas\r\n\
:set fibraFalhas 0\r\n\
/ip route set [find comment=\"WAN2-Fibra-ISP-Principal\"] disabled=no\r\n\
/system script run qos-failover-off\r\n\
:log info \"FIBRA ISP RESTAURADA — rota reabilitada\""

# ==============================================================================
# SCHEDULER — agendamento automático das trocas de prioridade
# ==============================================================================
/system scheduler
add name=qos-inicio-dia   start-time=06:00:00 interval=1d on-event=qos-dia   \
    comment="Ativa QoS dia — NVR tem prioridade na Starlink"
add name=qos-inicio-noite start-time=18:00:00 interval=1d on-event=qos-noite \
    comment="Ativa QoS noite — NAS tem prioridade para backup"
