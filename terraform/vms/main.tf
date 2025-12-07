# Infrastructure Monitoring VM (enhanced)
module "infra_monitoring" {
  source = "../modules/vm-template"

  vm_name        = "infra-monitoring"
  target_node   = var.xeon_node
  cpu_cores      = 4
  memory_mb      = 6144
  disk_size_gb   = 80
  storage_pool   = "local-zfs"
  ip_address     = "192.168.31.201"
  cloudinit_template = "ubuntu-cloud-init.yaml"
  ssh_public_keys = var.ssh_public_keys
  tags = ["homelab", "monitoring", "infrastructure"]

  # Provider variables
  proxmox_api_url          = var.proxmox_api_url
  proxmox_user             = var.proxmox_user
  proxmox_password         = var.proxmox_password
  proxmox_api_token_id     = var.proxmox_api_token_id
  proxmox_api_token_secret = var.proxmox_api_token_secret
  proxmox_tls_insecure     = var.proxmox_tls_insecure
}

# Media Server VM (enhanced with GPU support)
module "media_server" {
  source = "../modules/vm-template"

  vm_name        = "media-server"
  target_node   = var.helios_node
  cpu_cores      = 8
  memory_mb      = 24576
  disk_size_gb   = 300
  storage_pool   = "local-zfs"
  ip_address     = "192.168.31.151"
  cloudinit_template = "ubuntu-cloud-init.yaml"
  ssh_public_keys = var.ssh_public_keys
  tags = ["homelab", "media", "gpu"]

  # Provider variables
  proxmox_api_url          = var.proxmox_api_url
  proxmox_user             = var.proxmox_user
  proxmox_password         = var.proxmox_password
  proxmox_api_token_id     = var.proxmox_api_token_id
  proxmox_api_token_secret = var.proxmox_api_token_secret
  proxmox_tls_insecure     = var.proxmox_tls_insecure
}

# Production Services VM (enhanced)
module "prod_services" {
  source = "../modules/vm-template"

  vm_name        = "prod-services"
  target_node   = var.xeon_node
  cpu_cores      = 6
  memory_mb      = 20480
  disk_size_gb   = 250
  storage_pool   = "local-zfs"
  ip_address     = "192.168.31.202"
  cloudinit_template = "ubuntu-cloud-init.yaml"
  ssh_public_keys = var.ssh_public_keys
  tags = ["homelab", "productivity", "services"]

  # Provider variables
  proxmox_api_url          = var.proxmox_api_url
  proxmox_user             = var.proxmox_user
  proxmox_password         = var.proxmox_password
  proxmox_api_token_id     = var.proxmox_api_token_id
  proxmox_api_token_secret = var.proxmox_api_token_secret
  proxmox_tls_insecure     = var.proxmox_tls_insecure
}

# Databases VM (maximized)
module "databases" {
  source = "../modules/vm-template"

  vm_name        = "databases"
  target_node   = var.xeon_node
  cpu_cores      = 6
  memory_mb      = 40960
  disk_size_gb   = 400
  storage_pool   = "local-zfs"
  ip_address     = "192.168.31.203"
  cloudinit_template = "ubuntu-cloud-init.yaml"
  ssh_public_keys = var.ssh_public_keys
  tags = ["homelab", "database", "storage"]

  # Provider variables
  proxmox_api_url          = var.proxmox_api_url
  proxmox_user             = var.proxmox_user
  proxmox_password         = var.proxmox_password
  proxmox_api_token_id     = var.proxmox_api_token_id
  proxmox_api_token_secret = var.proxmox_api_token_secret
  proxmox_tls_insecure     = var.proxmox_tls_insecure
}

# Books Server VM (enhanced)
module "books_server" {
  source = "../modules/vm-template"

  vm_name        = "books-server"
  target_node   = var.xeon_node
  cpu_cores      = 4
  memory_mb      = 12288
  disk_size_gb   = 600
  storage_pool   = "local-zfs"
  ip_address     = "192.168.31.205"
  cloudinit_template = "ubuntu-cloud-init.yaml"
  ssh_public_keys = var.ssh_public_keys
  tags = ["homelab", "books", "media"]

  # Provider variables
  proxmox_api_url          = var.proxmox_api_url
  proxmox_user             = var.proxmox_user
  proxmox_password         = var.proxmox_password
  proxmox_api_token_id     = var.proxmox_api_token_id
  proxmox_api_token_secret = var.proxmox_api_token_secret
  proxmox_tls_insecure     = var.proxmox_tls_insecure
}

# Storage Server VM (enhanced)
module "storage_server" {
  source = "../modules/vm-template"

  vm_name        = "storage-server"
  target_node   = var.xeon_node
  cpu_cores      = 4
  memory_mb      = 12288
  disk_size_gb   = 200
  storage_pool   = "local-zfs"
  ip_address     = "192.168.31.206"
  cloudinit_template = "ubuntu-cloud-init.yaml"
  ssh_public_keys = var.ssh_public_keys
  tags = ["homelab", "storage", "s3"]

  # Provider variables
  proxmox_api_url          = var.proxmox_api_url
  proxmox_user             = var.proxmox_user
  proxmox_password         = var.proxmox_password
  proxmox_api_token_id     = var.proxmox_api_token_id
  proxmox_api_token_secret = var.proxmox_api_token_secret
  proxmox_tls_insecure     = var.proxmox_tls_insecure
}

# DevOps Server VM (enhanced)
module "devops_server" {
  source = "../modules/vm-template"

  vm_name        = "devops-server"
  target_node   = var.xeon_node
  cpu_cores      = 8
  memory_mb      = 18432
  disk_size_gb   = 150
  storage_pool   = "local-zfs"
  ip_address     = "192.168.31.207"
  cloudinit_template = "ubuntu-cloud-init.yaml"
  ssh_public_keys = var.ssh_public_keys
  tags = ["homelab", "devops", "development"]

  # Provider variables
  proxmox_api_url          = var.proxmox_api_url
  proxmox_user             = var.proxmox_user
  proxmox_password         = var.proxmox_password
  proxmox_api_token_id     = var.proxmox_api_token_id
  proxmox_api_token_secret = var.proxmox_api_token_secret
  proxmox_tls_insecure     = var.proxmox_tls_insecure
}

# Home Assistant LXC Container (commented for now)
# resource "proxmox_container" "home_assistant" {
#   target_node = var.xeon_node
#   hostname    = "home-assistant"
#   ostemplate   = "local:vztmpl/homeassistant-amd64-*.tar.zst"
#
#   cores       = 1
#   memory      = 2048
#
#   network {
#     name   = "eth0"
#     bridge = "vmbr0"
#     ip     = "192.168.31.204/24"
#     gw     = "192.168.31.1"
#   }
#
#   mount {
#     mp    = "/config"
#     type  = "volume"
#     volume = "local-zfs:16"
#   }
#
#   unprivileged = true
#
#   tags = "homelab,smarthome,lxc"
#
#   # Environment variables for Home Assistant
#   environment = {
#     TZ = "America/Sao_Paulo"
#   }
# }