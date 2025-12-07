variable "helios_node" {
  description = "Helios Proxmox node"
  type        = string
}

variable "xeon_node" {
  description = "Xeon Proxmox node"
  type        = string
}

variable "ssh_public_keys" {
  description = "SSH public keys for VMs"
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