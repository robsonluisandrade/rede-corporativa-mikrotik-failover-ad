# ==============================================================================
# BLOCO 5 — Firewall (25 regras)
# ==============================================================================
#
# Hardware : MikroTik hEX (RB750Gr3)
# RouterOS : 7.22.3 stable
# Autor    : Robson Andrade
# Data     : Maio 2026
#
# O firewall foi construído em camadas:
#   Chain INPUT  (14 regras) — protege o próprio roteador
#   Chain FORWARD (11 regras) — controla o tráfego que passa pelo roteador
#
# Antes desse firewall, os logs do MikroTik registravam tentativas de login
# externo via Winbox — IPs estrangeiros tentando acesso com usuários como
# 'admin', 'root' e 'moblocal' em sequência, típico de ataque automatizado
# de força bruta. Com essas 25 regras, nenhuma porta está acessível de fora.
#
# ⚠️ ATENÇÃO: aplique este bloco conectado pelo servidor AD (.234) ou pelo
#    notebook do TI (.125 ou .127) via cabo — não pelo Wi-Fi.
#    Após aplicar, acesso externo ao roteador é bloqueado permanentemente.
#
# Depois de aplicar, verifique:
#   /ip firewall filter print count-only   → deve retornar 25
#   /ip firewall filter print
# ==============================================================================

/ip firewall filter

# ==============================================================================
# PROTEÇÃO DO ROTEADOR — Chain INPUT (14 regras)
# ==============================================================================

# Conexões já estabelecidas passam direto — sem isso o próprio roteador
# ficaria sem resposta após a primeira troca de pacotes.
add chain=input connection-state=established,related action=accept \
    comment="Aceita conexoes ja estabelecidas"

# Pacotes inválidos são silenciosamente descartados.
add chain=input connection-state=invalid action=drop \
    comment="Descarta pacotes invalidos"

# Port scan detection: registra o IP que está varrendo portas em uma lista
# negra por 1 semana. A segunda regra bloqueia quem já foi registrado.
add chain=input protocol=tcp psd=21,3s,3,1 \
    action=add-src-to-address-list \
    address-list=port-scanners address-list-timeout=1w \
    comment="Detecta port scan e registra o IP por 1 semana"

add chain=input src-address-list=port-scanners action=drop \
    comment="Bloqueia IPs detectados como port scanners"

# Nenhuma porta do roteador está acessível de fora — nem ping, nem Winbox, nada.
add chain=input in-interface=ether1 action=drop \
    comment="Bloqueia todo acesso externo pelo Starlink"

add chain=input in-interface=ether2 action=drop \
    comment="Bloqueia todo acesso externo pela Fibra"

add chain=input in-interface=ether3 action=drop \
    comment="Bloqueia todo acesso externo pelo terceiro link"

# Ping interno liberado — útil para diagnóstico na rede local.
add chain=input in-interface=bridge-lan protocol=icmp action=accept \
    comment="Permite ping dentro da rede local"

# DHCP precisa funcionar para os dispositivos pegarem IP.
add chain=input in-interface=bridge-lan protocol=udp dst-port=67 \
    action=accept comment="Permite DHCP"

# DNS aceito apenas do servidor AD — ele faz o encaminhamento externo.
# Aceitar DNS de qualquer IP da rede local abriria o roteador como resolver
# público para qualquer dispositivo que aparecesse na rede.
add chain=input in-interface=bridge-lan src-address=192.168.88.234 \
    protocol=udp dst-port=53 action=accept \
    comment="Permite DNS UDP via servidor AD"

add chain=input in-interface=bridge-lan src-address=192.168.88.234 \
    protocol=tcp dst-port=53 action=accept \
    comment="Permite DNS TCP via servidor AD"

# Winbox restrito à lista acesso-winbox — somente IPs autorizados.
add chain=input in-interface=bridge-lan src-address-list=acesso-winbox \
    protocol=tcp dst-port=8291 action=accept \
    comment="Winbox — apenas para IPs autorizados"

add chain=input protocol=tcp dst-port=8291 action=drop \
    comment="Winbox — bloqueia qualquer outro IP"

# Tudo que não foi explicitamente permitido é descartado.
add chain=input action=drop \
    comment="Descarta tudo que nao foi autorizado"

# ==============================================================================
# CONTROLE DO TRÁFEGO PASSANTE — Chain FORWARD (11 regras)
# ==============================================================================

# Conexões em andamento passam sem reavaliação — melhora significativa
# de performance em ambientes com muitos dispositivos.
add chain=forward connection-state=established,related action=accept \
    comment="Aceita conexoes ja em andamento"

add chain=forward connection-state=invalid action=drop \
    comment="Descarta pacotes invalidos no trafego passante"

# Proteção básica contra SYN flood — descarta pacotes TCP que chegam com SYN
# mas com MSS fora do range esperado para conexões legítimas.
add chain=forward protocol=tcp connection-state=new \
    tcp-flags=syn tcp-mss=!0-1460 action=drop \
    comment="Bloqueia tentativas de SYN flood"

# Desconhecidos (faixa .2–.59) não chegam na infraestrutura interna.
# Um celular desconhecido na rede Wi-Fi pode se comunicar com outros
# desconhecidos, mas não chega ao servidor AD, NAS, câmeras ou PCs.
add chain=forward src-address=192.168.88.2-192.168.88.59 \
    dst-address-list=dispositivos-protegidos action=drop \
    comment="Desconhecidos nao acessam infraestrutura interna"

# Tráfego interno entre dispositivos da rede local passa livremente.
# Câmeras falam com o NVR, PCs acessam impressoras, etc.
add chain=forward in-interface=bridge-lan out-interface=bridge-lan \
    action=accept comment="Libera comunicacao dentro da rede local"

# Câmeras, impressoras e relógio não saem para a internet.
add chain=forward src-address-list=sem-internet out-interface=ether1 \
    action=drop comment="Sem internet — bloqueia saida pelo Starlink"

add chain=forward src-address-list=sem-internet out-interface=ether2 \
    action=drop comment="Sem internet — bloqueia saida pela Fibra"

# Dispositivos autorizados saem pela internet normalmente.
add chain=forward src-address-list=com-internet out-interface=ether1 \
    action=accept comment="Autorizado — libera saida pelo Starlink"

add chain=forward src-address-list=com-internet out-interface=ether2 \
    action=accept comment="Autorizado — libera saida pela Fibra"

# Qualquer dispositivo que não estava em nenhuma das listas e tentar sair
# é bloqueado silenciosamente.
add chain=forward out-interface=ether1 action=drop \
    comment="Bloqueia Starlink para dispositivos nao autorizados"

add chain=forward out-interface=ether2 action=drop \
    comment="Bloqueia Fibra para dispositivos nao autorizados"
