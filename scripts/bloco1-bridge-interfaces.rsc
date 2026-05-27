# ==============================================================================
# BLOCO 1 — Interfaces, Bridge LAN e DHCP Client nas WANs
# ==============================================================================
#
# Hardware : MikroTik hEX (RB750Gr3)
# RouterOS : 7.22.3 stable
# Autor    : Robson Andrade
# Data     : Maio 2026
#
# Como está organizado:
#   ether1 — Starlink  (link principal do NVR e NAS, backup geral)
#   ether2 — Fibra ISP (link principal dos PCs, notebooks e diretoria)
#   ether3 — Reservado para um terceiro link futuro
#   ether4 — Rede local (LAN)
#   ether5 — Rede local (LAN) — junto com ether4 formam a bridge-lan
#
# Por que bridge e não routed ports?
#   Com bridge, ether4 e ether5 se comportam como um switch — dispositivos
#   em qualquer das duas portas estão na mesma rede e o roteador gerencia
#   tudo pelo IP da bridge. Simples, direto e sem overhead.
#
# Por que add-default-route=no no DHCP client?
#   As rotas padrão são gerenciadas manualmente no bloco 3. Se o RouterOS
#   criasse as rotas automaticamente aqui, elas entrariam em conflito com
#   o failover. Mantemos controle total.
#
# Depois de aplicar, verifique:
#   /interface bridge print
#   /interface bridge port print
#   /ip address print
#   /ip dhcp-client print
# ==============================================================================

/system identity set name="MikroTik-HEX-Principal"

# --- Comentários nas interfaces para facilitar a identificação visual ---
/interface ethernet
set [find name=ether1] comment="WAN1 - Starlink - principal NVR/NAS e backup geral"
set [find name=ether2] comment="WAN2 - Fibra ISP - principal para PCs e dominio"
set [find name=ether3] comment="WAN3 - Reservada - terceiro link futuro"
set [find name=ether4] comment="LAN - porta 4 - faz parte da bridge-lan"
set [find name=ether5] comment="LAN - porta 5 - faz parte da bridge-lan"

# --- Bridge que une ether4 e ether5 como uma só rede local ---
/interface bridge
add name=bridge-lan comment="Rede local — ether4 e ether5 juntas"

/interface bridge port
add interface=ether4 bridge=bridge-lan comment="LAN - porta 4"
add interface=ether5 bridge=bridge-lan comment="LAN - porta 5"

# --- IP fixo do roteador na rede local ---
/ip address
add address=192.168.88.1/24 interface=bridge-lan comment="Gateway da rede local 192.168.88.0/24"

# --- DHCP client nas WANs ---
# add-default-route=no é intencional: as rotas são gerenciadas no bloco 3
# use-peer-dns=no evita que o ISP sobrescreva os DNS configurados
/ip dhcp-client
add interface=ether1 disabled=no add-default-route=no use-peer-dns=no \
    comment="Recebe IP do Starlink (WAN1)"
add interface=ether2 disabled=no add-default-route=no use-peer-dns=no \
    comment="Recebe IP da Fibra ISP (WAN2)"

# --- WAN3 pré-configurada — descomentar quando o terceiro link chegar ---
# Se for DHCP:
# add interface=ether3 disabled=yes add-default-route=no use-peer-dns=no \
#     comment="Recebe IP do terceiro link (WAN3) — habilitar quando disponivel"
# Se for IP fixo:
# /ip address add address=X.X.X.X/XX interface=ether3 comment="WAN3 IP fixo"
