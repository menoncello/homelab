# ============================================
# CUSTOM SERVICES POLICY
# ============================================

# Read access to custom service secrets
path "secret/data/custom/*" {
  capabilities = ["read", "list"]
}

# Write access for service-specific secrets
path "secret/data/custom/{{identity.entity.name}}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Database dynamic secrets
path "database/creds/homelab-app" {
  capabilities = ["read"]
}

path "database/creds/homelab-readonly" {
  capabilities = ["read"]
}

# PKI certificates for internal services
path "pki/homelab-pki/issue/*" {
  capabilities = ["create", "update"]
}

path "pki/homelab-pki/cert/*" {
  capabilities = ["read"]
}

# Transit secrets for encryption/decryption
path "transit/encrypt/custom-*" {
  capabilities = ["create", "update"]
}

path "transit/decrypt/custom-*" {
  capabilities = ["create", "update"]
}

# Identity tokens for service-to-service auth
path "identity/token" {
  capabilities = ["read"]
}