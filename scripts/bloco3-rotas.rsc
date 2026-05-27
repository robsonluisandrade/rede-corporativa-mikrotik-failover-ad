# ==============================================================================
# BLOCO 3 — Rotas, Tabelas de Roteamento, Mangle e Routing Rules
# ==============================================================================
#
# Hardware : MikroTik hEX (RB750Gr3)
# RouterOS : 7.22.3 stable
# Autor    : Robson Andrade
# Data     : Maio 2026
#
# Este foi o bloco mais trabalhoso do projeto inteiro.
#
# O problema: os dois links de internet estavam na mesma faixa 192.168.1.x
# com gateways diferentes. O MikroTik não sabia por qual interface chegar
# em cada gateway, gerando instabilidade constante: ping falhava, uma
# interface travava a outra, o failover nunca entrava de verdade.
#
# Tentativas que não funcionaram:
#   — Ajustar apenas a distância das rotas padrão → conflito persistia
#   — Desabilitar uma interface → funcionava, mas era intervenção manual
#
# A solução: rotas /32 para cada gateway
#   Ao criar uma rota /32 especificamente para o IP do gateway, forçamos
#   o RouterOS a saber EXATAMENTE por qual interface aquele gateway é
#   acessado. Com essa âncora explícita, as rotas padrão passam a funcionar
#   corretamente e o failover passa a ser confiável.
#
# Além disso, NVR e NAS têm uma tabela de roteamento própria (via-starlink)
# que os força a sair pela Starlink, com fallback automático para a Fibra.
# Nenhum dispositivo fica offline em nenhum cenário.
#
# Depois de aplicar, verifique:
#   /routing table print
#   /ip route print
#   /ip firewall mangle print
#   /routing rule print
# ==============================================================================

# --- Tabelas de roteamento dedicadas ---
/routing table
add name=via-starlink fib comment="Roteamento do NVR e NAS — sai pela Starlink"
add name=via-wan3     fib comment="Terceiro link — pre-configurado para quando chegar"

# ==============================================================================
# ROTAS PRINCIPAIS
# ==============================================================================
/ip route

# Estas duas rotas /32 são a chave para resolver o conflito entre os dois links
# na mesma faixa — cada gateway fica ancorado na sua interface específica
add dst-address=192.168.1.254/32 gateway=ether2 comment="Gateway local da Fibra ISP"
add dst-address=192.168.1.1/32   gateway=ether1 comment="Gateway local do Starlink"

# Rota principal — Fibra com distância 1 (preferencial para a maioria dos dispositivos)
# check-gateway=ping: o RouterOS só usa esta rota se a Fibra estiver respondendo
add dst-address=0.0.0.0/0 gateway=192.168.1.254 distance=1 \
    check-gateway=ping comment="WAN2-Fibra-ISP-Principal" disabled=no

# Rota de backup — Starlink com distância 2 (assume se a Fibra cair)
add dst-address=0.0.0.0/0 gateway=192.168.1.1 distance=2 \
    check-gateway=ping comment="WAN1-Starlink-Backup" disabled=no

# Terceiro link — descomentar e ajustar quando disponível
# add dst-address=0.0.0.0/0 gateway=WAN3_GATEWAY distance=3 \
#     check-gateway=ping comment="WAN3-Reservada-Backup" disabled=yes

# Rota do NVR e NAS — saem pela Starlink via tabela dedicada
add dst-address=0.0.0.0/0 gateway=192.168.1.1 distance=1 \
    routing-table=via-starlink comment="Starlink — rota principal NVR e NAS"

# Fallback — se a Starlink cair, NVR e NAS migram para a Fibra automaticamente
add dst-address=0.0.0.0/0 gateway=192.168.1.254 distance=2 \
    routing-table=via-starlink comment="Fibra — fallback do NVR e NAS"

# Âncora do gateway da Starlink dentro da tabela dedicada
add dst-address=192.168.1.1/32 gateway=ether1 \
    routing-table=via-starlink comment="Gateway Starlink na tabela dedicada"

# ==============================================================================
# ROUTING RULES — define qual tabela cada dispositivo usa
# ==============================================================================
/routing rule
add src-address=192.168.88.235/32 action=lookup-only-in-table \
    table=via-starlink comment="NAS — usa tabela da Starlink"
add src-address=192.168.88.236/32 action=lookup-only-in-table \
    table=via-starlink comment="NVR — usa tabela da Starlink"

# ==============================================================================
# MANGLE — marcação de conexões para garantir retorno pelo link correto
# ==============================================================================
/ip firewall mangle

# Marca conexões que entram por cada link.
# Isso garante que a resposta volte pelo mesmo caminho que a requisição chegou
# (problema clássico de dual WAN: request entra pela Fibra, resposta tenta sair
# pelo Starlink e o cliente descarta o pacote por achar que é inválido).
add chain=prerouting in-interface=ether1 action=mark-connection \
    new-connection-mark=starlink-conn passthrough=yes \
    comment="Marca conexoes que entram pelo Starlink"

add chain=prerouting in-interface=ether2 action=mark-connection \
    new-connection-mark=fibra-conn passthrough=yes \
    comment="Marca conexoes que entram pela Fibra"

# Garante que o tráfego de retorno use o mesmo link de entrada
add chain=output connection-mark=starlink-conn action=mark-routing \
    new-routing-mark=via-starlink passthrough=yes \
    comment="Respostas do Starlink voltam pelo Starlink"

# Força o NVR a sair pela Starlink
add chain=prerouting src-address=192.168.88.236 in-interface=bridge-lan \
    action=mark-routing new-routing-mark=via-starlink passthrough=yes \
    comment="NVR — forca saida pela Starlink"

# Força o NAS a sair pela Starlink
add chain=prerouting src-address=192.168.88.235 in-interface=bridge-lan \
    action=mark-routing new-routing-mark=via-starlink passthrough=yes \
    comment="NAS — forca saida pela Starlink"
