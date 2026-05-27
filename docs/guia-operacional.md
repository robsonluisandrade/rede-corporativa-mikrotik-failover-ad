# Guia Operacional — MikroTik hEX

> Procedimentos do dia a dia para gestão da rede.  
> Todos os comandos são executados no **Terminal do Winbox**.  
> Substitua `192.168.88.XXX` pelo IP real do dispositivo.

---

## Sumário

| Seção | O que faz |
|---|---|
| 1. Dispositivo novo apareceu | O que fazer quando um equipamento desconhecido se conecta |
| 2. Autorizar internet pela Fibra | Liberar internet + acesso à rede para PC ou notebook |
| 3. Autorizar internet pela Starlink | Liberar internet pela Starlink + acesso à rede |
| 4. Remover internet | Bloquear acesso à internet de qualquer dispositivo |
| 5. Trocar link Fibra ↔ Starlink | Mover dispositivo entre os dois links |
| 6. Autorizar acesso ao Winbox | Permitir que um PC gerencie o roteador |
| 7. Remover acesso ao Winbox | Revogar permissão de gerenciamento |
| 8. Mover para sem-internet | Bloquear internet mas manter na rede local |
| 9. Como funciona o isolamento de desconhecidos | Referência sobre o bloqueio automático |
| 10. Referência rápida | Tabela com todos os comandos |

---

## 1. Dispositivo Novo Apareceu na Rede

Quando um equipamento desconhecido se conecta, ele recebe IP entre `.2` e `.59` e fica **completamente isolado**:

| Tenta acessar | Resultado |
|---|---|
| Internet | Bloqueado |
| Servidor AD, NAS, NVR | Bloqueado |
| Câmeras e impressoras | Bloqueado |
| PCs do domínio e diretoria | Bloqueado |

### Como identificar

No Winbox → IP > DHCP Server > Leases: dispositivos com IP entre `.2` e `.59` são desconhecidos.

No Terminal:
```routeros
/ip dhcp-server lease print where dynamic=yes
```

### Fazer Make Static

1. IP > DHCP Server > Leases
2. Clique duas vezes no lease
3. Clique **Make Static**
4. Adicione um comentário descritivo (ex: `PC-Recepcao`, `Celular-Carlos`)
5. Clique OK

---

## 2. Autorizar Internet pela Fibra

Use para: PCs do domínio, notebooks, celulares da diretoria, APs.  
Além de liberar internet, o dispositivo passa a acessar toda a rede interna.

### Passo a passo

1. Faça Make Static se necessário (Seção 1)
2. Execute:

```routeros
/ip firewall address-list add list=com-internet address=192.168.88.XXX comment="Nome-do-dispositivo"
```

3. Verifique:

```routeros
/ip firewall address-list print where list=com-internet
```

4. Teste internet e acesso à rede no dispositivo

### Exemplo prático

**Situação:** PC da recepção chegou. IP: `192.168.88.165`. Deve ter internet pela Fibra.

```routeros
/ip firewall address-list add list=com-internet address=192.168.88.165 comment="PC-Recepcao"
```

**Resultado:** PC tem internet pela Fibra e acesso a toda a rede interna.

---

## 3. Autorizar Internet pela Starlink

Use para: celulares de funcionários, dispositivos que fazem downloads grandes, dispositivos da faixa `.60`–`.119`.

> ⚠️ São **dois comandos obrigatórios**. Se executar apenas o primeiro, o dispositivo terá internet mas pela Fibra, não pela Starlink.

### Passo a passo — dois comandos

**Comando 1 — adiciona na lista com-internet:**
```routeros
/ip firewall address-list add list=com-internet address=192.168.88.XXX comment="Nome-do-dispositivo"
```

**Comando 2 — força saída pela Starlink:**
```routeros
/ip firewall mangle add chain=prerouting src-address=192.168.88.XXX in-interface=bridge-lan action=mark-routing new-routing-mark=via-starlink passthrough=yes comment="Nome-do-dispositivo - Starlink"
```

### Verificar:
```routeros
/ip firewall mangle print
```

### Exemplo prático

**Situação:** Celular de Carlos (IP: `192.168.88.75`) precisa de internet pela Starlink.

```routeros
/ip firewall address-list add list=com-internet address=192.168.88.75 comment="Celular-Carlos"
/ip firewall mangle add chain=prerouting src-address=192.168.88.75 in-interface=bridge-lan action=mark-routing new-routing-mark=via-starlink passthrough=yes comment="Celular-Carlos - Starlink"
```

**Resultado:** Carlos tem internet pela Starlink e acesso à rede interna.

---

## 4. Remover Internet de um Dispositivo

### 4A. Da Fibra

```routeros
/ip firewall address-list remove [find list=com-internet address=192.168.88.XXX]
```

### 4B. Da Starlink — dois comandos

```routeros
/ip firewall address-list remove [find list=com-internet address=192.168.88.XXX]
/ip firewall mangle remove [find src-address=192.168.88.XXX]
```

> ⚠️ Para Starlink, esquecer o segundo comando deixa a regra de roteamento ativa — o dispositivo perde a internet, mas a regra fica suja na tabela.

---

## 5. Trocar Link (Fibra ↔ Starlink)

### 5A. Mover da Fibra para Starlink

```routeros
/ip firewall mangle add chain=prerouting src-address=192.168.88.XXX in-interface=bridge-lan action=mark-routing new-routing-mark=via-starlink passthrough=yes comment="Nome - Starlink"
```

### 5B. Mover da Starlink para Fibra

```routeros
/ip firewall mangle remove [find src-address=192.168.88.XXX]
```

> 💡 Sem a regra mangle, o dispositivo usa automaticamente a Fibra — que é o padrão da rede.

---

## 6. Autorizar Acesso ao Winbox

### Quem já tem acesso por padrão

| IP | Dispositivo |
|---|---|
| 192.168.88.234 | SRV-AD01 |
| 192.168.88.125 | Notebook-TI-01 (cabo) |
| 192.168.88.126 | Celular-TI-01 |
| 192.168.88.127 | Notebook-TI-01 (Wi-Fi) |
| .120 — .154 | Toda a faixa de diretoria e autorizados |
| .155 — .194 | Toda a faixa de PCs do domínio |

### Autorizar novo dispositivo

```routeros
/ip firewall address-list add list=acesso-winbox address=192.168.88.XXX comment="Nome-do-dispositivo"
```

> ⚠️ Autorize apenas TI e diretoria técnica. Quem tem acesso ao Winbox pode alterar qualquer configuração do roteador.

---

## 7. Remover Acesso ao Winbox

### Ver quem está autorizado

```routeros
/ip firewall address-list print where list=acesso-winbox
```

### Remover pelo IP

```routeros
/ip firewall address-list remove [find list=acesso-winbox address=192.168.88.XXX]
```

### Trocar IP autorizado (ex: notebook ganhou novo IP)

```routeros
/ip firewall address-list set [find list=acesso-winbox address=192.168.88.ANTIGO] address=192.168.88.NOVO
```

---

## 8. Mover para Sem-Internet

Útil para dispositivos que devem ficar na rede local mas sem acesso à internet.

### 8A. Dispositivo que usava a Fibra

```routeros
/ip firewall address-list remove [find list=com-internet address=192.168.88.XXX]
/ip firewall address-list add list=sem-internet address=192.168.88.XXX comment="Nome - sem internet"
```

### 8B. Dispositivo que usava a Starlink

```routeros
/ip firewall address-list remove [find list=com-internet address=192.168.88.XXX]
/ip firewall mangle remove [find src-address=192.168.88.XXX]
/ip firewall address-list add list=sem-internet address=192.168.88.XXX comment="Nome - sem internet"
```

---

## 9. Isolamento de Desconhecidos

Todo dispositivo que conectar na rede **sem cadastro** fica completamente isolado por padrão.

| Ação | Resultado |
|---|---|
| Conectar no Wi-Fi ou cabo | Sim — recebe IP entre .2 e .59 |
| Acessar internet | Não — bloqueado |
| Acessar servidor AD | Não — bloqueado |
| Acessar NAS | Não — bloqueado |
| Acessar NVR e câmeras | Não — bloqueado |
| Acessar impressoras | Não — bloqueado |
| Acessar PCs do domínio | Não — bloqueado |

### Como ver e autorizar

```routeros
# Ver desconhecidos ativos
/ip dhcp-server lease print where dynamic=yes

# Após Make Static, autorizar na Fibra:
/ip firewall address-list add list=com-internet address=192.168.88.XXX comment="Nome"

# Ou na Starlink (dois comandos — ver Seção 3)
```

### Dispositivos na lista sem-internet

Câmeras, impressoras e relógio de ponto estão em `sem-internet` e também não têm internet, mas:
- Câmeras comunicam com o NVR normalmente (tráfego interno LAN)
- Impressoras são acessadas pelos PCs normalmente (tráfego interno LAN)
- Relógio de ponto funciona na rede interna normalmente

---

## 10. Referência Rápida

### Internet

| Ação | Comando |
|---|---|
| Autorizar Fibra | `/ip firewall address-list add list=com-internet address=192.168.88.XXX comment="Nome"` |
| Autorizar Starlink (passo 1) | `/ip firewall address-list add list=com-internet address=192.168.88.XXX comment="Nome"` |
| Autorizar Starlink (passo 2) | `/ip firewall mangle add chain=prerouting src-address=192.168.88.XXX in-interface=bridge-lan action=mark-routing new-routing-mark=via-starlink passthrough=yes comment="Nome"` |
| Remover internet Fibra | `/ip firewall address-list remove [find list=com-internet address=192.168.88.XXX]` |
| Remover internet Starlink p1 | `/ip firewall address-list remove [find list=com-internet address=192.168.88.XXX]` |
| Remover internet Starlink p2 | `/ip firewall mangle remove [find src-address=192.168.88.XXX]` |
| Mover Fibra → Starlink | `/ip firewall mangle add chain=prerouting src-address=192.168.88.XXX in-interface=bridge-lan action=mark-routing new-routing-mark=via-starlink passthrough=yes comment="Nome"` |
| Mover Starlink → Fibra | `/ip firewall mangle remove [find src-address=192.168.88.XXX]` |
| Bloquear sem internet | `/ip firewall address-list add list=sem-internet address=192.168.88.XXX comment="Nome"` |

### Winbox

| Ação | Comando |
|---|---|
| Ver quem tem acesso | `/ip firewall address-list print where list=acesso-winbox` |
| Autorizar novo PC | `/ip firewall address-list add list=acesso-winbox address=192.168.88.XXX comment="Nome"` |
| Remover acesso | `/ip firewall address-list remove [find list=acesso-winbox address=192.168.88.XXX]` |
| Trocar IP | `/ip firewall address-list set [find list=acesso-winbox address=192.168.88.ANTIGO] address=192.168.88.NOVO` |

### Diagnóstico

| Ação | Comando |
|---|---|
| Ver todos os dispositivos | `/ip dhcp-server lease print` |
| Ver conectados agora | `/ip dhcp-server lease print where status=bound` |
| Ver desconhecidos | `/ip dhcp-server lease print where dynamic=yes` |
| Ver lista com-internet | `/ip firewall address-list print where list=com-internet` |
| Ver lista sem-internet | `/ip firewall address-list print where list=sem-internet` |
| Ver dispositivos protegidos | `/ip firewall address-list print where list=dispositivos-protegidos` |
| Ver logs do failover | `/log print where topics~"warning"` |
| Ver rotas ativas | `/ip route print where active=yes` |
| Ver regras mangle | `/ip firewall mangle print` |
| Ver filas QoS | `/queue tree print` |
| Ver estado dos links | `/tool netwatch print` |

---

*Guia Operacional — MikroTik hEX — Maio 2026*
