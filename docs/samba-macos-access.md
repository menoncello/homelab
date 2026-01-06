# Acesso Samba/SMB do macOS

## Configuração

O Samba está configurado para compartilhar `/media` do Helios via rede SMB.

**Detalhes do Compartilhamento:**
- **Servidor:** 192.168.31.5 (Helios)
- **Share:** `media`
- **Usuário:** `eduardo`
- **Portas:** 139, 445 (TCP), 137, 138 (UDP)

## Acesso via Finder

### Acesso Rápido (Não Permanente)

1. Abra o **Finder**
2. Pressione `Cmd + K` (ou Ir → Conectar ao Servidor)
3. Digite: `smb://192.168.31.5`
4. Clique em **Conectar**
5. Selecione o share `media`
6. Entre com usuário `eduardo` e senha (configurada no `.env`)

O share aparecerá no Finder e você poderá arrastar arquivos para copiar.

## Mount Permanente (Auto-conecta ao iniciar)

### Opção 1: Adicionar aos itens de login

1. Conecte ao share uma vez (instruções acima)
2. O share aparecerá na barra lateral do Finder
3. Arraste o share para dentro de sua pasta Home
4. Sistema → Geral → Itens de Login → Adicione o alias criado

### Opção 2: Usar `autofs` (Mount via sistema de arquivos)

**1. Criar ponto de mount:**
```bash
sudo mkdir -p /Volumes/media
```

**2. Editar configuração do autofs:**
```bash
sudo vifs
```

**3. Adicionar esta linha:**
```
/media -fstype=smbfs,rw ://eduardo:PASSWORD@192.168.31.5/media
```
(Substitua `PASSWORD` pela senha real)

**4. Recarregar autofs:**
```bash
sudo automount -vc
```

O share estará disponível em `/media` automaticamente.

### Opção 3: Criar script de mount automático

**1. Criar arquivo de credenciais (sem mostrar na history):**
```bash
cat > ~/.smbcreds << 'EOF'
username=eduardo
password=YOUR_PASSWORD
domain=WORKGROUP
EOF
chmod 600 ~/.smbcreds
```

**2. Criar ponto de mount:**
```bash
sudo mkdir -p /Volumes/media
```

**3. Adicionar entry ao `/etc/fstab`:**
```bash
sudo vifs
```

Adicionar:
```
//192.168.31.5/media /Volumes/media smbfs rw,soft,noatime,nodev,nosuid,-N ~/.smbcreds 0 0
```

**4. Mount:**
```bash
sudo mount -a
```

## Acesso via Terminal

### Usar `smbclient` (incluído no macOS)

```bash
# Listar shares
smbclient -L 192.168.31.5 -U eduardo

# Acessar share interativo
smbclient //192.168.31.5/media -U eduardo

# Comandos dentro do smbclient:
# ls, cd, get, put, mkdir, rmdir
```

### Mount via linha de comando

```bash
# Mount manual
mount -t smbfs //eduardo:PASSWORD@192.168.31.5/media /Volumes/media

# Unmount
umount /Volumes/media
```

## Copiar Arquivos via Terminal

```bash
# Copiar arquivo local para o share
cp arquivo.mp4 /Volumes/media/

# Copiar do share para local
cp /Volumes/media/filme.mp4 ~/Downloads/

# Copiar diretórios recursivamente
rsync -av ~/Music/ /Volumes/media/music/
```

## Troubleshooting

### Share não aparece

1. Verifique se o container está rodando:
```bash
docker service logs samba-stack_samba
```

2. Teste conectividade:
```bash
ping 192.168.31.5
telnet 192.168.31.5 445
```

3. Verifique portas abertas no Helios:
```bash
# No Helios
sudo netstat -tulpn | grep -E ':(139|445|137|138)'
```

### Erro de autenticação

1. Verifique senha no `.env`:
```bash
cat stacks/samba-stack/.env | grep SAMBA_PASSWORD
```

2. Teste autenticação:
```bash
smbclient //192.168.31.5/media -U eduardo
```

### Performance lenta

Para melhor performance, use SMB3:

```bash
# Mount com SMB3
mount -t smbfs -o vers=3.0 //eduardo:PASSWORD@192.168.31.5/media /Volumes/media
```

### Permissões negadas

Verifique permissões no Helios:
```bash
# No Helios
ls -la /media/
```

O diretório `/media` deve ser acessível pelo UID 1000.

## Deploy do Samba

Se ainda não deployou:

```bash
# 1. Configurar senha
cd stacks/samba-stack
cp .env.example .env
nano .env  # Defina SAMBA_PASSWORD

# 2. Deploy
./scripts/deploy-samba.sh

# 3. Verificar
docker service ps samba-stack_samba
docker service logs -f samba-stack_samba
```

## Segurança

- Use uma senha forte no `SAMBA_PASSWORD`
- O compartilhamento está disponível apenas na rede local (192.168.31.x)
- A autenticação é obrigatória (guest ok = no)
- Considere usar VPN se precisar acessar de fora da rede

## Links Úteis

- [Apple SMB Documentation](https://support.apple.com/guide/mac-help/connect-a-computer-using-file-sharing-mh17137/mac)
- [Samba Configuration](https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html)
