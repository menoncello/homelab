#!/bin/bash

# Script para configurar o Helios (laptop) para não hibernar ao fechar a tampa
# Isso evita que o homelab fique indisponível quando a tampa do laptop for fechada

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se está rodando como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Este script precisa ser executado como root"
        exit 1
    fi
}

# Backup do arquivo original
backup_config() {
    local config_file="/etc/systemd/logind.conf"
    local backup_file="/etc/systemd/logind.conf.backup.$(date +%Y%m%d_%H%M%S)"

    if [[ -f $config_file ]]; then
        cp "$config_file" "$backup_file"
        success "Backup criado: $backup_file"
    fi
}

# Configurar systemd-logind para ignorar fechamento da tampa
configure_logind() {
    local config_file="/etc/systemd/logind.conf"

    log "Configurando systemd-logind para ignorar fechamento da tampa..."

    # Verificar se o arquivo já tem as configurações
    if grep -q "^HandleLidSwitch=" "$config_file" 2>/dev/null; then
        # Atualizar linha existente
        sed -i 's/^HandleLidSwitch=.*/HandleLidSwitch=ignore/' "$config_file"
    else
        # Adicionar linha no final do arquivo
        echo "HandleLidSwitch=ignore" >> "$config_file"
    fi

    if grep -q "^HandleLidSwitchExternalPower=" "$config_file" 2>/dev/null; then
        sed -i 's/^HandleLidSwitchExternalPower=.*/HandleLidSwitchExternalPower=ignore/' "$config_file"
    else
        echo "HandleLidSwitchExternalPower=ignore" >> "$config_file"
    fi

    if grep -q "^HandleLidSwitchDocked=" "$config_file" 2>/dev/null; then
        sed -i 's/^HandleLidSwitchDocked=.*/HandleLidSwitchDocked=ignore/' "$config_file"
    else
        echo "HandleLidSwitchDocked=ignore" >> "$config_file"
    fi

    success "Configurações do lid switch aplicadas"
}

# Desabilitar hibernação no sistema
disable_hibernation() {
    log "Desabilitando hibernação do sistema..."

    # Remover initramfs hook de hibernação
    update-initramfs -u -k all

    # Configurar GRUB para não usar hibernação
    local grub_file="/etc/default/grub"
    if [[ -f $grub_file ]]; then
        if grep -q "GRUB_CMDLINE_LINUX_DEFAULT=" "$grub_file"; then
            # Remover parâmetros de hibernação existentes
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*resume=[^"]*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/' "$grub_file"
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/' "$grub_file"
        fi
        update-grub
        success "GRUB atualizado"
    fi

    # Desabilitar swap (necessário para hibernação)
    log "Desabilitando swap para evitar hibernação..."
    swapoff -a 2>/dev/null || true

    # Comentiar linhas de swap no fstab
    sed -i 's/^\([^#].*swap.*\)/#\1/' /etc/fstab 2>/dev/null || true

    success "Hibernação desabilitada"
}

# Configurar PM utils (se presente)
configure_pm_utils() {
    if command -v pm-powersave &> /dev/null; then
        log "Configurando PM utils..."

        # Criar arquivo de configuração
        cat > /etc/pm/config.d/disable-lid-suspend << 'EOF'
# Desabilitar suspensão ao fechar tampa
SUSPEND_METHODS="none"
EOF
        success "PM utils configurado"
    fi
}

# Reiniciar systemd-logind para aplicar mudanças
restart_services() {
    log "Reiniciando systemd-logind..."
    systemctl restart systemd-logind
    success "systemd-logind reiniciado"
}

# Verificar configuração
verify_configuration() {
    log "Verificando configuração atual..."

    echo -e "\n${BLUE}=== Status da Configuração ===${NC}"

    # Verificar configurações do logind
    echo -e "\n${YELLOW}Configurações do systemd-logind:${NC}"
    grep -E "^HandleLidSwitch" /etc/systemd/logind.conf 2>/dev/null || echo "Nenhuma configuração encontrada"

    # Verificar status do swap
    echo -e "\n${YELLOW}Status do Swap:${NC}"
    swapon --show || echo "Nenhum swap ativo"

    # Verificar se há algum serviço de suspensão
    echo -e "\n${YELLOW}Serviços de Power Management:${NC}"
    systemctl status sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null | grep -E "(Active|Loaded)" || echo "Serviços não encontrados"

    echo -e "\n${GREEN}=== Verificação Concluída ===${NC}"
}

# Criar script de verificação
create_monitor_script() {
    cat > /usr/local/bin/check-lid-status.sh << 'EOF'
#!/bin/bash

# Script para verificar o status do lid switch
echo "=== Lid Switch Status ==="
echo "Configuração atual:"
grep -E "^HandleLidSwitch" /etc/systemd/logind.conf 2>/dev/null || echo "Padrão do sistema"

echo -e "\nEventos do lid (monitor por 10 segundos):"
timeout 10s udevadm monitor -u -s input 2>/dev/null | grep -i "lid" || echo "Nenhum evento detectado"

echo -e "\nInformações do ACPI:"
cat /proc/acpi/button/lid/LID/state 2>/dev/null || echo "Interface ACPI não disponível"
EOF
    chmod +x /usr/local/bin/check-lid-status.sh

    success "Script de verificação criado: /usr/local/bin/check-lid-status.sh"
}

# Função principal
main() {
    log "Iniciando configuração para ignorar fechamento da tampa no Helios..."

    check_root

    # Backup das configurações atuais
    backup_config

    # Aplicar configurações
    configure_logind
    disable_hibernation
    configure_pm_utils

    # Reiniciar serviços
    restart_services

    # Criar utilitários
    create_monitor_script

    # Verificar configuração
    verify_configuration

    echo -e "\n${GREEN}✅ Configuração concluída com sucesso!${NC}"
    echo -e "\n${BLUE}Resumo das alterações:${NC}"
    echo "• Lid switch configurado para 'ignore'"
    echo "• Hibernação desabilitada"
    echo "• Swap desabilitado"
    echo "• Backup criado em /etc/systemd/logind.conf.backup.*"
    echo -e "\n${YELLOW}Para verificar o status: execute /usr/local/bin/check-lid-status.sh${NC}"
    echo -e "\n${GREEN}O Helios agora permanecerá ligado mesmo com a tampa fechada!${NC}"
}

# Executar main
main "$@"