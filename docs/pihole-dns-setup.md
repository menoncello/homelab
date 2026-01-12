# Configurando DNS Local com Pi-hole

## Visão Geral

O Pi-hole está rodando no Helios (192.168.31.237) e serve como DNS server para toda rede, além de bloquear anúncios e rastreadores.

## Acesso ao Pi-hole

```
URL: http://192.168.31.237:8053/admin
Senha: piholeadmin2024
```

⚠️ **Primeira ação:** Altere a senha imediatamente!

---

## Configuração Passo a Passo

### 1. Configurar DNS Local para *.homelab

No Pi-hole Web UI:

1. **Navegue para:** Settings → DNS
2. **Role para baixo até:** "Local DNS Records"
3. **Adicione os registros:**

```
Domain: jellyfin.homelab    → IP: 192.168.31.237
Domain: sonarr.homelab      → IP: 192.168.31.237
Domain: radarr.homelab      → IP: 192.168.31.237
Domain: transmission.homelab → IP: 192.168.31.237
Domain: nextcloud.homelab   → IP: 192.168.31.6
Domain: audiobooks.homelab  → IP: 192.168.31.6
Domain: pihole.homelab      → IP: 192.168.31.237
```

4. **Clique em:** Save

### 2. Configurar Roteador para Usar Pi-hole

#### Opção A: Configurar DHCP do Roteador (Recomendado)

No seu roteador:
1. Acesse a interface de administração
2. Procure configurações de DHCP/DNS
3. **DNS primário:** `192.168.31.237` (Helios/Pi-hole)
4. **DNS secundário:** `1.1.1.1` (Cloudflare) ou deixe em branco

#### Opção B: Configurar DNS Manualmente em Cada Dispositivo

**Windows:**
```
Configurações → Rede e Internet → Wi-Fi → Propriedades
Editar DNS IP:
- DNS primário: 192.168.31.237
- DNS secundário: 1.1.1.1
```

**macOS:**
```
System Preferences → Network → Wi-Fi → Details → DNS
+ → Adicionar: 192.168.31.237
```

**Linux:**
```bash
sudo nano /etc/systemd/resolved.conf
# Adicione:
DNS=192.168.31.237
FallbackDNS=1.1.1.1
```

**Android:**
```
Configurações → Wi-Fi → (segurar rede) → Modificar rede
Avançado → DNS estático:
  DNS 1: 192.168.31.237
  DNS 2: 1.1.1.1
```

**iOS:**
```
Configurações → Wi-Fi → (i) ao lado da rede
Configurar DNS → Manual → Adicionar Servidor: 192.168.31.237
```

### 3. Configurar DNS do Helios para Si Próprio

No Helios, aponte o DNS para si mesmo:

```bash
# Editar resolv.conf
sudo nano /etc/resolv.conf

# Substituir com:
nameserver 127.0.0.1
nameserver 1.1.1.1
```

### 4. Testar DNS

```bash
# Testar resolução de nomes
nslookup jellyfin.homelab
nslookup pihole.homelab
ping nextcloud.homelab

# Testar bloqueio de anúncios
nslookup doubleclick.com
# Deve retornar 0.0.0.0 (bloqueado)
```

---

## Adicionar Wildcard DNS (Opcional)

Para suportar `*.homelab` sem adicionar cada subdomínio:

### Opção 1: Usar dnsmasq no Pi-hole

```bash
# SSH no Helios
docker exec -it pihole_pihole.1 bash

# Editar configuração do dnsmasq
echo "address=/.homelab/192.168.31.237" >> /etc/dnsmasq.d/02-homelab.conf

# Reiniciar Pi-hole
exit
docker service update pihole_pihole --force
```

### Opção 2: Usar Nginx Proxy Manager com DNS

Configure cada subdomínio individualmente no Nginx Proxy Manager e adicione DNS records no Pi-hole para cada um.

---

## SSL Certificates com Domínios Locais

Como `.local` não é um TLD público, o Let's Encrypt **não funciona**.

### Solução 1: Certificado Auto-Assinado (Aceitável para LAN)

No Nginx Proxy Manager:
1. **SSL Certificates** → **Add SSL Certificate**
2. **Tab:** Custom
3. **Preencha:**
   - Certificate Name: homelab-local
   - **Deixe os campos de chave/cert em branco**
   - Isso cria certificado auto-assinado automaticamente

4. **Configure Proxy Hosts** para usar este certificado

### Solução 2: Usar Domínio Real (Melhor Experiência)

1. Compre um domínio (ex: `seudominio.com`)
2. Configure DNS no seu provedor:
   ```
   jellyfin.homelab.seudominho.com   → 192.168.31.237
   sonarr.homelab.seudominho.com     → 192.168.31.237
   ```
3. Use Let's Encrypt no Nginx Proxy Manager com HTTP Challenge

### Solução 3: CloudFlare Tunnel (Recomendado para Acesso Externo)

Veja documentação em: `CLOUDFLARE-SETUP.md`

---

## Verificar Funcionamento

### 1. Dashboard do Pi-hole

Acesse http://192.168.31.237:8053/admin e verifique:
- **Total Queries:** Deve aumentar conforme você usa a internet
- **Queries Blocked:** Deve mostrar anúncios bloqueados
- **Gravity:** Lista de bloqueios carregada
- **Clients:** Dispositivos na rede usando o Pi-hole

### 2. Testar de DNS

```bash
# De qualquer dispositivo na rede:
nslookup google.com
# Deve retornar IP do Google

nslookup doubleclick.com
# Deve retornar 0.0.0.0 (bloqueado pelo Pi-hole)

ping jellyfin.homelab
# Deve resolver para 192.168.31.237
```

### 3. Testar de Navegação

1. Acesse sites normalmente - devem funcionar
2. Anúncios devem estar bloqueados em sites
3. Navegue para `jellyfin.homelab` - deve funcionar

---

## Manutenção

### Atualizar Listas de Bloqueio

1. Acesse Pi-hole → Settings → Blocklists
2. Clique em "Update All"
3. Ou use o botão "Tools → Update Gravity"

### Verificar Estatísticas

- **Dashboard:** Visão geral em tempo real
- **Query Log:** Histórico de consultas DNS
- **Top Clients:** Dispositivos que mais usam DNS
- **Top Domains:** Domínios mais acessados

### Backup da Configuração

```bash
# No Helios
docker exec pihole_pihole.1 pihole -a -t

# Ou copie os volumes:
docker run --rm -v pihole-config:/config -v $(pwd):/backup alpine \
  tar czf /backup/pihole-backup-$(date +%Y%m%d).tar.gz /config
```

---

## Solução de Problemas

### Problema: DNS não funciona

```bash
# Verificar se Pi-hole está rodando
docker service ps pihole_pihole

# Verificar logs
docker service logs pihole_pihole --tail 50

# Testar DNS diretamente
dig @127.0.0.1 google.com
nslookup google.com 127.0.0.1
```

### Problema: Alguns sites não abrem

1. Verifique se o DNS secundário está configurado (1.1.1.1)
2. Adicione domínios à whitelist: Settings → Whitelist

### Problema: Dispositivos não usam Pi-hole

1. Configure manualmente o DNS no dispositivo
2. Ou configure DHCP do roteador para distribuir o Pi-hole
3. Reinicie o dispositivo para pegar nova configuração DNS

---

## URLs Úteis

- **Pi-hole Admin:** http://192.168.31.237:8053/admin
- **Pi-hole API:** http://192.168.31.237:8053/api
- **Query Log:** http://192.168.31.237:8053/admin/query-log
- **Blocklists:** http://192.168.31.237:8053/admin/blocklists

---

**Última atualização:** 2025-12-22
**Documentação:** https://github.com/menoncello/homelab
