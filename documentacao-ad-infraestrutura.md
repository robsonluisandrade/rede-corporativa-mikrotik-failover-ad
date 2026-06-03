# Etapa 2 — Active Directory, Acesso Remoto, Backups e Serviços

> Continuação do projeto de reestruturação de infraestrutura corporativa.  
> Parte 1 + Etapa 3 (Zabbix): [MikroTik hEX — Dual WAN, Firewall, QoS, Segmentação e Monitoramento](README.md)

---

## Por que essa etapa existe

Com a rede estável — failover funcionando, isolamento por faixas de IP e firewall com 25 regras — veio a próxima camada: **organizar quem acessa o quê e garantir que os dados da empresa estejam protegidos**.

Os computadores não tinham domínio. Cada máquina era um mundo separado, com suas próprias contas locais, suas próprias senhas, suas próprias configurações. Não havia política de grupo, não havia controle centralizado de usuários, não havia acesso remoto seguro, e o backup era basicamente manual — quando alguém lembrava.

O objetivo dessa etapa foi resolver tudo isso de forma integrada.

---

## Active Directory e Domínio

Foi criado o domínio **empresa.local** em um servidor Windows Server 2019, que passou a funcionar como controlador de domínio (DC), servidor DNS e servidor de arquivos simultaneamente. O servidor recebeu IP fixo `192.168.88.234` — o mesmo endereço que já estava reservado no MikroTik desde a Etapa 1.

O DHCP continua sendo feito pelo MikroTik. O DNS das máquinas foi apontado para o servidor AD, que encaminha as consultas externas para `1.1.1.1` e `8.8.8.8` via DNS Forwarders. Essa separação funciona bem: o MikroTik distribui os IPs, o servidor AD resolve os nomes internos e externos.

Os usuários foram criados por setor — Comercial, Compras, Faturamento, Financeiro, Administração, Laboratório, Qualidade/SGQ — e os computadores foram ingressados no domínio um a um. Sete PCs que antes eram máquinas soltas passaram a fazer parte de uma estrutura centralizada.

O NAS Synology também foi ingressado no domínio, permitindo usar os usuários e grupos do AD diretamente nas permissões das pastas compartilhadas — sem precisar criar contas locais separadas no NAS.

> O servidor AD também hospeda o **Hyper-V** que roda a VM do servidor Zabbix (Etapa 3 — Ubuntu Server 22.04, IP `192.168.88.242`). Ter a VM de monitoramento no mesmo servidor evitou a necessidade de hardware adicional.

---

## GPO — Política de Grupo

Com o domínio funcionando, o próximo passo foi automatizar o ambiente de trabalho via GPO.

### O problema que motivou tudo

Um script de logon funcionava para o primeiro usuário que entrava em cada máquina, mas para o segundo os atalhos simplesmente não apareciam. Depois de investigar, o motivo ficou claro: o script verificava se a pasta local já existia antes de criar os atalhos. Como o primeiro usuário já tinha criado a pasta, o script pulava o bloco inteiro — inclusive a criação dos atalhos no novo perfil.

A correção foi **separar completamente a lógica de cópia de arquivos da lógica de criação de atalhos**. Os atalhos precisam ser verificados no contexto de cada usuário que está fazendo login, não na pasta do sistema.

### O que o script de logon faz

O script roda em **Configuração do Usuário → Scripts (Logon)**, garantindo execução no contexto de quem está logando, independente da máquina.

1. **Garante a pasta local** — cria `C:\Sistema` se não existir
2. **Controle de versão do ERP** — compara a data de modificação do executável entre o servidor e a máquina local. Se o servidor tiver versão mais nova, copia automaticamente. Todos os usuários sempre têm a mesma versão, sem intervenção manual.
3. **Controle de versão do logotipo** — mesma lógica, aplicada ao arquivo de imagem usado pelo sistema
4. **Atalhos por perfil** — cria atalhos na Área de Trabalho e em Documentos apenas se ainda não existirem, no perfil do usuário que está logando

### Outros itens configurados via GPO

- Mapeamento de unidades de rede (pastas no Synology)
- Ícones padrão na Área de Trabalho (Meu Computador, Lixeira)
- Restrição de instalação de software para usuários comuns
- Configurações padrão do Microsoft Edge para o ambiente corporativo

---

## Sistemas hospedados no servidor AD

O servidor hospeda dois sistemas além das funções de domínio e do Hyper-V:

**Sistema ERP** — rodando com SQL Server 2017. O executável é distribuído via GPO para todos os computadores do domínio, sempre na versão mais recente do servidor.

**Sistema de Ponto** — integrado ao relógio de ponto (`192.168.88.230`), mantido com IP fixo no dispositivo desde a Etapa 1.

**Hyper-V** — hospeda a VM do servidor Zabbix (Ubuntu Server 22.04 LTS, IP `192.168.88.242`). A carga da VM é baixa — Zabbix com PostgreSQL em ambiente pequeno consome menos de 1 GB de RAM.

Ter tudo no mesmo servidor foi uma escolha consciente de custo e simplicidade. O hardware suporta bem a carga e a manutenção fica centralizada.

---

## Tailscale — Acesso Remoto VPN

O acesso remoto anterior era feito por AnyDesk e TeamViewer — ambos exigindo que alguém na empresa autorizasse a sessão com senha. Funcional, mas dependente de alguém estar disponível do outro lado, o que era inviável em situações de urgência fora do horário comercial.

A solução foi o **Tailscale**, uma VPN mesh que cria uma rede privada entre dispositivos sem precisar abrir portas no firewall ou configurar NAT. O servidor AD e o notebook de TI foram conectados à mesma conta Tailscale.

Com o Tailscale ativo, é possível acessar qualquer máquina da rede interna de fora da empresa como se estivesse fisicamente dentro do escritório — incluindo o frontend do Zabbix em `http://192.168.88.242/zabbix`.

### O problema que apareceu depois

Após uma reinicialização do servidor, o Tailscale não reconectava automaticamente. O serviço estava configurado como Automático no Windows, mas a sessão não era restaurada.

A solução foi fazer o login uma vez via `tailscale.exe up` pelo PowerShell com permissões de administrador, abrindo a autenticação no navegador. Depois disso, o token fica salvo no perfil do serviço e o Tailscale volta a conectar sozinho a cada reinicialização — sem depender de auth keys com expiração de 90 dias.

---

## RustDesk — Acesso às Estações de Trabalho

Com o Tailscale garantindo o acesso ao servidor, o próximo passo foi centralizar o acesso às estações. O **RustDesk** foi escolhido por permitir um servidor self-hosted dentro da própria rede, eliminando dependência de infraestrutura externa.

O servidor RustDesk foi instalado no servidor AD. Todos os computadores e notebooks têm o cliente instalado e configurado para apontar para o **IP Tailscale** do servidor — não para o IP local.

**Por que o IP do Tailscale e não o IP local?** Porque dessa forma o acesso funciona de dentro e de fora da rede sem mudar configuração. Quando o TI está na empresa, o tráfego passa pelo IP Tailscale internamente. Quando está em casa, passa pelo túnel VPN. O cliente não precisa saber a diferença.

Para terceiros (suporte externo, fornecedores), o AnyDesk continua disponível — mas com senha de autorização exigida pelo administrador para cada sessão.

---

## Synology — Domínio, Permissões e Monitoramento

O NAS foi ingressado no domínio, o que trouxe um benefício direto: as pastas compartilhadas passaram a reconhecer os usuários e grupos do AD para controle de acesso, sem precisar criar contas duplicadas.

**Passo crítico antes do ingresso:** apontar o DNS do NAS para o servidor AD. Sem isso, o NAS não consegue resolver o domínio e o ingresso falha.

### Problema que surgiu após o ingresso

O Cloud Sync perdeu acesso a uma pasta que teve as permissões ajustadas. A causa foi a ativação das Permissões Avançadas de Compartilhamento sem incluir explicitamente o usuário admin na lista — nas permissões avançadas, diferente das básicas, é necessário marcar manualmente cada usuário, mesmo que seja administrador.

A solução foi ir em **Painel de Controle → Pasta Compartilhada → Editar → Permissões Avançadas** e marcar Leitura/Gravação para o admin. O Cloud Sync voltou a funcionar imediatamente.

### Permissões por subpasta

Para cenários onde um usuário precisa ver apenas uma subpasta dentro de uma pasta maior, o Synology permite isso via **Permissões Avançadas** com a opção *"Ocultar subpastas e arquivos de usuários sem permissão"* ativa na pasta compartilhada. A configuração de acesso por subpasta é feita no **File Station** — o Painel de Controle habilita o recurso, mas a configuração real por subpasta acontece no File Station.

### SNMP para monitoramento

O Synology tem suporte nativo a SNMP. Após habilitar em **Painel de Controle → Terminal e SNMP**, o Zabbix passou a monitorar temperatura, uso de disco por volume, status dos discos físicos e disponibilidade do NAS. O template `Synology DiskStation by SNMP` cobre todos esses pontos automaticamente.

---

## Backup — Estratégia com Nuvem

A estratégia foi montada usando o Synology como ponto central, com Cloud Sync e Hyper Backup conectados ao Google Drive e ao OneDrive.

| Frequência                     | Tipo             | Destino           |
| ------------------------------ | ---------------- | ----------------- |
| Seg / Qua / Sex                | Incremental      | OneDrive          |
| Sáb / Dom                      | Full (completo)  | OneDrive          |
| Contínuo                       | Cloud Sync       | Google Drive      |
| A cada alteração significativa | Backup SQL Server | NAS + nuvem      |

Essa rotina garante que, em qualquer dia da semana, existe um ponto de restauração recente disponível. O backup do SQL Server inclui os dados do ERP e do sistema de ponto — os mais críticos para a operação.

> O Zabbix monitora o espaço disponível no Synology. Um alerta dispara quando o uso ultrapassa 80%, antes que o backup em nuvem seja impactado.

---

## E-mail — Do Webmail para o Outlook Classic

Antes desta etapa, o e-mail corporativo era gerenciado exclusivamente pelo webmail do provedor. Cada usuário abria o navegador para ler e enviar e-mails, sem histórico consolidado e com acesso mobile inconsistente.

O Outlook Classic foi configurado em todas as máquinas do domínio via IMAP/SMTP. O resultado foi imediato: e-mail integrado ao desktop, com histórico local, funcionalidade offline e experiência muito mais próxima do que os usuários já conheciam.

Nenhuma migração para Microsoft 365 ou Exchange foi necessária — o provedor já oferecia suporte a IMAP, e o custo de uma migração de plataforma não se justificaria para o porte da operação atual.

---

## WordPress — Portal em Desenvolvimento

O NAS Synology hospeda uma instalação do WordPress com MariaDB 10 e PHP 8.2, usado como portal da empresa. O Package Center do Synology costuma ficar defasado — a versão disponível parou na 6.8 — então a atualização foi feita manualmente: copiando os arquivos do núcleo por cima da instalação existente, preservando `wp-config.php`, `wp-content` e `.htaccess`.

Com PHP 8.2 e MariaDB 10, não há bloqueio de compatibilidade para as versões mais recentes do WordPress.

---

## Conformidade — ISO 27001 e LGPD

As decisões tomadas ao longo do projeto não foram pensadas com certificação em mente — foram decisões práticas para resolver problemas reais. Mas o resultado é uma infraestrutura que, por design, já segue os princípios das principais referências de segurança.

| Implementação                                              | Princípio                                              |
| ---------------------------------------------------------- | ------------------------------------------------------ |
| Dispositivos desconhecidos isolados por padrão             | ISO 27001 A.9 — Controle de acesso / LGPD Art. 46      |
| Câmeras e impressoras sem acesso à internet                | LGPD Art. 6 — Minimização de exposição de dados        |
| Winbox restrito à rede local + detecção de port scan       | ISO 27001 A.13 — Segurança de rede                     |
| Usuários com permissões por função e setor                 | ISO 27001 A.9.2 — Princípio do menor privilégio        |
| Backup incremental e full com rotina definida              | ISO 27001 A.17 — Continuidade de negócios              |
| Acesso remoto via VPN sem portas abertas                   | ISO 27001 A.13.2 — Segurança em canais de comunicação  |
| RustDesk self-hosted — sem dados em servidores externos    | LGPD Art. 46 — Medidas de segurança no processamento   |
| Logs de firewall e failover no MikroTik                    | ISO 27001 A.12.4 — Rastreabilidade e auditoria         |
| GPO restringindo instalação de software                    | ISO 27001 A.12.6 — Gestão de vulnerabilidades técnicas |
| Firewall com 25 regras + Bloco 8 (Zabbix)                  | ISO 27001 A.13.1 — Controles de rede                   |
| Failover automático — sem dependência de intervenção humana| ISO 27001 A.17.2 — Redundâncias de infraestrutura      |
| Zabbix — monitoramento em tempo real com alertas proativos | ISO 27001 A.12.1 — Gestão de operações / A.12.4 — Auditoria |

---

## O que aprendi nessa etapa

A segunda etapa foi mais trabalhosa que a primeira num aspecto específico: **os problemas eram menos óbvios**.

No MikroTik, quando algo estava errado, o sintoma era imediato — a internet parava, o ping falhava, o failover não funcionava. Aqui, os problemas apareciam em situações específicas: o script de logon funcionava para um usuário mas não para o outro; o Cloud Sync parava de sincronizar silenciosamente após um ajuste de permissões; o Tailscale não reconectava após reboot sem deixar mensagem clara de erro.

Em todos os casos, a investigação levou ao mesmo aprendizado: **o problema raramente estava onde parecia estar**. O script parecia estar criando os atalhos — e estava, mas só para o primeiro usuário de cada máquina. O Cloud Sync parecia ter permissão de admin — e tinha, mas as permissões avançadas exigem marcação explícita.

Entender o comportamento real do sistema, e não o comportamento esperado, foi o que resolveu cada um desses problemas.

Isso ficou ainda mais claro com o Zabbix: na primeira semana após a implantação, dois alertas apareceram antes de qualquer usuário reclamar. Um PC com disco a 94% (descoberto às 22h, antes de virar problema no dia seguinte), e uma impressora que ficava offline por minutos toda madrugada — padrão que nunca teria sido percebido sem monitoramento. **Visibilidade não é luxo. É o que separa gestão reativa de gestão proativa.**

---

## Tecnologias utilizadas nessa etapa

`Windows Server 2019` `Active Directory` `DNS` `GPO` `Hyper-V` `SQL Server 2017` `PowerShell` `Tailscale VPN` `RustDesk` `Synology DSM` `Cloud Sync` `Hyper Backup` `OneDrive` `Google Drive` `WordPress` `MariaDB 10` `PHP 8.2` `Outlook Classic` `Zabbix 7.0 LTS` `Ubuntu Server 22.04` `PostgreSQL 16` `SNMP v2c` `Zabbix Agent 2` `ISO 27001` `LGPD`

---

*Projeto desenvolvido e documentado por Robson Andrade — Junho de 2026*  
💼 [linkedin.com/in/robsonandradee](https://www.linkedin.com/in/robsonandradee) · 📧 robsonluisandrade@gmail.com
