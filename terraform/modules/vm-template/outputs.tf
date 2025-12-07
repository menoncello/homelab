output "vm_id" {
  description = "VM ID in Proxmox"
  value       = proxmox_virtual_environment_vm.vm.id
}

output "vm_ip" {
  description = "VM IP address"
  value       = var.ip_address
}

output "vm_name" {
  description = "VM name"
  value       = proxmox_virtual_environment_vm.vm.name
}

output "vm_node" {
  description = "Proxmox node where VM is located"
  value       = proxmox_virtual_environment_vm.vm.node_name
}

output "vm_memory" {
  description = "VM memory in MB"
  value       = var.memory_mb
}

output "vm_cores" {
  description = "VM CPU cores"
  value       = var.cpu_cores
}