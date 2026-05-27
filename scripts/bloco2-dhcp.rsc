# ==============================================================================
# BLOCO 2 — Pools de IP, Servidor DHCP e Reservas por MAC
# ==============================================================================
#
# Hardware : MikroTik hEX (RB750Gr3)
# RouterOS : 7.22.3 stable
# Autor    : Robson Andrade
# Data     : Maio 2026
# Versão   : 2
#
# A lógica central deste bloco:
#   Cada dispositivo tem um MAC cadastrado e sempre recebe o mesmo IP.
#   Quem não tem cadastro cai no pool de desconhecidos (.2–.59) e fica
#   completamente isolado até ser autorizado manualmente.
#
# Organização das faixas:
#   .2   - .59  — Desconhecidos    (sem internet, sem acesso interno)
#   .60  - .119 — Autorizados Starlink (autorizados pela gestão)
#   .120 - .154 — Diretoria, TI e Autorizados (Fibra)
#   .155 - .194 — PCs do domínio  (Fibra)
#   .195 - .224 — Sem internet     (câmeras IP)
#   .225 - .233 — Sem internet     (impressoras e relógio de ponto)
#   .234        — Servidor AD      (IP fixo no SO — nunca DHCP)
#   .235 - .253 — Infraestrutura   (NVR, NAS, APs)
#
# Histórico de versões:
#   v1 — Maio 2026 — Versão inicial
#   v2 — Maio 2026 — Novos dispositivos (.128-.135) adicionados
#                    IP do relógio atualizado de .211 para .230
#
# Depois de aplicar, verifique:
#   /ip pool print
#   /ip dhcp-server print
#   /ip dhcp-server lease print
# ==============================================================================

/ip pool
add name=pool-desconhecidos    ranges=192.168.88.2-192.168.88.59 \
    comment="Desconhecidos — sem internet ate autorizacao"
add name=pool-starlink         ranges=192.168.88.60-192.168.88.119 \
    comment="Autorizados pela Starlink"
add name=pool-fibra-diretoria  ranges=192.168.88.120-192.168.88.154 \
    comment="Diretoria, TI e Autorizados — Fibra"
add name=pool-fibra-dominio    ranges=192.168.88.155-192.168.88.194 \
    comment="PCs do dominio — Fibra"
add name=pool-sem-internet     ranges=192.168.88.195-192.168.88.224 \
    comment="Sem internet — cameras IP"
add name=pool-impressoras      ranges=192.168.88.225-192.168.88.233 \
    comment="Sem internet — impressoras e relogio de ponto"
add name=pool-infra            ranges=192.168.88.235-192.168.88.253 \
    comment="Infraestrutura — NVR, NAS e APs"

# O servidor DHCP usa o pool de desconhecidos como padrão.
# Dispositivos com reserva estática recebem o IP cadastrado independente disso.
/ip dhcp-server
add name=dhcp-lan interface=bridge-lan address-pool=pool-desconhecidos \
    lease-time=8h disabled=no \
    comment="Servidor DHCP da rede local"

# DNS entregue aos clientes aponta para o servidor AD,
# que encaminha para 1.1.1.1 e 8.8.8.8 via DNS Forwarders.
/ip dhcp-server network
add address=192.168.88.0/24 gateway=192.168.88.1 \
    dns-server=192.168.88.234 \
    comment="Rede local — gateway e DNS via servidor AD"

# ==============================================================================
# RESERVAS ESTÁTICAS — MAC vinculado ao IP
# (MACs abaixo são exemplos fictícios para portfólio)
# ==============================================================================
/ip dhcp-server lease

# --- Infraestrutura (.235 em diante) ---
add mac-address=AA:BB:CC:00:01:01 address=192.168.88.235 comment="NAS-Synology — sai pela Starlink"
add mac-address=AA:BB:CC:00:01:02 address=192.168.88.236 comment="NVR-CFTV — sai pela Starlink"
add mac-address=AA:BB:CC:00:01:03 address=192.168.88.237 comment="AP-Producao — sai pela Fibra"
add mac-address=AA:BB:CC:00:01:04 address=192.168.88.238 comment="AP-Escritorio — sai pela Fibra"
add mac-address=AA:BB:CC:00:01:05 address=192.168.88.239 comment="AP-Deposito — sai pela Fibra"
add mac-address=AA:BB:CC:00:01:06 address=192.168.88.240 comment="AP-Portaria — sai pela Fibra"

# --- Servidor AD (.234) ---
# IP FIXO NO SO — a reserva aqui é só documentação, nunca deve receber via DHCP
add mac-address=AA:BB:CC:00:02:01 address=192.168.88.234 \
    comment="SRV-AD01 — IP FIXO NO SO — NAO ALTERAR"

# --- Impressoras e Relógio de Ponto (.225–.233) ---
add mac-address=AA:BB:CC:01:01:01 address=192.168.88.225 comment="Impressora-01 (Laser P&B)"
add mac-address=AA:BB:CC:01:01:02 address=192.168.88.226 comment="Impressora-02 (Laser P&B)"
add mac-address=AA:BB:CC:01:01:03 address=192.168.88.227 comment="Impressora-03 (Inkjet)"
add mac-address=AA:BB:CC:01:01:04 address=192.168.88.228 comment="Impressora-04 (Inkjet)"
add mac-address=AA:BB:CC:01:01:05 address=192.168.88.229 comment="Impressora-05 (Multifuncional)"
# ATENÇÃO: IP FIXO NO DISPOSITIVO — reserva aqui é só documentação
# IP atualizado de .211 para .230 (v2 — Maio 2026)
add mac-address=AA:BB:CC:01:02:01 address=192.168.88.230 \
    comment="Relogio-Ponto — IP FIXO NO DISPOSITIVO — NAO USAR DHCP"

# --- Câmeras IP (.195–.210) — sem acesso à internet ---
add mac-address=AA:BB:CC:02:00:01 address=192.168.88.195 comment="Camera-01"
add mac-address=AA:BB:CC:02:00:02 address=192.168.88.196 comment="Camera-02"
add mac-address=AA:BB:CC:02:00:03 address=192.168.88.197 comment="Camera-03"
add mac-address=AA:BB:CC:02:00:04 address=192.168.88.198 comment="Camera-04"
add mac-address=AA:BB:CC:02:00:05 address=192.168.88.199 comment="Camera-05"
add mac-address=AA:BB:CC:02:00:06 address=192.168.88.200 comment="Camera-06"
add mac-address=AA:BB:CC:02:00:07 address=192.168.88.201 comment="Camera-07"
add mac-address=AA:BB:CC:02:00:08 address=192.168.88.202 comment="Camera-08"
add mac-address=AA:BB:CC:02:00:09 address=192.168.88.203 comment="Camera-09"
add mac-address=AA:BB:CC:02:00:10 address=192.168.88.204 comment="Camera-10"
add mac-address=AA:BB:CC:02:00:11 address=192.168.88.205 comment="Camera-11"
add mac-address=AA:BB:CC:02:00:12 address=192.168.88.206 comment="Camera-12"
add mac-address=AA:BB:CC:02:00:13 address=192.168.88.207 comment="Camera-13"
add mac-address=AA:BB:CC:02:00:14 address=192.168.88.208 comment="Camera-14"
add mac-address=AA:BB:CC:02:00:15 address=192.168.88.209 comment="Camera-15"
add mac-address=AA:BB:CC:02:00:16 address=192.168.88.210 comment="Camera-16"

# --- PCs do domínio (.155–.194) — Fibra ---
add mac-address=AA:BB:CC:03:00:01 address=192.168.88.155 comment="PC-Comercial — dominio"
add mac-address=AA:BB:CC:03:00:02 address=192.168.88.156 comment="PC-Compras — dominio"
add mac-address=AA:BB:CC:03:00:03 address=192.168.88.157 comment="PC-Faturamento — dominio"
add mac-address=AA:BB:CC:03:00:04 address=192.168.88.158 comment="PC-Financeiro — dominio"
add mac-address=AA:BB:CC:03:00:05 address=192.168.88.159 comment="PC-Administracao — dominio"
add mac-address=AA:BB:CC:03:00:06 address=192.168.88.160 comment="PC-Laboratorio — dominio"
add mac-address=AA:BB:CC:03:00:07 address=192.168.88.161 comment="PC-Qualidade — dominio"

# --- Diretoria e TI (.120–.127) — Fibra + acesso Winbox ---
add mac-address=AA:BB:CC:04:00:01 address=192.168.88.120 comment="Notebook-Diretoria-01"
add mac-address=AA:BB:CC:04:00:02 address=192.168.88.121 comment="Celular-Diretoria-01"
add mac-address=AA:BB:CC:04:00:03 address=192.168.88.122 comment="Celular-Diretoria-02"
add mac-address=AA:BB:CC:04:00:04 address=192.168.88.123 comment="Celular-Diretoria-03"
add mac-address=AA:BB:CC:04:00:05 address=192.168.88.124 comment="Celular-Diretoria-04"
add mac-address=AA:BB:CC:04:01:01 address=192.168.88.125 comment="Notebook-TI-01-cabo — Winbox"
add mac-address=AA:BB:CC:04:01:02 address=192.168.88.126 comment="Celular-TI-01 — Winbox"
add mac-address=AA:BB:CC:04:01:03 address=192.168.88.127 comment="Notebook-TI-01-wifi — Winbox"

# --- Autorizados adicionais (.128–.135) — Fibra ---
add mac-address=AA:BB:CC:04:02:01 address=192.168.88.128 comment="Celular-Funcionario-01"
add mac-address=AA:BB:CC:04:02:02 address=192.168.88.129 comment="Celular-Funcionario-02"
add mac-address=AA:BB:CC:04:02:03 address=192.168.88.130 comment="Celular-Funcionario-03"
add mac-address=AA:BB:CC:04:02:04 address=192.168.88.131 comment="Celular-Funcionario-04"
add mac-address=AA:BB:CC:04:02:05 address=192.168.88.132 comment="Celular-Funcionario-05"
add mac-address=AA:BB:CC:04:02:06 address=192.168.88.133 comment="Celular-Funcionario-06"
add mac-address=AA:BB:CC:04:02:07 address=192.168.88.134 comment="Notebook-Diretoria-02-cabo"
add mac-address=AA:BB:CC:04:02:08 address=192.168.88.135 comment="Notebook-Diretoria-02-wifi"
