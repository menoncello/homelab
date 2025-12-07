# 🚨 Homelab Security Playbook
## Incident Response & Security Procedures for 6-User Environment

---

## 🎯 Security Overview

**Team Size**: 6 users
**Services**: 46+ applications + custom services
**Security Model**: Defense in depth with dual-tier secrets management

### Security Layers
1. **Network**: VLAN segmentation, firewall rules
2. **Authentication**: Vaultwarden + HashiCorp Vault
3. **Application**: Container isolation, least privilege
4. **Data**: Encryption at rest and transit
5. **Monitoring**: Real-time alerts and audit logs

---

## 🚨 Incident Response Levels

### 🔴 Level 1: Critical (Immediate Response)
**Time to Response**: < 15 minutes
**Examples**: Data breach, active attack, ransomware

### 🟡 Level 2: High (Response within 1 hour)
**Examples**: Suspicious activity, failed authentication spikes
### 🟢 Level 3: Medium (Response within 24 hours)
**Examples**: Security patch required, policy violation

---

## 📋 Pre-Incident Preparation

### Security Team (6 Users)
```
🔰 Security Lead: Responsible for coordination
🛡️ Infrastructure Owner: Manages Proxmox/Vault
📊 Monitoring Lead: Watches alerts and dashboards
🔍 Investigator: Analyzes logs and evidence
🔧 Recovery Lead: Manages restoration process
📝 Documentation: Records all incidents
```

### Contact Information
```bash
# Emergency contacts stored securely in Vaultwarden
# Backup communication channels (Slack, Discord, SMS)
# Escalation procedures
```

### Tools & Access
```bash
# Critical URLs
- Proxmox: https://proxmox:8006
- Grafana: http://192.168.31.201:3000
- Vault: http://vault:8200
- Vaultwarden: https://vaultwarden.domain.com

# Emergency scripts
/home/user/homelab/scripts/emergency/
  - isolate-service.sh
  - backup-critical-data.sh
  - revoke-access.sh
```

---

## 🚨 Incident Response Procedures

### Phase 1: Detection & Assessment (0-15 minutes)

#### 1.1 Identify Incident
```bash
# Automated alerts trigger:
- Failed authentication spikes (>10/min)
- Unusual network traffic
- Service unavailable
- Anomaly detection alerts

# Manual detection:
- User reports
- Log review
- Monitoring dashboards
```

#### 1.2 Triage Severity
```bash
# Critical if:
- Data exfiltration confirmed
- Production services down
- Security controls bypassed
- Ransomware detected

# High if:
- Suspicious activity patterns
- Multiple failed logins
- Unusual access times
- Configuration changes
```

#### 1.3 Initial Documentation
```bash
# Create incident log:
echo "INCIDENT-$(date +%Y%m%d-%H%M%S)" > /var/log/homelab-incident.log
echo "Severity: CRITICAL" >> /var/log/homelab-incident.log
echo "Time Detected: $(date)" >> /var/log/homelab-incident.log
echo "Initial Reporter: $USER" >> /var/log/homelab-incident.log
```

### Phase 2: Immediate Containment (15-60 minutes)

#### 2.1 Network Isolation
```bash
# Isolate affected VMs
pvesh set /nodes/pve/qemu/VMID/net0 --firewall 1
pvesh set /nodes/pve/qemu/VMID/firewall/options --input DROP
pvesh set /nodes/pve/qemu/VMID/firewall/options --output DROP

# Block suspicious IPs
iptables -A INPUT -s SUSPICIOUS_IP -j DROP

# Enable emergency firewall rules
./scripts/emergency/lockdown-network.sh
```

#### 2.2 Service Containment
```bash
# Stop affected services
docker-compose down --remove-orphans

# Pause non-critical services
docker-compose stop $(docker-compose ps --services | grep -v "critical")

# Enable read-only mode
docker run --rm -v $(pwd):/data alpine sh -c "chmod -w /data/*/config"
```

#### 2.3 Access Revocation
```bash
# Revoke Vault tokens
vault token revoke -mode path "auth/token/revoke-orphan"

# Rotate all AppRole secrets
vault write -f auth/approle/role/web-app/secret-id

# Disable user accounts
pveum user modify username@pve --enable 0
```

### Phase 3: Investigation (1-6 hours)

#### 3.1 Evidence Collection
```bash
# Create evidence directory
mkdir -p /tmp/evidence/$(date +%Y%m%d)
cd /tmp/evidence/$(date +%Y%m%d)

# Collect logs
pvesh get /nodes/pve/syslog > pve-syslog.log
docker logs --timestamps > docker-all-logs.log
vault audit list -format=json > vault-audit.log

# Collect system state
ps aux > process-list.txt
netstat -tulnp > network-connections.txt
df -h > disk-usage.txt

# Memory dump (if critical)
dd if=/dev/mem of=memory.dump bs=1M count=1000
```

#### 3.2 Timeline Reconstruction
```bash
# Build incident timeline
grep "$(date -d '6 hours ago' '+%b %d %H')" /var/log/auth.log > auth-timeline.log
grep "$(date -d '6 hours ago' '+%Y-%m-%dT')" /var/log/nginx/access.log > nginx-timeline.log

# Vault audit analysis
grep "response.error" /vault/logs/audit.log > vault-errors.log
```

#### 3.3 Malware Analysis
```bash
# Scan for malware
clamscan -r / --log=clamscan.log --infected

# Check for rootkits
chkrootkit > chkrootkit.log
rkhunter -c --rwo --sk > rkhunter.log

# File integrity check
find / -type f -mtime -1 -exec md5sum {} \; > recent-files.md5
```

### Phase 4: Eradication (6-12 hours)

#### 4.1 Remove Malicious Code
```bash
# Remove infected containers
docker rmi $(docker images --format "{{.Repository}}:{{.Tag}}" | grep suspicious)

# Clean compromised files
find /tmp -name "*.tmp" -delete
find /var/tmp -name "*.tmp" -delete

# Rebuild affected services
docker-compose build --no-cache
docker-compose up -d
```

#### 4.2 Patch Vulnerabilities
```bash
# Update all packages
apt-get update && apt-get upgrade -y

# Update Docker images
docker-compose pull

# Restart services with updated images
docker-compose up -d --force-recreate
```

#### 4.3 Password Rotation
```bash
# Rotate all database passwords
vault write database/roles/homelab-app rotate-root-credentials

# Rotate service account passwords
pveum user modify service-account@pve --password $(openssl rand -base64 32)

# Update Vaultwarden master passwords
./scripts/security/rotate-vaultwarden-passwords.sh
```

### Phase 5: Recovery (12-24 hours)

#### 5.1 Restore from Backup
```bash
# Verify backup integrity
./scripts/backup/verify-backup.sh homelab-backup-$(date +%Y%m%d)

# Restore from clean backup
./scripts/backup/restore.sh homelab-backup-$(date +%Y%m%d) --configs

# Validate restored data
docker-compose ps
./scripts/health-check.sh
```

#### 5.2 Gradual Service Restoration
```bash
# Start critical services first
docker-compose up -d databases monitoring

# Wait for health checks
sleep 300

# Start application services
docker-compose up -d prod-services media books

# Monitor for anomalies
./scripts/monitoring/real-time-monitor.sh
```

#### 5.3 Post-Recovery Validation
```bash
# Run comprehensive health check
./scripts/security/full-security-scan.sh

# Validate all services are responding
for service in $(docker-compose ps --services); do
    curl -f http://localhost/health || echo "$service is not responding"
done
```

### Phase 6: Post-Incident Activities

#### 6.1 Security Audit
```bash
# Review all access logs for the past 30 days
grep "$(date -d '30 days ago' '+%Y-%m-%d')" /vault/logs/audit.log

# Update security policies
vault policy write homelab-app policies/homelab-app-updated.hcl

# Review and update firewall rules
iptables -L -n > current-firewall.rules
```

#### 6.2 Documentation
```bash
# Complete incident report
cat > /var/log/incident-report.md << EOF
# Incident Report: $(date +%Y-%m-%d)

## Summary
[Brief description of incident]

## Timeline
[Detailed timeline of events]

## Impact Assessment
[What was affected]

## Root Cause Analysis
[Why it happened]

## Lessons Learned
[What we can improve]

## Prevention Measures
[How to prevent recurrence]
EOF
```

#### 6.3 Security Improvements
```bash
# Implement additional monitoring
./scripts/monitoring/deploy-enhanced-monitoring.sh

# Update incident response playbooks
cp SECURITY-PLAYBOOK.md SECURITY-PLAYBOOK-v2.md

# Schedule security training for all 6 users
./scripts/security/schedule-training.sh
```

---

## 🛡️ Proactive Security Measures

### Daily Security Tasks
```bash
# Automated daily checks
0 8 * * * /home/user/homelab/scripts/security/daily-scan.sh
0 9 * * * /home/user/homelab/scripts/backup/daily-backup.sh
0 10 * * * /home/user/homelab/scripts/monitoring/health-check.sh
```

### Weekly Security Tasks
```bash
# Monday: Security updates
0 6 * * 1 /home/user/homelab/scripts/security/weekly-updates.sh

# Wednesday: Audit log review
0 6 * * 3 /home/user/homelab/scripts/security/audit-review.sh

# Friday: Security report
0 6 * * 5 /home/user/homelab/scripts/security/weekly-report.sh
```

### Monthly Security Tasks
```bash
# Full security assessment
0 6 1 * * /home/user/homelab/scripts/security/full-assessment.sh

# Password rotation
0 6 15 * * /home/user/homelab/scripts/security/password-rotation.sh

# Security training review
0 6 20 * * /home/user/homelab/scripts/security/training-review.sh
```

---

## 🚨 Emergency Contacts & Escalation

### Internal Team (6 Users)
1. **Security Lead**: +55-XX-XXXX-XXXX (24/7)
2. **Infrastructure Owner**: +55-XX-XXXX-XXXX
3. **Monitoring Lead**: +55-XX-XXXX-XXXX
4. **Investigator**: +55-XX-XXXX-XXXX
5. **Recovery Lead**: +55-XX-XXXX-XXXX
6. **Documentation**: +55-XX-XXXX-XXXX

### External Support
- **Cloudflare**: DDoS protection support
- **Internet Provider**: Abuse contact
- **Legal Counsel**: Data breach notification
- **Insurance Provider**: Cyber insurance claim

### Regulatory Requirements
- **LGPD Notification**: 72 hours for data breaches
- **Documentation**: Maintain records for 2 years
- **User Notification**: Clear communication plan

---

## 📚 Security Training for 6 Users

### Mandatory Training Topics
1. **Password Security**: Vaultwarden usage, 2FA
2. **Phishing Awareness**: Email safety, verification
3. **Device Security**: Antivirus, updates, encryption
4. **Incident Reporting**: How and when to report
5. **Data Handling**: Classification and protection

### Training Schedule
```bash
# New user onboarding (mandatory)
./scripts/security/onboarding.sh [username]

# Quarterly refresher training
0 14 1 */3 * /home/user/homelab/scripts/security/quarterly-training.sh

# Annual security assessment
0 14 1 1 * /home/user/homelab/scripts/security/annual-assessment.sh
```

---

## 🎯 Success Metrics

### Security KPIs
- **Mean Time to Detect (MTTD)**: < 15 minutes
- **Mean Time to Respond (MTTR)**: < 1 hour
- **Security Incidents**: < 2 per quarter
- **False Positives**: < 10% of alerts
- **Patch Compliance**: > 95%

### User Security Score
Each of the 6 users gets a security score:
- **Strong Passwords**: 20 points
- **2FA Enabled**: 20 points
- **Training Completed**: 20 points
- **No Security Violations**: 20 points
- **Regular Updates**: 20 points

---

**🛡️ Your homelab now has enterprise-grade security with comprehensive incident response capabilities!**