# Guia Completo de Skills Claude Code para Proxmox & Homelab

## 🎯 Skills Essenciais para Seu Homelab

### 📊 Tabela Comparativa de Skills

| Skill | Estrelas | Instalações | Autor | Última Atualização | Foco Principal | Recomendação |
|-------|----------|-------------|-------|-------------------|----------------|-------------|
| **proxmox-infrastructure** | ⭐ 2 | 1 | @basher83 | Out 2025 | Templates, Ansible, Terraform, CEPH | 🏆 **Essencial** |
| **DevOps Engineer** | ⭐ 3 | 8 | @Jeffallan | Out 2025 | CI/CD, Docker, Kubernetes, IaC | 🏆 **Essencial** |
| **homeassistant** | ⭐ 0 | 1 | @madeinoz67 | Out 2025 | Home Assistant, automações | 🎯 **Recomendado** |
| **team-builder** | - | - | @edwardhallam | Recent | Setup de projetos, plugins | 🔧 **Utilitário** |
| **kubernetes-operations** | - | - | @laurigates | Recent | K8s management, debugging | ☁️ **Futuro** |

## 🚀 Skills Essenciais (Instalar Primeiro)

### 1️⃣ **proxmox-infrastructure** - @basher83

**Por que é essencial:**
✅ **Autoridade**: Autor com cluster real de 3 nós MINISFORUM
✅ **Completo**: Templates, Ansible, Terraform, CEPH, networking
✅ **Prático**: Exemplos reais de microk8s cluster
✅ **Enterprise**: Best practices e anti-patterns

**Quando usar:**
- Criar templates de VMs
- Configurar networking (VLANs, bridges)
- Provisionar VMs via cloning
- Troubleshooting de infraestrutura
- Gerenciar storage CEPH

**Comandos exemplo:**
```
"Crie um template Ubuntu com cloud-init"
"Configure VLAN-aware bridges no cluster"
"Provisione 3 VMs para cluster Kubernetes"
```

### 2️⃣ **DevOps Engineer** - @Jeffallan

**Por que é essencial:**
✅ **3 personas**: Build Engineer, Release Manager, SRE
✅ **Completo**: CI/CD, Docker, Kubernetes, monitoring
✅ **Documentation**: Auto-gera summaries markdown
✅ **Production ready**: Security, scalability, disaster recovery

**Quando usar:**
- Setup de CI/CD pipelines
- Docker containerization
- Kubernetes deployment
- Infrastructure as Code
- Monitoring e alerting

**Comandos exemplo:**
```
"Setup CI/CD pipeline para minha aplicação"
"Containerize esta aplicação com Docker"
"Deploy Kubernetes com rolling update"
"Configure monitoring Prometheus+Grafana"
```

## 🎯 Skills Recomendadas (Adicionar Depois)

### 3️⃣ **homeassistant** - @madeinoz67

**Por que recomendar:**
✅ **Especialista**: Custom sensors, dashboards, integrations
✅ **Completo**: Template sensors, REST, Python components
✅ **Avançado**: Custom integrations com config flows

**Quando usar:**
- Criar sensors customizados
- Build dashboards Lovelace
- Desenvolver integrações Python
- Automatizations complexas

**Comandos exemplo:**
```
"Crie sensor template para calcular temperatura aparente"
"Build dashboard para controle de iluminação"
"Desenvolva integração com API externa"
```

## 🔧 Skills Utilitárias

### 4️⃣ **team-builder** - @edwardhallam

**Função:**
- Montar equipe de desenvolvimento AI
- Setup de plugins e subagents
- Otimizado para homelab infrastructure

**Ideal para:**
- Iniciar novos projetos
- Configurar ambiente Claude Code
- Automatizar setup de workflows

### 5️⃣ **kubernetes-operations** - @laurigates

**Função:**
- Management de clusters K8s
- Debugging e troubleshooting
- Workloads, networking, storage

**Ideal para:**
- Quando implementar Kubernetes no homelab
- Troubleshooting de aplicações
- Otimização de clusters

## 📋 Plano de Instalação de Skills

### Fase 1: Essenciais (Hoje)

```bash
# 1. Proxmox Infrastructure
claude skill install @basher83/lunar-claude/proxmox-infrastructure

# 2. DevOps Engineer
claude skill install @Jeffallan/claude-skills/devops-engineer
```

### Fase 2: Homelab (Semana seguinte)

```bash
# 3. Home Assistant
claude skill install @madeinoz67/HA-CloudCover/homeassistant

# 4. Team Builder
claude skill install @edwardhallam/claude-skills/latest
```

### Fase 3: Cloud Native (Quando precisar)

```bash
# 5. Kubernetes Operations
claude skill install @laurigates/dotfiles/kubernetes-operations
```

## 🎯 Use Cases Práticos para Seu Homelab

### **Setup Inicial com Proxmox**
```
Use skill: proxmox-infrastructure
"Crie template Ubuntu 22.04 com cloud-init para meu cluster"
"Configure rede com VLANs para isolamento de serviços"
"Provisione VM para Nextcloud com 4GB RAM e 50GB storage"
```

### **Deploy de Serviços com DevOps**
```
Use skill: DevOps Engineer
"Containerize aplicação web com Docker"
"Setup CI/CD para autodeploy quando commitar"
"Configure monitoring com Prometheus+Grafana"
```

### **Automação Residencial**
```
Use skill: homeassistant
"Crie sensor para monitorar consumo dos servidores"
"Build dashboard para controle de smart home"
"Desenvolva integração com API do clima"
```

## 🔗 Integração com ProxmoxMCP-Plus

**Workflow completo:**

1. **ProxmoxMCP-Plus** → Gerencia VMs via IA
2. **proxmox-infrastructure** → Templates e automação avançada
3. **DevOps Engineer** → Deploy e monitoring das aplicações
4. **homeassistant** → Automação e dashboards

**Exemplo de workflow integrado:**
```
Humano: "Quero setup de media server completo"

Claude (com skills):
1. [ProxmoxMCP-Plus] "Criando VM com 8GB RAM, GPU passthrough"
2. [proxmox-infrastructure] "Usando template Ubuntu otimizado"
3. [DevOps Engineer] "Deployando Plex com Docker compose"
4. [homeassistant] "Criando dashboard para controle remoto"
```

## 🚀 Cenários de Uso Avançados

### **Cluster Kubernetes Homelab**
```
1. proxmox-infrastructure: "Criar 3 VMs para Kubernetes"
2. DevOps Engineer: "Instalar K3s cluster"
3. kubernetes-operations: "Configurar networking e storage"
4. DevOps Engineer: "Deploy aplicações com GitOps"
```

### **CI/CD Pipeline Completo**
```
1. proxmox-infrastructure: "Provisionar VM build agent"
2. DevOps Engineer: "Setup Jenkins/GitLab Runner"
3. DevOps Engineer: "Configure pipeline stages"
4. proxmox-infrastructure: "Criar templates para deploy"
```

### **Monitoring & Observability**
```
1. DevOps Engineer: "Deploy Prometheus+Grafana stack"
2. homeassistant: "Criar dashboard no HA"
3. ProxmoxMCP-Plus: "Monitor health das VMs"
4. DevOps Engineer: "Configurar alertas no Telegram"
```

## 💡 Dicas de Uso

### **Maximizando Eficiência:**
1. **Uma task de cada vez** - Deixe Claude focar
2. **Context switch claro** - "Agora vamos trabalhar com..."
3. **Use as personas** - Build/Deploy/Ops do DevOps Engineer
4. **Documentação automática** - Skills geram summaries

### **Integração com MCP:**
- **ProxmoxMCP-Plus**: Operações básicas de VM
- **Skills**: Workflows complexos e especializados
- **Combine**: Use ambos para máximo poder

### **Best Practices:**
1. **Start small** - Use uma skill de cada vez
2. **Build complexity** - Adicione skills conforme precisa
3. **Test first** - Valide em ambiente dev
4. **Document** - Use auto-documentação das skills

## 🔍 Como Instalar Skills

### **Via Claude Code CLI:**
```bash
# Listar skills disponíveis
claude skill list

# Instalar skill específica
claude skill install @basher83/lunar-claude/proxmox-infrastructure

# Ver skills instaladas
claude skill status

# Remover skill
claude skill uninstall proxmox-infrastructure
```

### **Via Arquivo .claude/skills:**
```json
{
  "skills": [
    "@basher83/lunar-claude/proxmox-infrastructure",
    "@Jeffallan/claude-skills/devops-engineer",
    "@madeinoz67/HA-CloudCover/homeassistant"
  ]
}
```

## 🎯 Conclusão

**Para seu homelab com 2 servidores Proxmox:**

1. **Comece com:** `proxmox-infrastructure` + `DevOps Engineer`
2. **Adicione depois:** `homeassistant` (se usar HA)
3. **Futuro:** `kubernetes-operations` (se implementar K8s)

**Esta combinação oferece:**
- ✅ **Gestão completa** de infraestrutura Proxmox
- ✅ **DevOps moderno** com CI/CD e containers
- ✅ **Automação residencial** integrada
- ✅ **Escalabilidade** para Kubernetes quando precisar
- ✅ **Produtividade máxima** com workflows AI-driven

**Próximos passos:**
1. Instalar as 2 skills essenciais hoje
2. Testar com seus servidores atuais
3. Expandir conforme necessário