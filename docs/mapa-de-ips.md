# Mapa de IPs da Rede

> Rede 192.168.88.0/24 — Gateway: 192.168.88.1  
> MikroTik hEX (RB750Gr3) — RouterOS 7.22.3  
> *(Dados fictícios para fins de portfólio — MACs e nomes de dispositivos são exemplos)*

---

## Faixas de IP

| Faixa        | Grupo                          | Qtd    | Internet                           |
| ------------ | ------------------------------ | ------ | ---------------------------------- |
| .2 — .59     | Desconhecidos                  | 58 IPs | Sem internet até autorização        |
| .60 — .119   | Autorizados Starlink           | 60 IPs | Starlink — gestão autoriza          |
| .120 — .154  | Diretoria, TI e Autorizados    | 35 IPs | Fibra                              |
| .155 — .194  | PCs do domínio                 | 40 IPs | Fibra — Zabbix Agent 2             |
| .195 — .224  | Câmeras IP                     | 30 IPs | Sem internet                       |
| .225 — .233  | Impressoras e Relógio          | 9 IPs  | Sem internet                       |
| .234         | Servidor AD                    | 1 IP   | Sem internet direta (VPN)          |
| .235 — .253  | Infraestrutura (NVR, NAS, APs, Zabbix) | 19 IPs | NVR/NAS: Starlink — APs/Zabbix: Fibra |

---

## Infraestrutura — .235 a .253

| IP             | MAC*              | Dispositivo  | Internet | Link    | Obs                                  |
| -------------- | ----------------- | ------------ | -------- | ------- | ------------------------------------ |
| 192.168.88.235 | AA:BB:CC:00:01:01 | NAS-Synology | Sim      | Starlink| SNMP monitorado pelo Zabbix          |
| 192.168.88.236 | AA:BB:CC:00:01:02 | NVR-CFTV     | Sim      | Starlink|                                      |
| 192.168.88.237 | AA:BB:CC:00:01:03 | AP-Producao  | Sim      | Fibra   |                                      |
| 192.168.88.238 | AA:BB:CC:00:01:04 | AP-Escritorio| Sim      | Fibra   |                                      |
| 192.168.88.239 | AA:BB:CC:00:01:05 | AP-Deposito  | Sim      | Fibra   |                                      |
| 192.168.88.240 | AA:BB:CC:00:01:06 | AP-Portaria  | Sim      | Fibra   |                                      |
| 192.168.88.242 | AA:BB:CC:00:03:01 | SRV-Zabbix   | Sim      | Fibra   | VM Ubuntu 22.04 — Hyper-V no SRV-AD01|

---

## Servidor AD — .234

| IP             | MAC*              | Dispositivo | Obs                                                   |
| -------------- | ----------------- | ----------- | ----------------------------------------------------- |
| 192.168.88.234 | AA:BB:CC:00:02:01 | SRV-AD01    | **IP FIXO NO SO — NUNCA USAR DHCP** — Zabbix Agent 2  |

---

## Impressoras e Relógio de Ponto — .225 a .233

| IP             | MAC*              | Dispositivo             | Internet | Obs                              |
| -------------- | ----------------- | ----------------------- | -------- | -------------------------------- |
| 192.168.88.225 | AA:BB:CC:01:01:01 | Impressora-01 (Laser P&B)   | Não  | SNMP monitorado pelo Zabbix      |
| 192.168.88.226 | AA:BB:CC:01:01:02 | Impressora-02 (Laser P&B)   | Não  | Rede local apenas                |
| 192.168.88.227 | AA:BB:CC:01:01:03 | Impressora-03 (Inkjet)      | Não  | Rede local apenas                |
| 192.168.88.228 | AA:BB:CC:01:01:04 | Impressora-04 (Inkjet)      | Não  | Rede local apenas                |
| 192.168.88.229 | AA:BB:CC:01:01:05 | Impressora-05 (Multifuncional)| Não| SNMP monitorado pelo Zabbix      |
| 192.168.88.230 | AA:BB:CC:01:02:01 | Relogio-Ponto               | Não  | **IP FIXO NO DISPOSITIVO**       |

---

## Câmeras IP — .195 a .210

| IP             | MAC*              | Câmera    | Internet |
| -------------- | ----------------- | --------- | -------- |
| 192.168.88.195 | AA:BB:CC:02:00:01 | Camera-01 | Não      |
| 192.168.88.196 | AA:BB:CC:02:00:02 | Camera-02 | Não      |
| 192.168.88.197 | AA:BB:CC:02:00:03 | Camera-03 | Não      |
| 192.168.88.198 | AA:BB:CC:02:00:04 | Camera-04 | Não      |
| 192.168.88.199 | AA:BB:CC:02:00:05 | Camera-05 | Não      |
| 192.168.88.200 | AA:BB:CC:02:00:06 | Camera-06 | Não      |
| 192.168.88.201 | AA:BB:CC:02:00:07 | Camera-07 | Não      |
| 192.168.88.202 | AA:BB:CC:02:00:08 | Camera-08 | Não      |
| 192.168.88.203 | AA:BB:CC:02:00:09 | Camera-09 | Não      |
| 192.168.88.204 | AA:BB:CC:02:00:10 | Camera-10 | Não      |
| 192.168.88.205 | AA:BB:CC:02:00:11 | Camera-11 | Não      |
| 192.168.88.206 | AA:BB:CC:02:00:12 | Camera-12 | Não      |
| 192.168.88.207 | AA:BB:CC:02:00:13 | Camera-13 | Não      |
| 192.168.88.208 | AA:BB:CC:02:00:14 | Camera-14 | Não      |
| 192.168.88.209 | AA:BB:CC:02:00:15 | Camera-15 | Não      |
| 192.168.88.210 | AA:BB:CC:02:00:16 | Camera-16 | Não      |

---

## PCs do Domínio — .155 a .194 — Fibra

| IP             | MAC*              | Dispositivo      | Internet    | Winbox | Zabbix  |
| -------------- | ----------------- | ---------------- | ----------- | ------ | ------- |
| 192.168.88.155 | AA:BB:CC:03:00:01 | PC-Comercial     | Sim — Fibra | Sim    | Agent 2 |
| 192.168.88.156 | AA:BB:CC:03:00:02 | PC-Compras       | Sim — Fibra | Sim    | Agent 2 |
| 192.168.88.157 | AA:BB:CC:03:00:03 | PC-Faturamento   | Sim — Fibra | Sim    | Agent 2 |
| 192.168.88.158 | AA:BB:CC:03:00:04 | PC-Financeiro    | Sim — Fibra | Sim    | Agent 2 |
| 192.168.88.159 | AA:BB:CC:03:00:05 | PC-Administracao | Sim — Fibra | Sim    | Agent 2 |
| 192.168.88.160 | AA:BB:CC:03:00:06 | PC-Laboratorio   | Sim — Fibra | Sim    | Agent 2 |
| 192.168.88.161 | AA:BB:CC:03:00:07 | PC-Qualidade     | Sim — Fibra | Sim    | Agent 2 |

---

## Diretoria, TI e Autorizados — .120 a .154 — Fibra

| IP             | MAC*              | Dispositivo                | Internet    | Winbox |
| -------------- | ----------------- | -------------------------- | ----------- | ------ |
| 192.168.88.120 | AA:BB:CC:04:00:01 | Notebook-Diretoria-01      | Sim — Fibra | Sim    |
| 192.168.88.121 | AA:BB:CC:04:00:02 | Celular-Diretoria-01       | Sim — Fibra | Sim    |
| 192.168.88.122 | AA:BB:CC:04:00:03 | Celular-Diretoria-02       | Sim — Fibra | Sim    |
| 192.168.88.123 | AA:BB:CC:04:00:04 | Celular-Diretoria-03       | Sim — Fibra | Sim    |
| 192.168.88.124 | AA:BB:CC:04:00:05 | Celular-Diretoria-04       | Sim — Fibra | Sim    |
| 192.168.88.125 | AA:BB:CC:04:01:01 | Notebook-TI-01-cabo        | Sim — Fibra | Sim    |
| 192.168.88.126 | AA:BB:CC:04:01:02 | Celular-TI-01              | Sim — Fibra | Sim    |
| 192.168.88.127 | AA:BB:CC:04:01:03 | Notebook-TI-01-wifi        | Sim — Fibra | Sim    |
| 192.168.88.128 | AA:BB:CC:04:02:01 | Celular-Funcionario-01     | Sim — Fibra | Não    |
| 192.168.88.129 | AA:BB:CC:04:02:02 | Celular-Funcionario-02     | Sim — Fibra | Não    |
| 192.168.88.130 | AA:BB:CC:04:02:03 | Celular-Funcionario-03     | Sim — Fibra | Não    |
| 192.168.88.131 | AA:BB:CC:04:02:04 | Celular-Funcionario-04     | Sim — Fibra | Não    |
| 192.168.88.132 | AA:BB:CC:04:02:05 | Celular-Funcionario-05     | Sim — Fibra | Não    |
| 192.168.88.133 | AA:BB:CC:04:02:06 | Celular-Funcionario-06     | Sim — Fibra | Não    |
| 192.168.88.134 | AA:BB:CC:04:02:07 | Notebook-Diretoria-02-cabo | Sim — Fibra | Sim    |
| 192.168.88.135 | AA:BB:CC:04:02:08 | Notebook-Diretoria-02-wifi | Sim — Fibra | Sim    |

---

## Autorizados Starlink — .60 a .119

Faixa reservada para dispositivos que a gestão autorizar com internet pela Starlink. Adicionar conforme necessário — veja o guia operacional para o comando.

| IP          | MAC*       | Dispositivo          | Internet |
| ----------- | ---------- | -------------------- | -------- |
| .60 — .119  | (a definir)| Aguardando autorização | Starlink|

---

## Pool Desconhecidos — .2 a .59

Dispositivos sem cadastro recebem IP nesta faixa e ficam **completamente isolados** — sem internet e sem acesso a nenhum dispositivo interno.

Quando aparecer um desconhecido:
`IP > DHCP Server > Leases > Make Static > autorizar ou ignorar`

| IP         | Status                                          |
| ---------- | ----------------------------------------------- |
| .2 — .59   | Dinâmico — sem internet, sem acesso interno     |

---

*\* MACs neste documento são fictícios para fins de portfólio.*

*Mapa de IPs — MikroTik hEX — 192.168.88.0/24 — Junho 2026*
