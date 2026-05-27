# Reestruturação Completa de Rede Corporativa com MikroTik hEX

> Projeto real de infraestrutura desenvolvido e implementado do zero em uma empresa industrial de médio porte.  
> Dual WAN com failover automático · Segmentação por faixas de IP · Firewall com 25 regras · QoS por prioridade e horário · Active Directory · Acesso remoto via VPN

---

## Sobre o projeto

A rede da empresa estava crescendo sem nenhum planejamento. Qualquer dispositivo que chegasse entrava, pegava IP e tinha acesso livre a tudo — câmeras, NAS, impressoras, servidores. Não havia separação de ambiente, não havia controle de quem tinha internet ou não, e o failover entre os dois links de internet simplesmente não funcionava.

Quando um link caía, precisávamos entrar no roteador manualmente, desativar uma interface e ativar a outra. Isso acontecia fora do horário comercial, atrapalhava a operação e gerava dependência constante de intervenção humana para algo que deveria ser automático.

A decisão foi parar tudo e refazer do zero — com planejamento, com testes e com documentação.

---

## O ambiente

| Componente | Especificação |
|---|---|
| Roteador | MikroTik hEX (RB750Gr3) — RouterOS 7.22.3 |
| Rede LAN | 192.168.88.0/24 — Gateway: 192.168.88.1 |
| Link principal | Fibra (400 Mbps) — preferencial para PCs e diretoria |
| Link secundário | Starlink (400 Mbps) — preferencial para NVR e NAS |
| Servidor AD | Windows Server 2019 — IP fixo 192.168.88.234 |
| NAS | Synology — IP 192.168.88.235 |
| NVR + câmeras | 16 câmeras IP — IP 192.168.88.236 |
| Access Points | 4 APs — todos via Fibra |
| Impressoras | 5 — rede local apenas |
| PCs | 7 — ingressados no domínio |

---

## O problema que mais deu trabalho

Quando comecei a configurar o failover, esbarrei em algo que não é óbvio à primeira vista: **os dois links de internet estavam na mesma faixa de IP**.

A Fibra e o Starlink entregavam endereços em `192.168.1.x`, com gateways diferentes — `192.168.1.254` e `192.168.1.1`. Com os dois cabos conectados ao mesmo tempo, o MikroTik ficava confuso: não sabia por qual interface chegar em cada gateway. Ping ora funcionava, ora não. Pacotes eram perdidos sem motivo aparente. Ajustar distância nas rotas funcionava no papel, mas não resolvia o problema real.

A solução foi criar **rotas `/32` para cada gateway**, forçando o roteador a saber exatamente por qual interface cada um é acessado:

```routeros
/ip route add dst-address=192.168.1.254/32 gateway=ether2   # ancora o gateway da Fibra na ether2
/ip route add dst-address=192.168.1.1/32   gateway=ether1   # ancora o gateway do Starlink na ether1
```

Combinado com **routing rules** do RouterOS 7 e **NAT com src-address** nos dois links, o conflito foi resolvido definitivamente. A lição que ficou: quando dois links estão na mesma faixa, o roteador precisa de uma âncora explícita para saber o caminho de cada gateway — sem isso, a instabilidade é certa.

---

## Arquitetura da rede

```
Internet
   │
   ├── ether1 ─── Starlink (WAN1)    → NVR e NAS (link preferencial)
   │                                  → backup geral (fallback)
   │
   ├── ether2 ─── Fibra WSP (WAN2)   → PCs, notebooks, diretoria, APs
   │
   ├── ether3 ─── Reservada (WAN3)   → pré-configurada para 3º link futuro
   │
   └── bridge-lan (ether4 + ether5)
          │
          ├── .2   – .59   → Desconhecidos       (sem internet, isolados)
          ├── .60  – .119  → Autorizados Starlink (diretoria autoriza)
          ├── .120 – .154  → Diretoria e TI       (Fibra)
          ├── .155 – .194  → PCs do domínio       (Fibra)
          ├── .195 – .224  → Sem internet          (câmeras)
          ├── .225 – .233  → Sem internet          (impressoras e relógio)
          ├── .234         → Servidor AD           (IP fixo no SO)
          └── .235 – .253  → Infraestrutura        (NVR, NAS, APs)
```

---

## O que foi implementado

### Dual WAN com failover automático e bidirecional

O Netwatch monitora cada link a cada 10 segundos. Quando um link para de responder por 3 falhas consecutivas, o script desativa aquela rota e o tráfego migra automaticamente. Quando o link volta, a rota é reabilitada — sem tocar em nada.

```
Fibra cai      → tráfego migra para Starlink automaticamente
Fibra volta    → balanceamento original restaurado
Starlink cai   → NVR e NAS migram para Fibra automaticamente
Starlink volta → NVR e NAS voltam para Starlink
```

Nenhum dispositivo fica sem internet em nenhum cenário.

### Roteamento por dispositivo (Policy-Based Routing)

| Dispositivo | Link | Motivo |
|---|---|---|
| PCs do domínio | Fibra | Velocidade e prioridade no ambiente de trabalho |
| Diretoria e TI | Fibra | Mesma lógica — acesso privilegiado |
| NVR (câmeras) | Starlink | Streaming libera banda da Fibra para quem trabalha |
| NAS Synology | Starlink | Backups em nuvem não impactam o expediente |
| Câmeras IP | Sem internet | Comunicam apenas com o NVR na rede local |
| Impressoras | Sem internet | Rede local apenas |

### Controle de acesso por MAC address

Cada dispositivo tem um MAC registrado no DHCP e sempre recebe o mesmo IP. Quem não tem cadastro cai na faixa de desconhecidos (`.2` – `.59`) e fica completamente isolado — sem internet e sem acesso a nenhum dispositivo interno — até ser autorizado manualmente.

### Isolamento em vez de VLANs

A forma mais correta de separar ambientes em redes corporativas seria usando VLANs. Mas o parque de switches da empresa era misto: parte suportava VLAN e parte não. Implementar VLANs parcialmente criaria brechas piores do que não usar nenhuma.

A solução foi fazer a separação por **faixas de IP dentro da mesma rede**, com o controle de tráfego feito via firewall no MikroTik. Não é tão elegante quanto VLANs, mas entrega o isolamento necessário com o hardware disponível. Quando os switches forem homogeneizados, a migração para VLANs pode ser feita sem grandes mudanças — as faixas já estão organizadas pensando nisso.

### Firewall com 25 regras

Organizado em duas chains:

- **INPUT (14 regras):** protege o próprio roteador. Bloqueio total de acesso externo, Winbox restrito à rede local para IPs autorizados, detecção de port scan com banimento automático por 1 semana, proteção contra SYN flood, descarte de pacotes inválidos.
- **FORWARD (11 regras):** controla o tráfego passante. Câmeras e impressoras não acessam a internet, desconhecidos não chegam na infraestrutura interna, dispositivos autorizados saem normalmente.

### QoS com Queue Tree e PCQ

Com dois links de 400 Mbps e vários dispositivos, o QoS foi implementado para garantir que nenhum equipamento monopolize a banda.

**Fibra:** Servidor AD (prioridade 1) → PCs e notebooks (prioridade 2) → celulares (prioridade 4)  
**Starlink (dia):** NVR (prioridade 1) → NAS com mín. 20 Mbps (prioridade 2) → celulares com teto de 30 Mbps  
**Starlink (noite):** NAS sobe para prioridade 1 para o backup — teto de 30 Mbps dos celulares mantido

O Scheduler troca as prioridades automaticamente às 06h e às 18h. Quando a Fibra cai, o script de failover remove o teto dos celulares na Starlink para não prejudicar quem migrou.

---

## Detalhe que me ensinou algo

Durante a implementação, sete câmeras não recebiam os IPs reservados — ficavam presas na faixa de desconhecidos mesmo após várias reinicializações. Depois de investigar, descobri que o MAC registrado era `30:1E:1F:xx:xx:xx` mas o MAC real das câmeras era `30:E1:F1:xx:xx:xx` — os bytes estavam com a ordem invertida.

Uma diferença de três bytes que invalidava todas as reservas. Corrigi os MACs e as câmeras passaram a pegar os IPs certos na primeira tentativa. Esse tipo de coisa só aparece quando você está com a mão na massa.

---

## Estrutura do repositório

```
📁 mikrotik-hex-rede-corporativa/
│
├── README.md                              → Você está aqui (Etapa 1)
├── documentacao-ad-infraestrutura.md      → Etapa 2: AD, GPO, acesso remoto, backups
│
├── scripts/
│   ├── bloco1-bridge-interfaces.rsc   → interfaces, bridge LAN, DHCP client nas WANs
│   ├── bloco2-dhcp.rsc                → pools de IP, servidor DHCP, reservas por MAC
│   ├── bloco3-rotas.rsc               → rotas, tabelas de roteamento, mangle, routing rules
│   ├── bloco4-nat-listas.rsc          → DNS, NAT, listas de controle de acesso
│   ├── bloco5-firewall.rsc            → 25 regras de firewall (input + forward)
│   ├── bloco6-failover.rsc            → failover automático, NTP, serviços e segurança final
│   └── bloco7-queue.rsc               → QoS com Queue Tree, PCQ e Scheduler
│
└── docs/
    ├── mapa-de-ips.md                 → mapa completo de dispositivos (IP, MAC, acesso)
    ├── guia-operacional.md            → procedimentos do dia a dia para gestão da rede
    └── documentacao-tecnica.md        → arquitetura completa e referência técnica
```

### Como aplicar os scripts

Os scripts foram desenvolvidos para serem aplicados **na ordem dos blocos**, um por vez, via Terminal do Winbox ou SSH:

```bash
# No terminal do Winbox ou SSH:
# Cole o conteúdo de cada bloco e execute
# Aguarde a confirmação de cada bloco antes de passar para o próximo

# Ordem obrigatória:
# bloco1 → bloco2 → bloco3 → bloco4 → bloco5 → bloco6 → bloco7
```

> ⚠️ **Atenção:** aplique o bloco 5 (firewall) conectado via cabo, não pelo Wi-Fi. Após aplicar, acesso externo ao roteador é bloqueado.

---

## Etapas do projeto

- [x] **Etapa 1 — MikroTik:** reestruturação da rede, failover, QoS e firewall *(este arquivo)*
- [x] **Etapa 2 — Servidor:** Active Directory, GPO, acesso remoto, backups e serviços → [`documentacao-ad-infraestrutura.md`](documentacao-ad-infraestrutura.md)

---

## Tecnologias

`MikroTik RouterOS 7.22.3` `Dual WAN` `Policy-Based Routing` `Netwatch` `Firewall Stateful` `Queue Tree` `PCQ` `QoS` `Active Directory` `Windows Server 2019` `GPO` `SQL Server 2017` `Tailscale VPN` `RustDesk` `Synology DSM` `NVR Intelbras` `ISO 27001` `LGPD`

---

## Sobre mim

Sou **Robson Andrade**, Especialista Sênior em Infraestrutura de TI com mais de 20 anos de experiência em redes, servidores e suporte técnico. Atuo desde 2022 na área industrial, onde sou responsável por toda a infraestrutura de TI — de servidores Windows e Linux a redes corporativas com MikroTik, gestão de e-mails, arquivos e CFTV.

Formado em Análise e Desenvolvimento de Sistemas, com pós-graduações em andamento em Arquitetura e Gestão de Infraestrutura em TI, Segurança da Informação, Perícia Cibernética e Computação em Nuvem.

📞 +55 (92) 9 8187-7120  
💼 [linkedin.com/in/robsonandradee](https://www.linkedin.com/in/robsonandradee)  
📧 robsonluisandrade@gmail.com

---

*Projeto desenvolvido e documentado por Robson Andrade — Maio de 2026*
