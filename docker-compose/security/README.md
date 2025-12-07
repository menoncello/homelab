# 🛡️ Homelab Security Stack

## Dual-Tier Secrets Management Architecture

This stack provides enterprise-grade security for your homelab with two complementary solutions:

### 🔐 Tier 1: Vaultwarden (Password Manager)
- **Purpose**: Personal/team password management
- **Users**: 6 team members
- **Access**: Web interface, mobile apps, browser extensions
- **Storage**: Encrypted password vault

### 🏗️ Tier 2: HashiCorp Vault (Application Secrets)
- **Purpose**: Application secrets and infrastructure credentials
- **Users**: Services and applications
- **Access**: API, CLI, and programmatic integration
- **Features**: Dynamic secrets, auto-rotation, audit logs

---

## 🚀 Quick Start

### 1. Configure Environment
```bash
# Copy and edit environment file
cp .env.example .env
nano .env
```

### 2. Deploy Security Stack
```bash
# Start all security services
docker-compose up -d

# Or start with production features
docker-compose --profile production up -d
```

### 3. Setup Vault
```bash
# Run the setup script
./scripts/setup-vault.sh
```

---

## 🏗️ Architecture Overview

```
┌─────────────────┬─────────────────────┬─────────────────────┐
│                 │  VAULTWARDEN        │  HASHICORP VAULT   │
├─────────────────┼─────────────────────┼─────────────────────┤
│ Purpose         │ Password Manager    │ Secrets Manager    │
│ Users           │ 6 Team Members      │ Applications        │
│ Access          │ Web/Mobile/API      │ API/CLI            │
│ Storage         │ Encrypted Vault     │ Dynamic Secrets    │
│ Features        │ 2FA, Sharing        │ Auto-Rotation      │
│ Integration     │ Browser Extensions  │ Docker/Kubernetes  │
│ Backup          │ Automated           │ Manual/Automated   │
└─────────────────┴─────────────────────┴─────────────────────┘
```

---

## 🔐 HashiCorp Vault Configuration

### Authentication Methods
- **AppRole**: For your custom services
- **UserPass**: For admin access
- **Kubernetes**: For container orchestration (optional)
- **OIDC/LDAP**: For enterprise SSO (optional)

### Secret Engines
- **kv**: Static secrets storage
- **Database**: Dynamic database credentials
- **PKI**: Internal TLS certificates
- **Transit**: Encryption as a service

### Policies
- **admin**: Full administrative access
- **custom-services**: Access for your applications
- **readonly**: Read-only access for monitoring

---

## 🔧 Custom Services Integration

### 1. AppRole Authentication
```bash
# Your service authenticates using Role ID + Secret ID
VAULT_ROLE_ID="your-role-id"
VAULT_SECRET_ID="your-secret-id"

# Get temporary token
vault write auth/approle/login role_id="$VAULT_ROLE_ID" secret_id="$VAULT_SECRET_ID"
```

### 2. Database Credentials
```bash
# Get dynamic database credentials
vault read database/creds/homelab-app

# Returns temporary credentials that expire automatically
```

### 3. API Keys
```bash
# Retrieve encrypted API keys
vault kv get secret/custom/api-keys

# Or use transit encryption
vault write transit/encrypt/homelab plaintext=$(echo -n "sensitive-data" | base64)
```

### 4. TLS Certificates
```bash
# Generate internal certificate
vault write pki/homelab-pki/issue/homelab-service \
    common_name="my-service.homelab.local" \
    ttl=24h
```

---

## 📊 Monitoring & Logging

### Prometheus Metrics
- Vault Exporter: `http://localhost:9105/metrics`
- Metrics include: requests, latency, storage, authentication

### Audit Logging
- All access logged to `/vault/logs/audit.log`
- Includes: who accessed what, when, and result

### Health Checks
```bash
# Check Vault status
vault status

# Check authentication methods
vault auth list

# List available secrets
vault secrets list
```

---

## 🔒 Security Best Practices

### For Vaultwarden
1. **Enable 2FA** for all 6 users
2. **Strong master passwords** required
3. **Regular password audits**
4. **Emergency access** configured

### For HashiCorp Vault
1. **Regular key rotation** (weekly)
2. **Principle of least privilege** policies
3. **Audit log monitoring**
4. **Backup encryption**
5. **Network segmentation**

### Incident Response
```bash
# In case of security incident:
# 1. Revoke all active tokens
vault token revoke -mode path "auth/token/revoke-orphan"

# 2. Rotate root token
# 3. Review audit logs
# 4. Update AppRole credentials
# 5. Restore from backup if needed
```

---

## 💾 Backup & Recovery

### Automated Backup
```bash
# Daily backup script runs at 2 AM
# Stores in /opt/homelab-backups/vault/
# Retention: 7 days
```

### Manual Backup
```bash
# Export all secrets
vault kv list -format=json secret/ > secrets-backup.json

# Backup policies
vault policy list -format=json > policies-backup.json
```

### Disaster Recovery
```bash
# Restore from backup
# 1. Restore Vault data directory
# 2. Unseal Vault with recovery keys
# 3. Import policies
# 4. Recreate AppRoles
# 5. Update service credentials
```

---

## 🔗 Integration Examples

### Python Application
```python
import hvac
import os

# Connect to Vault
client = hvac.Client(url='http://vault:8200')

# Authenticate with AppRole
client.auth.approle.login(
    role_id=os.environ['VAULT_ROLE_ID'],
    secret_id=os.environ['VAULT_SECRET_ID']
)

# Get database credentials
db_creds = client.secrets.database.generate_credentials(
    name='homelab-app'
)

# Use credentials in your application
engine = create_engine(
    f"mysql://{db_creds['data']['username']}:{db_creds['data']['password']}@mysql:3306/homelab"
)
```

### Docker Service
```yaml
# In your docker-compose.yml
services:
  my-app:
    image: my-custom-app
    environment:
      VAULT_ADDR: http://vault:8200
      VAULT_ROLE_ID: ${VAULT_ROLE_ID}
      VAULT_SECRET_ID: ${VAULT_SECRET_ID}
    command: >
      sh -c "
        vault login -method=approle role_id=$$VAULT_ROLE_ID secret_id=$$VAULT_SECRET_ID &&
        export DB_PASSWORD=$$(vault read -field=password database/creds/homelab-app) &&
        python app.py
      "
```

---

## 📚 Additional Resources

### Documentation
- [Vault Documentation](https://www.vaultproject.io/docs)
- [Vaultwarden Documentation](https://github.com/dani-garcia/vaultwarden)
- [AppRole Authentication](https://www.vaultproject.io/docs/auth/approle)

### Security Checklists
- [Vault Security Checklist](https://www.vaultproject.io/docs/security)
- [Password Security Best Practices](https://bitwarden.com/help/personal-security/)

### Monitoring Dashboards
- Grafana dashboard for Vault metrics
- Alert rules for security events
- Log aggregation with Loki

---

## 🚨 Emergency Procedures

### Compromise Response
1. **Isolate**: Stop all services
2. **Assess**: Review audit logs
3. **Revoke**: Cancel all tokens
4. **Rotate**: Change all credentials
5. **Monitor**: Watch for suspicious activity

### Data Recovery
1. **Stop Vault service**
2. **Restore from backup**
3. **Unseal with recovery keys**
4. **Verify data integrity**
5. **Restart services**

---

**🎉 Your homelab now has enterprise-grade security with dual-tier secrets management!**