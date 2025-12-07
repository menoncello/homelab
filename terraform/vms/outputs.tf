# VM IP Outputs
output "infra_monitoring_ip" {
  description = "Infrastructure monitoring VM IP"
  value       = module.infra_monitoring.vm_ip
}

output "media_server_ip" {
  description = "Media server VM IP"
  value       = module.media_server.vm_ip
}

output "prod_services_ip" {
  description = "Production services VM IP"
  value       = module.prod_services.vm_ip
}

output "databases_ip" {
  description = "Databases VM IP"
  value       = module.databases.vm_ip
}

output "books_server_ip" {
  description = "Books server VM IP"
  value       = module.books_server.vm_ip
}

output "storage_server_ip" {
  description = "Storage server VM IP"
  value       = module.storage_server.vm_ip
}

output "devops_server_ip" {
  description = "DevOps server VM IP"
  value       = module.devops_server.vm_ip
}


output "home_assistant_ip" {
  description = "Home Assistant IP"
  value       = "192.168.31.204"
}

# VM IDs Outputs
output "infra_monitoring_id" {
  description = "Infrastructure monitoring VM ID"
  value       = module.infra_monitoring.vm_id
}

output "media_server_id" {
  description = "Media server VM ID"
  value       = module.media_server.vm_id
}

output "prod_services_id" {
  description = "Production services VM ID"
  value       = module.prod_services.vm_id
}

output "databases_id" {
  description = "Databases VM ID"
  value       = module.databases.vm_id
}

output "books_server_id" {
  description = "Books server VM ID"
  value       = module.books_server.vm_id
}

output "storage_server_id" {
  description = "Storage server VM ID"
  value       = module.storage_server.vm_id
}

output "devops_server_id" {
  description = "DevOps server VM ID"
  value       = module.devops_server.vm_id
}

# Resource Allocation Summary
output "total_memory_allocated" {
  description = "Total memory allocated across all VMs"
  value = sum([
    module.infra_monitoring.vm_memory,
    module.media_server.vm_memory,
    module.prod_services.vm_memory,
    module.databases.vm_memory,
    module.books_server.vm_memory,
    module.storage_server.vm_memory,
    module.devops_server.vm_memory,
    2048    # home assistant LXC
  ])
}

output "total_cpu_cores_allocated" {
  description = "Total CPU cores allocated across all VMs"
  value = sum([
    module.infra_monitoring.vm_cores,
    module.media_server.vm_cores,
    module.prod_services.vm_cores,
    module.databases.vm_cores,
    module.books_server.vm_cores,
    module.storage_server.vm_cores,
    module.devops_server.vm_cores,
    1        # home assistant LXC
  ])
}

# VM Names Output
output "all_vms" {
  description = "All VM names and their IPs"
  value = {
    "infra-monitoring" = module.infra_monitoring.vm_ip
    "media-server"     = module.media_server.vm_ip
    "prod-services"    = module.prod_services.vm_ip
    "databases"        = module.databases.vm_ip
    "books-server"     = module.books_server.vm_ip
    "storage-server"   = module.storage_server.vm_ip
    "devops-server"    = module.devops_server.vm_ip
    "home-assistant"   = "192.168.31.204"
  }
}