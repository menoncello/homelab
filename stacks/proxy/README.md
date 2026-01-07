# DNS e Proxy Setup para Homelab

Configuração completa de DNS local (Pi-hole) e Reverse Proxy (Nginx Proxy Manager) para URLs limpas sem portas.

## Arquitetura

```
Dispositivo → DNS (Pi-hole) → Proxy (Nginx PM) → Serviço
     │              │                  │              │
  homelab.local   192.168.31.5      :80/:443      :porta
```

## Estrutura de Arquivos

```
stacks/
├── pihole/
│   ├── docker-compose.yml
│   ├── setup-dns.sh           # Script completo de setup
│   └── local-dns.conf         # Config DNS local
│
└── proxy/
    ├── docker-compose.yml
    ├── setup-proxy.sh         # Script completo de setup
    └── config/
        ├── proxy-hosts.json   # Lista de serviços
        └── ssl-cert.sh        # Gerar certificado SSL
```

## Passo a Passo

### 1. Setup do Pi-hole (DNS Local)

No servidor Helios (192.168.31.5):

```bash
ssh eduardo@192.168.31.5

# Copiar e executar script
bash ~/repos/setup/homelab/stacks/pihole/setup-dns.sh
```

No seu computador local:

```bash
cd ~/repos/setup/homelab/stacks/pihole
docker -H ssh://eduardo@192.168.31.5 stack deploy -c docker-compose.yml pihole
```

Testar DNS:

```bash
dig @192.168.31.5 jellyfin.homelab.local
dig @192.168.31.5 sonarr.homelab.local
```

### 2. Setup do Nginx Proxy Manager

**Primeiro acesso:**

1. Acesse http://192.168.31.5:81
2. Faça login inicial e crie usuário admin
3. Anote as credenciais

**Configurar proxy hosts:**

No seu computador local:

```bash
# Editar credenciais se necessário
nano ~/repos/setup/homelab/stacks/proxy/setup-proxy.sh
# Altere NGINX_PM_USER e NGINX_PM_PASS

# Executar setup
bash ~/repos/setup/homelab/stacks/proxy/setup-proxy.sh
```

### 3. Configurar Dispositivos da Rede

Configure seus dispositivos para usar o DNS:

- **DNS Primário:** `192.168.31.5`
- **DNS Secundário:** `1.1.1.1`

Ou configure no roteador para toda a rede.

## URLs Finais

Após configuração, acesse os serviços sem portas:

| Serviço | URL Antes | URL Depois |
|---------|-----------|------------|
| Jellyfin | `http://192.168.31.5:8096` | `https://jellyfin.homelab.local` |
| Sonarr | `http://192.168.31.5:8989` | `https://sonarr.homelab.local` |
| Radarr | `http://192.168.31.5:7878` | `https://radarr.homelab.local` |
| Nextcloud | `http://192.168.31.6:8080` | `https://nextcloud.homelab.local` |

## Adicionando Novos Serviços

### 1. Adicionar ao DNS local

Edite `stacks/pihole/local-dns.conf`:

```conf
address=/novo-servico.homelab.local/192.168.31.5
```

Redeploy o Pi-hole:

```bash
docker -H ssh://eduardo@192.168.31.5 stack deploy -c stacks/pihole/docker-compose.yml pihole
```

### 2. Adicionar ao Proxy

Edite `stacks/proxy/config/proxy-hosts.json`:

```json
{
  "domain": "novo-servico.homelab.local",
  "name": "Novo Serviço",
  "target": "novo-servico",
  "port": 8888,
  "node": "pop-os",
  "description": "Descrição"
}
```

Execute o setup do proxy novamente:

```bash
bash ~/repos/setup/homelab/stacks/proxy/setup-proxy.sh
```

## Troubleshooting

### DNS não resolve

```bash
# Verificar se Pi-hole está rodando
docker -H ssh://eduardo@192.168.31.5 service ls | grep pihole

# Verificar logs
ssh eduardo@192.168.31.5 "docker logs -f pihole_pihole"

# Testar resolução direta
dig @192.168.31.5 jellyfin.homelab.local
```

### Proxy não funciona

```bash
# Verificar se Nginx PM está rodando
docker -H ssh://eduardo@192.168.31.5 service ls | grep proxy

# Acessar interface
http://192.168.31.5:81

# Verificar logs
ssh eduardo@192.168.31.5 "docker logs -f proxy_nginx-proxy"
```

### Certificado SSL

O certificado é auto-assinado. Seu navegador mostrará aviso de segurança.

**Para aceitar o certificado:**

1. Acesse https://<serviço>.homelab.local
2. Clique "Avançado" → "Aceitar o risco" ou "Adicionar exceção"
3. O navegador vai lembrar para próximos acessos

**Para remover o aviso permanentemente:**

Importe o certificado `/data/docker/nginx-proxy/ssl/homelab-local.crt` no sistema operacional ou navegador.

## Scripts Disponíveis

| Script | Descrição |
|--------|-----------|
| `stacks/pihole/setup-dns.sh` | Setup completo do Pi-hole (no servidor) |
| `stacks/proxy/setup-proxy.sh` | Setup completo do Proxy (local) |
| `stacks/proxy/config/ssl-cert.sh` | Gerar certificado SSL manualmente |

## Documentação Relacionada

- `CLAUDE.md` - Convenções do projeto
- `docs/servers.md` - Especificações dos servidores
- `scripts/setup-gpu.sh` - Setup de GPU (se aplicável)
