resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.vm_name
  node_name   = var.target_node

  cpu {
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.memory_mb
  }

  agent {
    enabled = true
  }

  # Disks - Use first boot disk
  disk {
    datastore_id = var.storage_pool
    size         = var.disk_size_gb
  }

  # Network
  network_device {
    bridge = "vmbr0"
    vlan_tag = var.vlan_tag
  }

  # Tags
  tags = join(",", var.tags)

  # Cloud-init via serial console (for now, simplified)
  serial_device {
    device = "socket"
  }

  # Basic cloud-init config
  boot_order = ["scsi0"]
}