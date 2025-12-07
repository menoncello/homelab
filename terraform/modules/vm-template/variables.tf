variable "vm_name" {
  description = "VM name"
  type        = string
}

variable "target_node" {
  description = "Proxmox target node"
  type        = string
}

variable "clone_template" {
  description = "Template to clone from"
  type        = string
  default     = "ubuntu-2204-cloudinit"
}

variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
}

variable "memory_mb" {
  description = "Memory in MB"
  type        = number
}

variable "disk_size_gb" {
  description = "Disk size in GB"
  type        = number
}

variable "storage_pool" {
  description = "Storage pool name"
  type        = string
  default     = "local-zfs"
}

variable "ip_address" {
  description = "Static IP address"
  type        = string
}

variable "vlan_tag" {
  description = "VLAN tag"
  type        = number
  default     = 30
}

variable "cloudinit_template" {
  description = "Cloud-init template file"
  type        = string
  default     = "ubuntu-cloud-init.yaml"
}

variable "ssh_public_keys" {
  description = "SSH public keys"
  type        = list(string)
}

variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "proxmox_user" {
  description = "Proxmox user"
  type        = string
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

variable "tags" {
  description = "Tags for VM organization"
  type        = list(string)
  default     = ["homelab", "terraform"]
}