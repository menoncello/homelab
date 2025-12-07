#!/bin/bash
# HashiCorp Vault Setup Script for Homelab
# =========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
VAULT_ADDR="http://localhost:8200"
VAULT_TOKEN="${VAULT_ROOT_TOKEN:-hvs.homelab-root-token-very-secure-string}"

log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

# Wait for Vault to be ready
wait_for_vault() {
    log "Waiting for Vault to be ready..."

    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$VAULT_ADDR/v1/sys/health" > /dev/null; then
            success "Vault is ready!"
            return 0
        fi

        log "Attempt $attempt/$max_attempts - Vault not ready yet..."
        sleep 2
        ((attempt++))
    done

    error "Vault failed to start after $max_attempts attempts"
    exit 1
}

# Initialize Vault (only for production mode)
initialize_vault() {
    if ! vault status -format=json | jq -r '.initialized' | grep -q true; then
        log "Initializing Vault..."

        local init_output=$(vault operator init -key-shares=5 -key-threshold=3 -format=json)

        echo "$init_output" | jq -r '.unseal_keys_hex[]' > /tmp/vault-unseal-keys.txt
        echo "$init_output" | jq -r '.root_token' > /tmp/vault-root-token.txt

        chmod 600 /tmp/vault-*.txt

        success "Vault initialized!"
        warning "SAVE THESE KEYS SECURELY:"
        cat /tmp/vault-unseal-keys.txt
        cat /tmp/vault-root-token.txt

        log "Keys saved to /tmp/vault-unseal-keys.txt and /tmp/vault-root-token.txt"
    else
        success "Vault already initialized"
    fi
}

# Unseal Vault (only for production mode)
unseal_vault() {
    if vault status -format=json | jq -r '.sealed' | grep -q true; then
        log "Vault is sealed, attempting to unseal..."

        if [ -f /tmp/vault-unseal-keys.txt ]; then
            local unseal_keys=($(head -3 /tmp/vault-unseal-keys.txt))

            for key in "${unseal_keys[@]}"; do
                vault operator unseal "$key"
            done

            success "Vault unsealed successfully"
        else
            error "Unseal keys not found. Cannot unseal Vault."
            return 1
        fi
    else
        success "Vault is already unsealed"
    fi
}

# Setup auth methods
setup_auth_methods() {
    log "Setting up authentication methods..."

    # Enable AppRole auth
    if ! vault auth list | grep -q "approle/"; then
        vault auth enable approle
        success "AppRole auth enabled"
    fi

    # Enable userpass auth
    if ! vault auth list | grep -q "userpass/"; then
        vault auth enable userpass
        success "UserPass auth enabled"
    fi

    # Enable Kubernetes auth (optional)
    if command -v kubectl &> /dev/null && vault auth list | grep -qv "kubernetes/"; then
        vault auth enable kubernetes
        success "Kubernetes auth enabled"
    fi
}

# Setup policies
setup_policies() {
    log "Setting up Vault policies..."

    # Admin policy
    vault policy write admin policies/admin.hcl
    success "Admin policy created"

    # Custom services policy
    vault policy write custom-services policies/custom-services.hcl
    success "Custom services policy created"

    # Create read-only policy for monitoring
    cat > /tmp/readonly-policy.hcl << EOF
path "*" {
  capabilities = ["read", "list"]
}
EOF
    vault policy write readonly /tmp/readonly-policy.hcl
    success "Read-only policy created"
}

# Setup AppRoles for custom services
setup_approles() {
    log "Setting up AppRoles for custom services..."

    # Create AppRole for web applications
    vault write auth/approle/role/web-app \
        token_policies="custom-services" \
        token_ttl=24h \
        token_max_ttl=720h \
        secret_id_ttl=24h

    # Create AppRole for background services
    vault write auth/approle/role/background-service \
        token_policies="custom-services" \
        token_ttl=168h \
        token_max_ttl=720h \
        secret_id_ttl=168h

    # Generate credentials for documentation
    local role_id_web=$(vault read -field=role_id auth/approle/role/web-app/role-id)
    local secret_id_web=$(vault write -f -field=secret_id auth/approle/role/web-app/secret-id)

    echo "=== WEB APP CREDENTIALS ===" > /tmp/vault-approles.txt
    echo "Role ID: $role_id_web" >> /tmp/vault-approles.txt
    echo "Secret ID: $secret_id_web" >> /tmp/vault-approles.txt
    echo "" >> /tmp/vault-approles.txt

    local role_id_bg=$(vault read -field=role_id auth/approle/role/background-service/role-id)
    local secret_id_bg=$(vault write -f -field=secret_id auth/approle/role/background-service/secret-id)

    echo "=== BACKGROUND SERVICE CREDENTIALS ===" >> /tmp/vault-approles.txt
    echo "Role ID: $role_id_bg" >> /tmp/vault-approles.txt
    echo "Secret ID: $secret_id_bg" >> /tmp/vault-approles.txt

    chmod 600 /tmp/vault-approles.txt

    success "AppRoles created. Credentials saved to /tmp/vault-approles.txt"
}

# Setup database secrets engine
setup_database_secrets() {
    log "Setting up database secrets engine..."

    # Configure MySQL
    vault write database/config/mysql \
        plugin_name=mysql-database-plugin \
        connection_url="{{username}}:{{password}}@tcp(mysql:3306)/" \
        allowed_roles="homelab-app,homelab-readonly" \
        username="root" \
        password="${MYSQL_ROOT_PASSWORD}"

    # MySQL role for applications
    vault write database/roles/homelab-app \
        db_name=mysql \
        creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}'; GRANT ALL PRIVILEGES ON homelab.* TO '{{name}}'@'%';" \
        default_ttl=24h \
        max_ttl=720h

    # MySQL read-only role
    vault write database/roles/homelab-readonly \
        db_name=mysql \
        creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}'; GRANT SELECT ON *.* TO '{{name}}'@'%';" \
        default_ttl=24h \
        max_ttl=720h

    # Configure PostgreSQL
    vault write database/config/postgresql \
        plugin_name=postgresql-database-plugin \
        connection_url="postgresql://{{username}}:{{password}}@postgresql:5432/postgres?sslmode=disable" \
        allowed_roles="postgres-app,postgres-readonly" \
        username="postgres" \
        password="${POSTGRES_PASSWORD}"

    # PostgreSQL role for applications
    vault write database/roles/postgres-app \
        db_name=postgresql \
        creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' INHERIT; GRANT ALL PRIVILEGES ON DATABASE homelab TO \"{{name}}\";" \
        default_ttl=24h \
        max_ttl=720h

    success "Database secrets engine configured"
}

# Setup PKI for internal certificates
setup_pki() {
    log "Setting up PKI secrets engine..."

    # Configure root CA
    vault secrets tune -max-lease-ttl=87600h pki/homelab-pki
    vault write pki/homelab-pki/root/generate/internal \
        common_name="Homelab Root CA" \
        ttl=87600h

    # Configure intermediate CA
    vault write pki/homelab-pki/intermediate/generate/internal \
        common_name="Homelab Intermediate CA" \
        ttl=43800h

    # Sign intermediate certificate
    vault write pki/homelab-pki/root/sign-intermediate \
        csr=$(vault read -field=csr pki/homelab-pki/intermediate/generate/internal) \
        format=pem_bundle \
        ttl=43800h

    # Configure CRL and issuing URLs
    vault write pki/homelab-pki/intermediate/set-signed \
        certificate=$(vault read -field=certificate pki/homelab-pki/root/sign-intermediate)

    vault write pki/homelab-pki/roles/homelab-service \
        allowed_domains="homelab.local,localhost" \
        allow_subdomains=true \
        allow_glob_domains=true \
        max_ttl=720h

    success "PKI secrets engine configured"
}

# Setup audit logging
setup_audit() {
    log "Setting up audit logging..."

    # Enable file audit device
    vault audit enable file file_path=/vault/logs/audit.log

    success "Audit logging enabled"
}

# Create initial secrets for custom services
create_initial_secrets() {
    log "Creating initial secrets for custom services..."

    # Database connection strings (encrypted with transit)
    vault secrets enable transit

    # Create encryption key
    vault write -f transit/keys/homelab

    # Example: encrypt database connection
    local mysql_creds="mysql://user:password@mysql:3306/homelab"
    vault write transit/encrypt/homelab \
        plaintext=$(echo -n "$mysql_creds" | base64)

    # Store API keys for external services
    vault kv put secret/custom/api-keys \
        openweathermap="your-openweathermap-key" \
        github="your-github-token" \
        slack="your-slack-webhook"

    # Store application configuration
    vault kv put secret/custom/app-config \
        jwt_secret=$(openssl rand -hex 32) \
        encryption_key=$(openssl rand -hex 32) \
        api_key=$(openssl rand -hex 16)

    success "Initial secrets created"
}

# Setup backup
setup_backup() {
    log "Setting up backup configuration..."

    # Create backup script
    cat > /usr/local/bin/vault-backup.sh << 'EOF'
#!/bin/bash
# Vault Backup Script
BACKUP_DIR="/opt/homelab-backups/vault"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Backup Vault data
tar -czf "$BACKUP_DIR/vault-data-$DATE.tar.gz" /vault/data/

# Backup Vault configuration
cp -r /vault/config "$BACKUP_DIR/config-$DATE"

# Keep only last 7 days
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete
find "$BACKUP_DIR" -name "config-*" -mtime +7 -delete

echo "Vault backup completed: $DATE"
EOF

    chmod +x /usr/local/bin/vault-backup.sh

    # Add to crontab
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/vault-backup.sh") | crontab -

    success "Backup configuration completed"
}

# Main setup function
main() {
    echo "🔐 HashiCorp Vault Setup for Homelab"
    echo "====================================="
    echo

    # Check if Vault is running
    if ! curl -s -f "$VAULT_ADDR/v1/sys/health" > /dev/null; then
        error "Vault is not running. Please start the security stack first."
        echo "Run: cd docker-compose/security && docker-compose up -d"
        exit 1
    fi

    # Export VAULT_TOKEN and VAULT_ADDR
    export VAULT_TOKEN
    export VAULT_ADDR

    wait_for_vault

    # Check if we're in dev mode or production
    if vault status -format=json | jq -r '.server_version_utc_time' | grep -q "null"; then
        log "Detected production mode - initializing..."
        initialize_vault
        unseal_vault
    else
        success "Detected dev mode - skipping initialization"
    fi

    setup_auth_methods
    setup_policies
    setup_approles
    setup_database_secrets
    setup_pki
    setup_audit
    create_initial_secrets
    setup_backup

    echo
    success "🎉 Vault setup completed successfully!"
    echo
    echo "📋 Next Steps:"
    echo "1. Access Vault UI: $VAULT_ADDR"
    echo "2. Login with root token from /tmp/vault-root-token.txt"
    echo "3. Review AppRole credentials in /tmp/vault-approles.txt"
    echo "4. Configure your custom services to use Vault"
    echo
    echo "📚 Documentation:"
    echo "- Vault API: $VAULT_ADDR/v1/sys/internal/ui/dashboard"
    echo "- Policies: vault policy list"
    echo "- Auth methods: vault auth list"
    echo "- Secrets: vault secrets list"
    echo
}

# Check if required tools are installed
check_dependencies() {
    local deps=("vault" "curl" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "$dep is required but not installed. Please install it first."
            exit 1
        fi
    done
}

# Run checks
check_dependencies

# Execute main function
main "$@"