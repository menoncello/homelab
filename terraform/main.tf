terraform {
  required_version = ">= 1.6.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.44.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "proxmox" {
  endpoint = var.proxmox_api_url
  username = var.proxmox_user
  password = var.proxmox_password
  api_token = "${var.proxmox_api_token_id}:${var.proxmox_api_token_secret}"
  insecure = var.proxmox_tls_insecure
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Common variables
locals {
  environment = terraform.workspace
  tags = {
    Environment = local.environment
    Project     = "Homelab"
    ManagedBy   = "Terraform"
  }
}

# Call VM modules
module "vms" {
  source = "./vms"

  helios_node = var.helios_node
  xeon_node  = var.xeon_node
  ssh_public_keys = var.ssh_public_keys

  # Provider variables
  proxmox_api_url          = var.proxmox_api_url
  proxmox_user             = var.proxmox_user
  proxmox_password         = var.proxmox_password
  proxmox_api_token_id     = var.proxmox_api_token_id
  proxmox_api_token_secret = var.proxmox_api_token_secret
  proxmox_tls_insecure     = var.proxmox_tls_insecure
}