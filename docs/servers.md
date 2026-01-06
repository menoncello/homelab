# Servidores do Homelab

## Visão Geral

Homelab com 2 servidores em rede 2.5Gbps, conexão fibra 600/200 Mbps.

---

## Helios (Manager Node)

**Especificações:**
- **CPU:** Intel Core i7 11ª geração
- **RAM:** 64GB DDR4
- **GPU:** NVIDIA RTX 3070ti Mobile
- **Storage:**
- nvme1n1p7 (/data) - 337.8GB - Docker configs
- nvme1n1p3 (/media) - 955.6GB - Media libraries
- nvme0n1p1 (/srv) - 444.5GB - Backup/expansão
- **SO:** Ubuntu 25.04
- **Função:** Docker Swarm Manager + Serviços GPU

**Rede:**
- **IP:** 192.168.31.5
- **Interface:** [Identificar interface 2.5G]
- **Porta Docker API:** 2375 (TCP)

**Serviços:**
- Docker Swarm Manager
- Jellyfin (GPU transcoding)
- Sonarr (TV automation)
- Radarr (Movie automation)
- Lidarr (Music automation)
- Transmission (Torrent)
- Homarr (Dashboard)
- Nginx Proxy Manager (Reverse proxy)
- Pi-hole (DNS + Ad blocking)

**Acesso:**
```bash
# SSH
ssh eduardo@192.168.31.5

# Docker Remoto
export DOCKER_HOST="tcp://192.168.31.5:2375"
# ou
docker context use homelab
```

---

## Xeon01 (Worker Node)

**Especificações:**
- **CPU:** Intel Xeon E5-2686
- **RAM:** 96GB DDR4
- **Storage:**
- nvme1n1p1 (/srv) - 434.1GB - Docker configs
- ubuntu-vg-lv--0 (/home) - 793.8GB - Nextcloud data & Audiobooks
- **SO:** Ubuntu 25.04
- **Função:** Docker Swarm Worker

**Rede:**
- **IP:** 192.168.31.6
- **Interface:** [Identificar interface]
- **Porta Docker API:** Acesso via manager (Swarm)

**Serviços:**
- Docker Swarm Worker
- PostgreSQL (Shared database)
- Redis (Cache/Queue)
- Nextcloud (File storage)
- Audiobookshelf (Audiobooks)
- n8n (Workflow automation)
- Kavita (Ebook/comic reader)
- Stacks (Anna's Archive downloader)

**Acesso:**
```bash
# SSH
ssh eduardo@192.168.31.6

# Docker (via manager)
docker context use homelab
docker node ls
```

---

## Configuração de Rede

### Topologia
```
Internet (600/200 Fibra)
    ↓
Roteador/Switch 2.5Gbps
    ├── Helios (192.168.31.5) - Manager
    └── Xeon01 (192.168.31.6) - Worker
```

### Portas Configuradas
| Serviço | Porta | Protocolo | Descrição |
|---------|-------|-----------|-----------|
| Docker API | 2375 | TCP | Acesso remoto ao Docker (Helios) |
| Docker Swarm | 2377 | TCP | Cluster management |
| Node Communication | 7946 | TCP/UDP | Comunicação entre nós |
| Overlay Network | 4789 | UDP | Tráfego de rede overlay |
| SSH | 22 | TCP | Acesso remoto |

### Portas dos Serviços (Helios - 192.168.31.5)
| Serviço | Porta | URL |
|---------|-------|-----|
| Jellyfin | 8096 | http://192.168.31.5:8096 |
| Sonarr | 8989 | http://192.168.31.5:8989 |
| Radarr | 7878 | http://192.168.31.5:7878 |
| Lidarr | 8686 | http://192.168.31.5:8686 |
| Transmission | 9091 | http://192.168.31.5:9091 |
| Homarr | 7575 | http://192.168.31.5:7575 |
| Nginx Proxy Manager | 81 | http://192.168.31.5:81 |
| Pi-hole (Web) | 8053 | http://192.168.31.5:8053/admin |

### Portas dos Serviços (Xeon01 - 192.168.31.6)
| Serviço | Porta | URL |
|---------|-------|-----|
| Nextcloud | 8080 | http://192.168.31.6:8080 |
| Audiobookshelf | 80 | http://192.168.31.6:80 |
| n8n | 5678 | http://192.168.31.6:5678 |
| Kavita | 5000 | http://192.168.31.6:5000 |
| Stacks | 7788 | http://192.168.31.6:7788 |

### Rede Docker Swarm
- **Rede Overlay:** homelab-net (criada para comunicação interna)
- **Driver:** overlay
- **Attachable:** true

---

## Status da Configuração

### ✅ Concluído
- [x] Ubuntu 25.04 instalado em ambos os servidores
- [x] Rede 2.5Gbps configurada
- [x] Docker Engine instalado (ambos servidores)
- [x] Docker API TCP configurado (Helios:2375)
- [x] Acesso remoto Docker funcionando
- [x] Docker Swarm initialization
- [x] Xeon01 ingressar no cluster
- [x] Rede overlay homelab-net criada
- [x] Labels dos nós configurados
- [x] Todos os stacks implantados

### 🔄 Serviços Ativos
**Helios (GPU/ARR/Proxy):**
- [x] Jellyfin (GPU transcoding)
- [x] Sonarr (TV)
- [x] Radarr (Movies)
- [x] Lidarr (Music)
- [x] Transmission (Torrents)
- [x] Homarr (Dashboard)
- [x] Nginx Proxy Manager
- [x] Pi-hole (DNS)

**Xeon01 (Storage/Database):**
- [x] PostgreSQL
- [x] Redis
- [x] Nextcloud
- [x] Audiobookshelf
- [x] n8n (Automation)
- [x] Kavita (Ebooks)
- [x] Stacks (Anna's Archive)

### ⏳ Planejado
- [ ] Setup de storage compartilhado
- [ ] Configuração de monitoring (Prometheus/Grafana)
- [ ] Backup automático (restic)
- [ ] URLs com proxy reverso

---

## Comandos Úteis

### Verificar Status
```bash
# No Helios (Manager)
docker node ls                    # Status do cluster
docker service ls                 # Serviços em execução
docker network ls                 # Redes disponíveis

# Nos dois servidores
docker info                       # Informações do Docker
docker version                    # Versão Docker
systemctl status docker           # Status do serviço
```

### Manutenção
```bash
# Colocar nó em manutenção
docker node update --availability drain xeon01

# Promover worker para manager
docker node promote xeon01

# Remover nó do cluster
docker swarm leave xeon01
```

### Debug
```bash
# Logs do nó
docker node inspect xeon01

# Status detalhado do cluster
docker info --format '{{.Swarm}}'

# Testar conectividade
ping -c 3 192.168.31.5
telnet 192.168.31.5 2375
```

---

## Acesso Rápido

### Do Computador Local
```bash
# Usando Docker Context
docker context update homelab --docker "host=ssh://eduardo@192.168.31.5:2375"
docker context use homelab

# Variável de ambiente
export DOCKER_HOST="tcp://192.168.31.5:2375"
docker ps
```

### Scripts Úteis
- `docker context use homelab` - Alternar para contexto do homelab
- `docker context use default` - Voltar para Docker local

---

## Notas de Configuração

### Hardware Específico
- **Helios GPU:** NVIDIA RTX 3070ti Mobile suporta NVIDIA Container Runtime
- **Xeon01:** Ideal para workloads de RAM intensiva (96GB)
- **Storage:** Configurar volumes persistentes em SSDs quando possível

### Considerações de Performance
- **Rede 2.5Gbps:** Aproveitar para comunicação entre serviços
- **RAM disponível:** 160GB totais no cluster
- **Storage distribuído:** Considerar replicação de dados críticos

### Segurança
- Docker API TCP apenas para rede local
- Configurar firewall adequadamente
- Considerar TLS para acesso externo (futuro)

---

## Última Atualização

**Data:** 2025-12-24
**Status:** Todos os stacks implantados e funcionando
**Próximos passos:** Configurar URLs com proxy reverso