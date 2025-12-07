variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://192.168.31.75:8006/api2/json"
}

variable "proxmox_user" {
  description = "Proxmox user"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_id" {
  description = "Proxmox API Token ID"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification"
  type        = bool
  default     = true
}

# VM Configuration Variables
variable "vm_templates" {
  description = "VM templates configuration"
  type = map(object({
    node         = string
    vm_id        = number
    name         = string
    description  = string
    cores        = number
    memory       = number
    disk_size    = string
    storage_pool = string
    network = object({
      bridge  = string
      vlan    = number
      ip      = string
      gateway = string
    })
    tags = list(string)
  }))
  default = {}
}

# Container Configuration Variables
variable "lxc_containers" {
  description = "LXC containers configuration"
  type = map(object({
    node         = string
    vm_id        = number
    name         = string
    description  = string
    template     = string
    cores        = number
    memory       = number
    disk_size    = string
    storage_pool = string
    network = object({
      bridge  = string
      vlan    = number
      ip      = string
      gateway = string
    })
    features = object({
      nesting = bool
      fuse    = bool
    })
    tags = list(string)
  }))
  default = {}
}

# Network Configuration
variable "network_config" {
  description = "Network configuration"
  type = object({
    management_bridge = string
    vm_bridge         = string
    storage_bridge    = string
    subnet            = string
    gateway           = string
    dns_servers       = list(string)
    vlan_ranges = object({
      management = number
      storage    = number
      vms        = number
    })
  })
  default = {
    management_bridge = "vmbr0"
    vm_bridge         = "vmbr1"
    storage_bridge    = "vmbr2"
    subnet            = "192.168.31.0/24"
    gateway           = "192.168.31.1"
    dns_servers       = ["1.1.1.1", "8.8.8.8"]
    vlan_ranges = {
      management = 10
      storage    = 20
      vms        = 30
    }
  }
}

# Storage Configuration
variable "storage_pools" {
  description = "Storage pools configuration"
  type = map(object({
    type     = string
    path     = string
    content  = list(string)
    shared   = bool
    max_size = string
  }))
  default = {
    local-zfs = {
      type     = "zfspool"
      path     = "rpool/data"
      content  = ["images", "rootdir"]
      shared   = false
      max_size = "200GB"
    }
    local-lvm = {
      type     = "lvm-thin"
      path     = "pve/data"
      content  = ["images", "rootdir"]
      shared   = false
      max_size = "100GB"
    }
  }
}

# Cloudflare variables
variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Base domain for services"
  type        = string
  default     = "homelab.local"
}

variable "helios_node" {
  description = "Proxmox node name for Helios server"
  type        = string
  default     = "pve-helios"
}

variable "xeon_node" {
  description = "Proxmox node name for Xeon server"
  type        = string
  default     = "pve-xeon"
}

variable "ssh_public_keys" {
  description = "SSH public keys for VMs"
  type        = list(string)
}