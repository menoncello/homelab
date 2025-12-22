# Servidores do Homelab

## Visão Geral

Homelab com 2 servidores em rede 2.5Gbps, conexão fibra 600/200 Mbps.

---

## Helios (Manager Node)

**Especificações:**
- **CPU:** Intel Core i7 11ª geração
- **RAM:** 64GB DDR4
- **GPU:** NVIDIA RTX 3070ti Mobile
- **Storage:** 2TB HDD + 480GB SSD
- **SO:** Ubuntu 25.04
- **Função:** Docker Swarm Manager + Serviços GPU

**Rede:**
- **IP:** 192.168.31.237
- **Interface:** [Identificar interface 2.5G]
- **Porta Docker API:** 2375 (TCP)

**Serviços Planejados:**
- Docker Swarm Manager
- Serviços com aceleração GPU
- Machine Learning / AI
- Transcoding de vídeo
- serviços principais do homelab

**Acesso:**
```bash
# SSH
ssh eduardo@192.168.31.237

# Docker Remoto
export DOCKER_HOST="tcp://192.168.31.237:2375"
# ou
docker context use homelab
```

---

## Xeon01 (Worker Node)

**Especificações:**
- **CPU:** Intel Xeon E5-2686
- **RAM:** 96GB DDR4
- **Storage:** 1TB HDD + 480GB SSD
- **SO:** Ubuntu 25.04
- **Função:** Docker Swarm Worker

**Rede:**
- **IP:** 192.168.31.208
- **Interface:** [Identificar interface]
- **Porta Docker API:** Acesso via manager (Swarm)

**Serviços Planejados:**
- Docker Swarm Worker
- Bancos de dados (MySQL, PostgreSQL)
- Cache (Redis)
- Serviços que precisam de muita RAM
- Backup e storage

**Acesso:**
```bash
# SSH
ssh eduardo@192.168.31.208

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
    ├── Helios (192.168.31.237) - Manager
    └── Xeon01 (192.168.31.208) - Worker
```

### Portas Configuradas
| Serviço | Porta | Protocolo | Descrição |
|---------|-------|-----------|-----------|
| Docker API | 2375 | TCP | Acesso remoto ao Docker (Helios) |
| Docker Swarm | 2377 | TCP | Cluster management |
| Node Communication | 7946 | TCP/UDP | Comunicação entre nós |
| Overlay Network | 4789 | UDP | Tráfego de rede overlay |
| SSH | 22 | TCP | Acesso remoto |

### Rede Docker Swarm
- **Rede Overlay:** homelab-net (criada para comunicação interna)
- **Driver:** overlay
- **Attachable:** true

---

## Status da Configuração

### ✅ Concluído
- [x] Ubuntu 25.04 instalado em ambos os servidores
- [x] Rede 2.5Gbps configurada
- [x] Docker Engine instalado (Helios)
- [x] Docker API TCP configurado (Helios:2375)
- [x] Acesso remoto Docker funcionando
- [x] Docker Swarm initialization
- [x] Xeon01 ingressar no cluster

### 🔄 Em Progresso
- [ ] Configuração de rede overlay
- [ ] Labels dos nós para deploy seletivo

### ⏳ Planejado
- [ ] Setup de storage compartilhado
- [ ] Configuração de monitoring
- [ ] Backup automático
- [ ] Serviços específicos por nó

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
ping -c 3 192.168.31.237
telnet 192.168.31.237 2375
```

---

## Acesso Rápido

### Do Computador Local
```bash
# Usando Docker Context
docker context update homelab --docker "host=ssh://eduardo@192.168.31.237:2375"
docker context use homelab

# Variável de ambiente
export DOCKER_HOST="tcp://192.168.31.237:2375"
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

**Data:** 2025-12-22
**Status:** Configuração em andamento
**Próximos passos:** Finalizar Docker Swarm setup