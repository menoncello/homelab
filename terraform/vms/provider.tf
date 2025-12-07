terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.44.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_api_url
  username = var.proxmox_user
  password = var.proxmox_password
  api_token = "${var.proxmox_api_token_id}:${var.proxmox_api_token_secret}"
  insecure = var.proxmox_tls_insecure
}