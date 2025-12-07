# Pré-requisitos Proxmox

## 1. Criar Template Ubuntu Cloud-Init

Execute estes comandos no nó Proxmox (via SSH ou Web Shell):

```bash
# Baixar imagem Ubuntu 22.04 Cloud
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# Criar VM template
qm create 9000 --name ubuntu-2204-cloudinit --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0

# Importar imagem
qm importdisk 9000 jammy-server-cloudimg-amd64.img local-zfs

# Configurar VM
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-zfs:vm-9000-disk-0
qm set 9000 --ide2 local-zfs:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1

# Converter para template
qm template 9000
```

## 2. Verificar Storage Pools

```bash
# Listar storages disponíveis
pvesm status

# Verificar se local-zfs existe
pvesm status | grep local-zfs
```

Se não tiver `local-zfs`, substitua por `local` ou outro storage disponível.

## 3. Configurar Rede

Verificar se bridge `vmbr0` existe:
```bash
ip a show vmbr0
```

## 4. Testar API Access

Se o MCP já conecta, a API está funcionando. Teste com:
```bash
# Via curl se precisar testar
curl -k "https://192.168.31.75:8006/api2/json/version"
```

---

**Depois de executar estes passos, volte aqui e eu começo a implementação do Task 1.**