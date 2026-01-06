#!/bin/bash

# Install and configure Samba directly on host (not Docker)
# This provides better macOS compatibility

set -e

echo "=== Installing Samba on host ==="

# Update and install
sudo apt update
sudo apt install -y samba smbclient

# Backup original config
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak.$(date +%Y%m%d)

# Create new config
sudo tee /etc/samba/smb.conf > /dev/null <<'EOF'
[global]
   workgroup = WORKGROUP
   server string = Helios
   server role = standalone server
   security = user

   # Protocol settings
   server min protocol = SMB2
   client min protocol = SMB2
   server max protocol = SMB3

   # macOS compatibility
   vfs objects = catia fruit streams_xattr
   fruit:aapl = yes
   fruit:metadata = stream
   fruit:encoding = UTF8-MAC
   fruit:time_machine = max

   # Logging
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file

   # Performance
   socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072
   use sendfile = yes

   # Network
   bind interfaces only = yes
   interfaces = 192.168.31.0/24
   hosts allow = 192.168.31. 127.0.0.1

[media]
   comment = Media Library
   path = /media
   browseable = yes
   read only = no
   create mask = 0777
   directory mask = 0777
   valid users = eduardo
   write list = eduardo
   veto files = /._*/.DS_Store/
   delete veto files = yes
EOF

# Create Samba user (will prompt for password)
echo ""
echo "Creating Samba user 'eduardo'"
echo "You will need to enter your Unix password twice, then set a Samba password"
sudo smbpasswd -a eduardo

# Enable and start service
sudo systemctl enable smbd nmbd
sudo systemctl restart smbd nmbd

# Check status
echo ""
echo "=== Samba Status ==="
sudo systemctl status smbd --no-pager -l | head -20

echo ""
echo "=== Samba is now running on host ==="
echo "To test from macOS:"
echo "  Finder → Cmd+K → smb://192.168.31.5"
echo ""
echo "To view logs:"
echo "  sudo tail -f /var/log/samba/log.smbd"
