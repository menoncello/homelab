# Homelab Híbrido - Design Minimalista

## Visão Geral

Infraestrutura Docker Swarm com 2 nós focada em Media Center, Self-hosted services e automação de conteúdo, aproveitando recursos específicos de cada servidor.

---

## Arquitetura

### Helios (Manager Node) - 192.168.31.237
- **CPU:** Intel Core i7 11ª geração
- **RAM:** 64GB DDR4
- **GPU:** NVIDIA RTX 3070ti Mobile
- **Storage:** 480GB SSD (principal) + 2TB HDD (mídia)

**Serviços:**
- Docker Swarm Manager
- Nginx Proxy Manager (portas 80/443)
- Jellyfin (transcoding via GPU)
- Sonarr (séries/anime)
- Radarr (filmes)
- Transmission/qBittorrent (downloads)

### Xeon01 (Worker Node) - 192.168.31.208
- **CPU:** Intel Xeon E5-2686
- **RAM:** 96GB DDR4
- **Storage:** 480GB SSD (principal) + 1TB HDD (dados)

**Serviços:**
- Docker Swarm Worker
- Nextcloud (arquivos/documentos)
- Audiobookshelf (livros/audiolivros)
- PostgreSQL (banco de dados central)

---

## Estrutura de Storage

### Helios (SSD 480GB)
```
/docker/
├── jellyfin/
│   ├── config/
│   └── cache/
├── sonarr/
├── radarr/
├── transmission/
│   ├── config/
│   └── downloads/
└── nginx-proxy/
```

### Helios (HDD 2TB - Mídia)
```
/media/
├── movies/
├── series/
├── anime/
└── incomplete/
```

### Xeon01 (SSD 480GB)
```
/docker/
├── nextcloud/
│   ├── config/
│   └── data/
├── audiobookshelf/
│   ├── config/
│   ├── metadata/
│   └── audiobooks/
└── postgresql/
    └── data/
```

---

## Rede

### Topologia
```
Internet (600/200 Fibra)
    ↓
Roteador/Switch 2.5Gbps
    ├── Helios (192.168.31.237) - Manager
    └── Xeon01 (192.168.31.208) - Worker
```

### Configuração
- **Docker Swarm:** overlay network `homelab-net` (attachable)
- **Proxy:** Nginx Proxy Manager centraliza acesso HTTPS
- **DNS Local:** `*.homelab.local` → Helios
- **Portas Externas:** 80, 443 (HTTPS), 22 (SSH)

### Serviços Expostos via Proxy
- `jellyfin.homelab.local` → Jellyfin
- `sonarr.homelab.local` → Sonarr
- `radarr.homelab.local` → Radarr
- `transmission.homelab.local` → Transmission
- `nextcloud.homelab.local` → Nextcloud
- `audiobooks.homelab.local` → Audiobookshelf

---

## Fluxo de Dados

### Pipeline de Mídia Automatizada
```
1. Radarr/Sonarr detectam novo conteúdo
2. Envia para Transmission/qBittorrent
3. Download completo → pasta /media/
4. Jellyfin detecta novo conteúdo automaticamente
5. Disponível para streaming com transcoding GPU
```

### Gestão de Livros
```
1. Audiobookshelf monitora pasta /audiobooks/
2. Metadados automáticos via APIs
3. Acesso via interface web/mobile
4. Sincronização de progresso
```

---

## Segurança

### Rede
- Docker API apenas rede interna (Helios:2375)
- Firewall bloqueando acesso externo às portas de gerenciamento
- Todos os serviços expostos apenas via HTTPS com certificado Let's Encrypt

### Dados
- Senhas fortes em todos os serviços
- 2FA habilitado onde disponível
- Backups regulares do PostgreSQL e configurações

### Isolamento
- Containers isolados com usuários dedicados
- Permissões restritivas em volumes
- Rede overlay para comunicação interna

---

## Gerenciamento

### Via Terminal
```bash
# Contexto Docker para homelab
docker context use homelab

# Verificar status do cluster
docker node ls
docker service ls

# Deploy de serviços
docker stack deploy -c docker-compose.yml homelab

# Logs e manutenção
docker service logs [serviço]
docker service update --force [serviço]
```

### Scripts Úteis
- Deploy automatizado via `docker-compose.yml`
- Scripts de backup para PostgreSQL e configurações
- Monitoramento de saúde dos serviços

---

## Implementação

### Pré-requisitos
1. Docker Swarm configurado
2. Volumes persistentes criados
3. Certificados SSL configurados no Nginx Proxy Manager
4. DNS local configurado

### Deploy Sequence
1. Infraestrutura básica (networks, volumes)
2. PostgreSQL
3. Nginx Proxy Manager
4. Serviços de mídia (Jellyfin, ARR stack)
5. Serviços de conteúdo (Nextcloud, Audiobookshelf)

---

## Expansão Futura

### Possíveis Adições
- **Monitoramento:** Prometheus + Grafana
- **Logs:** Loki + Promtail
- **Cache:** Redis para performance
- **IA:** Serviços leves usando GPU
- **CI/CD:** GitLab Runner

### Otimizações
- Storage compartilhado entre nós
- Load balancing para alta disponibilidade
- Backup automatizado incremental

---

## Especificações Técnicas

### Docker Compose Features
- Secrets para dados sensíveis
- Health checks para todos os serviços
- Restart policies automáticas
- Resource limits baseados no hardware

### Performance Considerations
- GPU passthrough para Jellyfin
- RAM alocada por necessidade (Xeon01: bancos, Helios: transcodificação)
- Storage SSD para dados críticos, HDD para mídia

---

## Última Atualização

**Data:** 2025-12-22
**Status:** Design completo, pronto para implementação
**Próximos passos:** Criar Docker Compose e scripts de deploy