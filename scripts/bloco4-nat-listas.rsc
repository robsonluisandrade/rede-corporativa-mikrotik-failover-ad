# ==============================================================================
# BLOCO 4 — DNS, NAT e Listas de Controle de Acesso
# ==============================================================================
#
# Hardware : MikroTik hEX (RB750Gr3)
# RouterOS : 7.22.3 stable
# Autor    : Robson Andrade
# Data     : Maio 2026
# Versão   : 2
#
# Uma armadilha do dual WAN na mesma faixa:
#   Sem src-address no masquerade, o RouterOS pode criar entradas duplicadas
#   na tabela de NAT quando os dois links estão ativos — isso causa o problema
#   clássico do "conecta mas não navega" em dual WAN. O src-address=192.168.88.0/24
#   garante que cada regra de NAT se aplica apenas ao tráfego que já sabe que
#   vai sair por aquela interface.
#
# As listas de acesso funcionam como o núcleo do controle:
#   com-internet       — quem tem acesso à internet (qualquer link)
#   sem-internet       — quem não tem (câmeras, impressoras, relógio)
#   dispositivos-protegidos — infraestrutura que desconhecidos não podem acessar
#   acesso-winbox      — quem pode gerenciar o roteador
#
# Histórico de versões:
#   v1 — Maio 2026 — Versão inicial
#   v2 — Maio 2026 — Novos IPs .128-.135 adicionados em com-internet
#                    IP do relógio atualizado de .211 para .230
#
# Depois de aplicar, verifique:
#   /ip dns print
#   /ip firewall nat print      — não deve ter flag I (invalid)
#   /ip firewall address-list print
# ==============================================================================

# O roteador usa servidores externos como fallback.
# O servidor AD resolve os nomes internos e encaminha o restante para cá.
/ip dns
set servers=8.8.8.8,1.1.1.1 allow-remote-requests=yes cache-max-ttl=1d

# --- NAT com src-address — essencial para dual WAN na mesma faixa ---
/ip firewall nat
add chain=srcnat out-interface=ether1 src-address=192.168.88.0/24 \
    action=masquerade comment="NAT saida pelo Starlink"
add chain=srcnat out-interface=ether2 src-address=192.168.88.0/24 \
    action=masquerade comment="NAT saida pela Fibra ISP"
# Terceiro link — descomentar quando disponível
# add chain=srcnat out-interface=ether3 src-address=192.168.88.0/24 \
#     action=masquerade comment="NAT saida pelo terceiro link"

# ==============================================================================
# LISTAS DE CONTROLE DE ACESSO
# ==============================================================================
/ip firewall address-list

# --- Quem pode abrir o Winbox e gerenciar o roteador ---
# Restrito ao servidor AD, TI e PCs/notebooks do domínio e diretoria.
# NUNCA authorize dispositivos desconhecidos ou temporários nesta lista.
add list=acesso-winbox address=192.168.88.234   comment="SRV-AD01"
add list=acesso-winbox address=192.168.88.125   comment="Notebook-TI-01-cabo"
add list=acesso-winbox address=192.168.88.126   comment="Celular-TI-01"
add list=acesso-winbox address=192.168.88.127   comment="Notebook-TI-01-wifi"
add list=acesso-winbox address=192.168.88.155-192.168.88.194 comment="PCs do dominio"
add list=acesso-winbox address=192.168.88.120-192.168.88.154 comment="Diretoria e TI"

# --- Quem tem acesso à internet — Fibra ---
add list=com-internet address=192.168.88.234  comment="SRV-AD01 — Fibra"
# PCs do domínio
add list=com-internet address=192.168.88.155  comment="PC-Comercial — Fibra"
add list=com-internet address=192.168.88.156  comment="PC-Compras — Fibra"
add list=com-internet address=192.168.88.157  comment="PC-Faturamento — Fibra"
add list=com-internet address=192.168.88.158  comment="PC-Financeiro — Fibra"
add list=com-internet address=192.168.88.159  comment="PC-Administracao — Fibra"
add list=com-internet address=192.168.88.160  comment="PC-Laboratorio — Fibra"
add list=com-internet address=192.168.88.161  comment="PC-Qualidade — Fibra"
# Diretoria e TI
add list=com-internet address=192.168.88.120  comment="Notebook-Diretoria-01 — Fibra"
add list=com-internet address=192.168.88.121  comment="Celular-Diretoria-01 — Fibra"
add list=com-internet address=192.168.88.122  comment="Celular-Diretoria-02 — Fibra"
add list=com-internet address=192.168.88.123  comment="Celular-Diretoria-03 — Fibra"
add list=com-internet address=192.168.88.124  comment="Celular-Diretoria-04 — Fibra"
add list=com-internet address=192.168.88.125  comment="Notebook-TI-01-cabo — Fibra"
add list=com-internet address=192.168.88.126  comment="Celular-TI-01 — Fibra"
add list=com-internet address=192.168.88.127  comment="Notebook-TI-01-wifi — Fibra"
# Autorizados adicionais (v2)
add list=com-internet address=192.168.88.128  comment="Celular-Funcionario-01 — Fibra"
add list=com-internet address=192.168.88.129  comment="Celular-Funcionario-02 — Fibra"
add list=com-internet address=192.168.88.130  comment="Celular-Funcionario-03 — Fibra"
add list=com-internet address=192.168.88.131  comment="Celular-Funcionario-04 — Fibra"
add list=com-internet address=192.168.88.132  comment="Celular-Funcionario-05 — Fibra"
add list=com-internet address=192.168.88.133  comment="Celular-Funcionario-06 — Fibra"
add list=com-internet address=192.168.88.134  comment="Notebook-Diretoria-02-cabo — Fibra"
add list=com-internet address=192.168.88.135  comment="Notebook-Diretoria-02-wifi — Fibra"
# APs
add list=com-internet address=192.168.88.237  comment="AP-Producao — Fibra"
add list=com-internet address=192.168.88.238  comment="AP-Escritorio — Fibra"
add list=com-internet address=192.168.88.239  comment="AP-Deposito — Fibra"
add list=com-internet address=192.168.88.240  comment="AP-Portaria — Fibra"

# --- Quem tem acesso à internet — Starlink ---
# O roteamento específico é feito pelo mangle e routing rules no bloco 3
add list=com-internet address=192.168.88.235  comment="NAS-Synology — Starlink"
add list=com-internet address=192.168.88.236  comment="NVR-CFTV — Starlink"

# --- Quem NÃO tem acesso à internet ---
add list=sem-internet address=192.168.88.195  comment="Camera-01"
add list=sem-internet address=192.168.88.196  comment="Camera-02"
add list=sem-internet address=192.168.88.197  comment="Camera-03"
add list=sem-internet address=192.168.88.198  comment="Camera-04"
add list=sem-internet address=192.168.88.199  comment="Camera-05"
add list=sem-internet address=192.168.88.200  comment="Camera-06"
add list=sem-internet address=192.168.88.201  comment="Camera-07"
add list=sem-internet address=192.168.88.202  comment="Camera-08"
add list=sem-internet address=192.168.88.203  comment="Camera-09"
add list=sem-internet address=192.168.88.204  comment="Camera-10"
add list=sem-internet address=192.168.88.205  comment="Camera-11"
add list=sem-internet address=192.168.88.206  comment="Camera-12"
add list=sem-internet address=192.168.88.207  comment="Camera-13"
add list=sem-internet address=192.168.88.208  comment="Camera-14"
add list=sem-internet address=192.168.88.209  comment="Camera-15"
add list=sem-internet address=192.168.88.210  comment="Camera-16"
# Relógio de ponto — IP fixo no dispositivo (atualizado de .211 para .230 em v2)
add list=sem-internet address=192.168.88.230  comment="Relogio-Ponto — IP fixo no dispositivo"
# Impressoras
add list=sem-internet address=192.168.88.225  comment="Impressora-01"
add list=sem-internet address=192.168.88.226  comment="Impressora-02"
add list=sem-internet address=192.168.88.227  comment="Impressora-03"
add list=sem-internet address=192.168.88.228  comment="Impressora-04"
add list=sem-internet address=192.168.88.229  comment="Impressora-05"
# Pool de desconhecidos — isolados até autorização manual
add list=sem-internet address=192.168.88.2-192.168.88.59 \
    comment="Pool de desconhecidos — sem internet ate autorizacao"

# --- Infraestrutura protegida — desconhecidos não devem acessar estes IPs ---
# Um celular desconhecido não pode chegar no servidor AD, no NAS ou nas câmeras,
# mesmo estando na mesma rede física.
add list=dispositivos-protegidos address=192.168.88.234   comment="SRV-AD01"
add list=dispositivos-protegidos address=192.168.88.235   comment="NAS-Synology"
add list=dispositivos-protegidos address=192.168.88.236   comment="NVR-CFTV"
add list=dispositivos-protegidos address=192.168.88.195-192.168.88.210 comment="Cameras"
add list=dispositivos-protegidos address=192.168.88.225-192.168.88.229 comment="Impressoras"
add list=dispositivos-protegidos address=192.168.88.155-192.168.88.194 comment="PCs do dominio"
add list=dispositivos-protegidos address=192.168.88.120-192.168.88.154 comment="Diretoria e TI"
