# Homelab Cluster Implementation Plan

## Overview
Transforming two standalone servers into a high-availability Proxmox cluster with AI-powered management through Claude Code and ProxmoxMCP-Plus.

## Hardware Inventory

### Servidor Helios (pve-helios)
- **CPU**: Intel i7 11th Gen
- **GPU**: RTX 3070 Mobile
- **RAM**: 64GB
- **Storage**: 2TB + 500GB
- **IP**: 192.168.31.75
- **Role**: GPU-intensive workloads, Media services

### Servidor Xeon (pve-xeon)
- **CPU**: Intel Xeon E5-2686v4
- **GPU**: GTX 1050ti
- **RAM**: 96GB
- **Storage**: 1TB + 480GB
- **IP**: 192.168.31.208
- **Role**: RAM-intensive workloads, Databases, Monitoring

## Implementation Phases

### Phase 1: Preparation (1-2 days)
- [ ] Backup critical data from both servers
- [ ] Download Proxmox VE 9.1 ISO
- [ ] Prepare installation media
- [ ] Document current configurations
- [ ] Schedule maintenance window

### Phase 2: Proxmox Installation (1 day)
- [ ] Install Proxmox VE 9.1 on Helios
- [ ] Install Proxmox VE 9.1 on Xeon
- [ ] Configure network settings
- [ ] Update and patch both systems

### Phase 3: Cluster Configuration (1 day)
- [ ] Create cluster on Helios: `pvecm create MeuHomelab`
- [ ] Join cluster from Xeon: `pvecm add 192.168.31.75`
- [ ] Configure shared storage (NFS/iSCSI)
- [ ] Test cluster functionality
- [ ] Configure HA groups

### Phase 4: ProxmoxMCP-Plus Installation (2-3 hours)
- [ ] Install Python 3.9+, UV, Git on both nodes
- [ ] Clone ProxmoxMCP-Plus repository
- [ ] Configure API tokens for each node
- [ ] Set up Claude Code integration
- [ ] Test MCP functionality

### Phase 5: Strategic VM Deployment
- [ ] Create media services VM on Helios (Plex/Jellyfin)
- [ ] Deploy database VMs on Xeon
- [ ] Set up monitoring stack
- [ ] Configure Home Assistant
- [ ] Install GitLab/Gitea

### Phase 6: Automation & Monitoring
- [ ] Deploy Prometheus + Grafana
- [ ] Configure alerts and notifications
- [ ] Set up automated backups
- [ ] Create management dashboards
- [ ] Document runbooks

## Target Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Home Network (192.168.31.0/24)          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────┐         ┌──────────────────────┐ │
│  │   pve-helios         │         │    pve-xeon         │ │
│  │   192.168.31.75      │         │   192.168.31.208    │ │
│  │                      │         │                      │ │
│  │  ┌────────────────┐  │         │  ┌────────────────┐  │ │
│  │  │ Media Services │  │         │  │   Databases    │  │ │
│  │  │ Plex/Jellyfin  │  │         │  │ PostgreSQL     │  │ │
│  │  │ Nextcloud      │  │         │  │ MongoDB        │  │ │
│  │  │ Docker w/GPU   │  │         │  │                │  │ │
│  │  └────────────────┘  │         │  └────────────────┘  │ │
│  │  ┌────────────────┐  │         │  ┌────────────────┐  │ │
│  │  │ GPU Workloads  │  │         │  │   Monitoring   │  │ │
│  │  │ RTX 3070       │  │         │  │ Prometheus     │  │ │
│  │  │ AI/ML Tasks    │  │         │  │ Grafana        │  │ │
│  │  │                │  │         │  │ Home Assistant │  │ │
│  │  └────────────────┘  │         │  └────────────────┘  │ │
│  └──────────────────────┘         └──────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Claude Code + ProxmoxMCP-Plus              │ │
│  │                 AI Management Layer                    │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Command Examples (via Claude Code)

```bash
# VM Management
"Crie uma VM com 4 CPUs, 16GB RAM, 100GB storage para Nextcloud"
"Liste todas as VMs em execução no cluster"
"Mova a VM 'plex-server' do nó helios para o nó xeon"

# Container Management
"Crie um container LXC com 2 CPUs, 4GB RAM para Home Assistant"
"Reinicie o container 'monitoring' no nó xeon"

# Cluster Operations
"Verifique o status do cluster"
"Faça backup de todas as VMs criticas"
"Monitore o uso de recursos em ambos os nós"
```

## Shared Storage Options

### Option 1: NFS Server (Recommended)
- Set up NFS on one node or dedicated NAS
- Pros: Simple, reliable, cross-platform
- Cons: Single point of failure

### Option 2: iSCSI Target
- Better performance for database workloads
- Block-level storage
- More complex setup

### Option 3: Local Storage Only
- VMs stored locally
- Use replication for HA
- Simpler but limited migration

## Network Configuration

### Management Network
- VLAN 10: 192.168.10.0/24 (Cluster communication)
- Bonded interfaces for redundancy

### Storage Network
- VLAN 20: 192.168.20.0/24 (iSCSI/NFS traffic)
- Dedicated NICs if available

### Public Network
- VLAN 30: 192.168.31.0/24 (VM traffic)
- Current network setup

## Security Considerations

### Firewall Rules
```bash
# Cluster communication
pvecm allow 192.168.31.75
pvecm allow 192.168.31.208

# Storage traffic
# Allow NFS (2049), iSCSI (3260)

# Management access
# Allow HTTPS (8006) from trusted networks only
```

### API Security
- Use API tokens with least privilege
- Rotate tokens regularly
- Enable SSL certificates
- Implement fail2ban

## Backup Strategy

### Local Backup
- Daily incremental backups
- Weekly full backups
- Retention: 30 days

### Off-site Backup
- Critical VMs to external storage
- Configuration backups
- Documentation in Git

## Monitoring & Alerting

### Metrics to Monitor
- CPU/Memory usage per node
- Storage utilization
- Network throughput
- VM health status
- Cluster quorum

### Alert Channels
- Email notifications
- Telegram bot
- Dashboard alerts

## Timeline Estimate

| Phase | Duration | Dependencies |
|-------|----------|---------------|
| Preparation | 1-2 days | None |
| Installation | 1 day | Hardware available |
| Cluster Setup | 1 day | Installation complete |
| MCP Integration | 2-3 hours | Cluster running |
| VM Migration | 1-2 days | MCP working |
| Automation | Ongoing | VMs running |

**Total Initial Setup**: 4-6 days spread over 1-2 weeks

## Success Criteria

- [ ] Both nodes running Proxmox VE 9.1
- [ ] Cluster formed and healthy
- [ ] VM migration working between nodes
- [ ] MCP integration functional
- [ ] All services migrated and running
- [ ] Monitoring and alerting configured
- [ ] Documentation complete

## Risks & Mitigations

### Risk: Data Loss
- **Mitigation**: Complete backup before starting
- **Recovery**: Restore from backup

### Risk: Cluster Split-Brain
- **Mitigation**: Use quorum with odd number of nodes (add witness)
- **Recovery**: Manual intervention

### Risk: Downtime
- **Mitigation**: Staggered migration, test extensively
- **Recovery**: Rollback plan documented

## Next Steps

1. **Immediate**: Start Phase 1 - Backup and ISO download
2. **This Weekend**: Complete Phase 2 - Installation
3. **Next Week**: Phases 3-4 - Cluster and MCP setup
4. **Following Week**: Phases 5-6 - Migration and automation

## Resources

- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [ProxmoxMCP-Plus GitHub](https://github.com/RekklesNA/ProxmoxMCP-Plus)
- [Claude Code MCP Integration](https://claude.ai/blog/skills)
- [Proxmox VE 9.1 Release Notes](https://www.proxmox.com/en/about/company-details/press-releases/proxmox-virtual-environment-9-1)