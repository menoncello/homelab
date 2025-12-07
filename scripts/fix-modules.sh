#!/bin/bash
# Script to fix provider variables in all VM modules

set -e

VMS_FILE="terraform/vms/main.tf"

# Array of VM module names
MODULES=(
  "infra_monitoring"
  "media_server"
  "prod_services"
  "databases"
  "books_server"
  "storage_server"
  "devops_server"
)

echo "🔧 Fixing provider variables in VM modules..."

# Read the file and process each module
python3 << 'EOF'
import re

# Read the file
with open('terraform/vms/main.tf', 'r') as f:
    content = f.read()

# Pattern to match module definitions
module_pattern = r'module "(\w+)" \{[^}]+?\}'

# Provider variables to add
provider_vars = '''  # Provider variables
  proxmox_api_url          = var.proxmox_api_url
  proxmox_user             = var.proxmox_user
  proxmox_password         = var.proxmox_password
  proxmox_api_token_id     = var.proxmox_api_token_id
  proxmox_api_token_secret = var.proxmox_api_token_secret
  proxmox_tls_insecure     = var.proxmox_tls_insecure'''

def fix_module(match):
    module_content = match.group(0)

    # Add provider variables before the closing brace
    if '# Provider variables' not in module_content:
        # Find the last tag line and add provider vars after it
        module_content = re.sub(
            r'(\s+tags\s*=\s*\[[^\]]*\])\s*\}',
            r'\1\n\n' + provider_vars + '\n}',
            module_content
        )

    return module_content

# Apply the fix to all modules
content = re.sub(module_pattern, fix_module, content, flags=re.DOTALL)

# Write back to file
with open('terraform/vms/main.tf', 'w') as f:
    f.write(content)

print("✅ Fixed provider variables in all VM modules")
EOF

echo "✅ VM modules fixed successfully!"