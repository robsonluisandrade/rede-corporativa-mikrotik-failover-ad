# ==============================================================================
# BLOCO 6 — Failover Automático, NTP, Horário e Segurança Final
# ==============================================================================
#
# Hardware : MikroTik hEX (RB750Gr3)
# RouterOS : 7.22.3 stable
# Autor    : Robson Andrade
# Data     : Maio 2026
#
# Como o failover funciona:
#   O Netwatch faz um ping a cada 10 segundos em cada link.
#   Se não houver resposta em 3 segundos, conta como falha.
#   Após 3 falhas consecutivas, o script desativa a rota daquele link
#   e o tráfego migra automaticamente para o link disponível.
#   Quando o link volta a responder, a rota é reabilitada.
#
# O contador de 3 falhas é intencional:
#   Links de internet, especialmente Starlink, podem ter oscilações pontuais
#   de menos de 30 segundos. Sem o contador, um pingo de instabilidade
#   acionaria o failover desnecessariamente várias vezes por dia.
#   Com 3 falhas consecutivas (30 segundos de indisponibilidade), garantimos
#   que o failover só atua quando o link realmente está fora.
#
# Nota sobre flag I (INVALID) nos scripts:
#   No RouterOS 7, scripts criados via CLI podem aparecer com flag I.
#   Isso é comportamento normal e não afeta o funcionamento.
#   Testado e validado em produção.
#
# Como testar o failover:
#   1. Desconecte o cabo da Fibra e aguarde ~30 segundos
#   2. /log print → deve aparecer "FAILOVER ATIVADO"
#   3. Reconecte o cabo e aguarde ~30 segundos
#   4. /log print → deve aparecer "FIBRA RESTAURADA"
#
# Depois de aplicar, verifique:
#   /system script print
#   /tool netwatch print       → deve mostrar os dois monitores como "up"
#   /ip service print          → todos desabilitados exceto winbox
#   /system ntp client print   → deve mostrar enabled=yes
# ==============================================================================

/system script

# Script executado quando a Fibra para de responder.
# Conta 3 falhas consecutivas antes de ativar o failover —
# evita acionamentos desnecessários por oscilações pontuais.
add name=fibra-down \
    policy=read,write,policy,test \
    dont-require-permissions=yes \
    comment="Executado quando a Fibra para de responder — age apos 3 falhas consecutivas" \
    source=":global fibraFalhas\r\n:if ([:typeof \$fibraFalhas] = \"nothing\") do={ :set fibraFalhas 0 }\r\n:set fibraFalhas (\$fibraFalhas + 1)\r\n:log warning (\"Fibra - falha \" . \$fibraFalhas . \" de 3\")\r\n:if (\$fibraFalhas >= 3) do={\r\n:set fibraFalhas 0\r\n/ip route set [find comment=\"WAN2-Fibra-ISP-Principal\"] disabled=yes\r\n:log warning \"FAILOVER ATIVADO - Fibra fora apos 3 falhas consecutivas\"\r\n}"

# Script executado quando a Fibra volta a responder.
# Zera o contador de falhas e reabilita a rota.
add name=fibra-up \
    policy=read,write,policy,test \
    dont-require-permissions=yes \
    comment="Executado quando a Fibra volta — zera contador e restaura rota" \
    source=":global fibraFalhas\r\n:set fibraFalhas 0\r\n/ip route set [find comment=\"WAN2-Fibra-ISP-Principal\"] disabled=no\r\n:log info \"FIBRA ISP RESTAURADA\""

# Script executado quando o Starlink para de responder.
add name=starlink-down \
    policy=read,write,policy,test \
    comment="Executado quando o Starlink para de responder" \
    source="/ip route set [find comment=\"WAN1-Starlink-Backup\"] disabled=yes\r\n:log warning \"FAILOVER ATIVADO - Starlink fora - NVR e NAS migrando para Fibra\""

# Script executado quando o Starlink volta.
add name=starlink-up \
    policy=read,write,policy,test \
    comment="Executado quando o Starlink volta a responder" \
    source="/ip route set [find comment=\"WAN1-Starlink-Backup\"] disabled=no\r\n:log info \"STARLINK RESTAURADO - NVR e NAS voltando para Starlink\""

# --- Netwatch — monitor de cada link ---
# Um ping a cada 10 segundos, timeout de 3 segundos.
# Esses valores podem ser ajustados conforme a estabilidade dos links.
/tool netwatch
add host=8.8.8.8 interval=10s timeout=3s \
    up-script=fibra-up \
    down-script=fibra-down \
    comment="Monitora a Fibra ISP — pinga 8.8.8.8 a cada 10 segundos"

add host=1.1.1.1 interval=10s timeout=3s \
    up-script=starlink-up \
    down-script=starlink-down \
    comment="Monitora o Starlink — pinga 1.1.1.1 a cada 10 segundos"

# Terceiro link — descomentar quando disponível
# add host=8.8.4.4 interval=10s timeout=3s \
#     up-script=wan3-up \
#     down-script=wan3-down \
#     comment="Monitora o terceiro link"

# --- Sincronização de horário ---
/system ntp client
set enabled=yes

/system ntp client servers
add address=a.ntp.br comment="NTP Brasil — servidor primario"
add address=b.ntp.br comment="NTP Brasil — servidor secundario"

/system clock
set time-zone-name=America/Manaus
# Ajuste para o fuso horário do ambiente:
# America/Sao_Paulo  → Brasília/SP/RJ/MG
# America/Manaus     → AM/RO/MT
# America/Fortaleza  → CE/PE/BA

# --- Desabilitar todos os serviços desnecessários ---
# Acesso ao servidor é feito via Tailscale VPN — sem portas expostas.
/ip service
set telnet  disabled=yes comment="Telnet desabilitado"
set ftp     disabled=yes comment="FTP desabilitado"
set www     disabled=yes comment="HTTP WebFig desabilitado"
set ssh     disabled=yes comment="SSH desabilitado"
set www-ssl disabled=yes comment="HTTPS WebFig desabilitado"
set api     disabled=yes comment="API desabilitada"
set api-ssl disabled=yes comment="API-SSL desabilitada"
set winbox  address=192.168.88.0/24 comment="Winbox — apenas da rede local"

# --- Interface lists para neighbor discovery ---
# O roteador anuncia sua presença apenas na LAN, nunca para a internet.
/interface list
add name=LAN comment="Interfaces da rede local"
add name=WAN comment="Interfaces de internet"

/interface list member
add interface=bridge-lan list=LAN comment="LAN"
add interface=ether1     list=WAN comment="Starlink"
add interface=ether2     list=WAN comment="Fibra ISP"
add interface=ether3     list=WAN comment="Terceiro link"

/ip neighbor discovery-settings
set discover-interface-list=LAN

# --- Proteção contra IP spoofing ---
# rp-filter=strict verifica se o pacote de entrada veio pela interface
# correta para aquele IP de origem. Pacotes que chegam por uma interface
# mas cujo IP de origem pertence a outra rota são descartados.
/ip settings
set rp-filter=strict

# --- Logs para acompanhamento ---
/system logging
add topics=firewall action=memory comment="Log do firewall"
add topics=route    action=memory comment="Log de rotas e failover"
add topics=warning  action=memory comment="Log de alertas"
add topics=info     action=memory comment="Log de informacoes gerais"
