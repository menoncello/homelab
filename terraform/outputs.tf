# Infrastructure outputs
output "proxmox_api_url" {
  description = "Proxmox API URL"
  value       = var.proxmox_api_url
}

output "helios_node" {
  description = "Helios Proxmox node"
  value       = var.helios_node
}

output "xeon_node" {
  description = "Xeon Proxmox node"
  value       = var.xeon_node
}

output "domain" {
  description = "Base domain for services"
  value       = var.domain
}

# Storage outputs
output "storage_pools" {
  description = "Available storage pools"
  value       = var.storage_pools
}

# Network outputs
output "network_config" {
  description = "Network configuration"
  value       = var.network_config
}