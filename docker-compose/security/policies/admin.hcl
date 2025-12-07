# ============================================
# ADMIN POLICY
# ============================================

# Full access to all secrets
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# System management
path "sys/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Audit logs
path "sys/audit" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Policy management
path "sys/policies/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Auth methods
path "sys/auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Identity management
path "identity/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}