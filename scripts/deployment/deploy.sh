#!/bin/bash
# Homelab Deployment Script
# ==========================
# Deploys complete homelab infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."

    deps=("terraform" "docker" "docker-compose" "jq" "curl")
    for dep in "${deps[@]}"; do
        if ! command -v $dep &> /dev/null; then
            error "Missing dependency: $dep"
            exit 1
        fi
    done

    success "All dependencies found"
}

# Load environment variables
load_env() {
    log "Loading environment variables..."

    if [[ -f "../docker-compose/.env" ]]; then
        source ../docker-compose/.env
        success "Loaded Docker environment"
    else
        warning "Docker .env file not found, creating from example..."
        cp ../docker-compose/.env.example ../docker-compose/.env
        warning "Please edit ../docker-compose/.env with your actual values"
    fi

    if [[ -f "../terraform/terraform.tfvars" ]]; then
        success "Terraform variables found"
    else
        warning "Terraform tfvars not found, creating from example..."
        cp ../terraform/terraform.tfvars.example ../terraform/terraform.tfvars
        warning "Please edit ../terraform/terraform.tfvars with your actual values"
    fi
}

# Terraform deployment
deploy_infrastructure() {
    log "Deploying infrastructure with Terraform..."

    cd ../terraform

    # Initialize Terraform
    log "Initializing Terraform..."
    terraform init

    # Plan deployment
    log "Creating deployment plan..."
    terraform plan -out=homelab.plan

    # Ask for confirmation
    echo
    read -p "Do you want to apply this Terraform plan? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Applying Terraform plan..."
        terraform apply homelab.plan
        success "Infrastructure deployed successfully"
    else
        warning "Terraform apply cancelled"
        return 1
    fi

    # Save outputs
    terraform output -json > ../config/terraform-outputs.json
    success "Terraform outputs saved"

    cd - > /dev/null
}

# Deploy Docker services
deploy_docker_services() {
    log "Deploying Docker services..."

    # Array of service stacks in order
    stacks=(
        "databases"
        "nginx-proxy"
        "monitoring"
        "media"
        "books"
        "prod-services"
    )

    for stack in "${stacks[@]}"; do
        log "Deploying $stack stack..."

        cd "../docker-compose/$stack"

        # Create network if not exists
        docker network inspect homelab-network &>/dev/null || {
            log "Creating homelab-network..."
            docker network create --driver bridge homelab-network
        }

        # Deploy the stack
        docker-compose up -d

        # Wait a moment for services to start
        sleep 5

        # Check if services are running
        if docker-compose ps | grep -q "Up"; then
            success "$stack stack deployed successfully"
        else
            error "$stack stack deployment failed"
            docker-compose logs
            return 1
        fi

        cd - > /dev/null
    done

    # Deploy Cloudflare tunnel
    log "Deploying Cloudflare tunnel..."
    cd ../cloudflare-tunnel
    docker-compose up -d
    success "Cloudflare tunnel deployed"
    cd - > /dev/null
}

# Post-deployment checks
post_deployment_checks() {
    log "Running post-deployment checks..."

    # Check Terraform outputs
    if [[ -f "../config/terraform-outputs.json" ]]; then
        success "Terraform outputs available"

        # Display VM information
        log "VM Information:"
        jq -r '.all_vms.value | to_entries | .[] | "  \(.key): \(.value)"' ../config/terraform-outputs.json
    fi

    # Check Docker services
    log "Docker services status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

    # Check network connectivity
    log "Checking network connectivity..."

    # Check if Nginx Proxy Manager is accessible
    if curl -f http://localhost:81 &>/dev/null; then
        success "Nginx Proxy Manager accessible on port 81"
    else
        warning "Nginx Proxy Manager not accessible yet (may still be starting)"
    fi

    # Check if services are responding
    services=(
        "Grafana:192.168.31.201:3000"
        "Prometheus:192.168.31.201:9090"
        "Jellyfin:192.168.31.151:8096"
    )

    for service in "${services[@]}"; do
        name=$(echo $service | cut -d: -f1)
        endpoint=$(echo $service | cut -d: -f2)
        port=$(echo $service | cut -d: -f3)

        if timeout 5 bash -c "</dev/tcp/${endpoint}/${port}" 2>/dev/null; then
            success "$name is responding"
        else
            warning "$name is not responding yet (may still be starting)"
        fi
    done
}

# Show next steps
show_next_steps() {
    log "Deployment completed!"
    echo
    echo "🎯 Next Steps:"
    echo "1. Configure Nginx Proxy Manager:"
    echo "   - Visit: http://$(hostname -I | awk '{print $1}'):81"
    echo "   - Default credentials: admin@example.com / changeme"
    echo
    echo "2. Configure Grafana:"
    echo "   - Visit: http://192.168.31.201:3000"
    echo "   - Default credentials: admin / admin"
    echo
    echo "3. Access your services via Cloudflare Tunnel:"
    echo "   - Configure tunnel with provided config"
    echo
    echo "4. Run backup script:"
    echo "   ./backup/create-backup.sh"
    echo
    echo "📚 Documentation:"
    echo "   - docs/HOMELAB-STACK-PLAN.md - Full architecture"
    echo "   - docs/prerequisites.md - Prerequisites guide"
    echo
}

# Main deployment function
main() {
    echo "🚀 Homelab Deployment Script"
    echo "==========================="
    echo

    check_root
    check_dependencies

    # Confirm deployment
    echo "This will deploy:"
    echo "  • 7 VMs in Proxmox"
    echo "  • 46+ Docker services"
    echo "  • Monitoring and alerting"
    echo "  • Reverse proxy with SSL"
    echo "  • Cloudflare tunnel"
    echo
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Deployment cancelled"
        exit 0
    fi

    load_env

    # Deploy infrastructure
    if ! deploy_infrastructure; then
        error "Infrastructure deployment failed"
        exit 1
    fi

    # Deploy services
    if ! deploy_docker_services; then
        error "Docker services deployment failed"
        exit 1
    fi

    # Post-deployment checks
    post_deployment_checks

    # Show next steps
    show_next_steps

    success "Homelab deployment completed successfully! 🎉"
}

# Handle script arguments
case "${1:-}" in
    "infra")
        log "Infrastructure-only deployment mode"
        check_dependencies
        load_env
        deploy_infrastructure
        ;;
    "services")
        log "Docker services-only deployment mode"
        check_dependencies
        deploy_docker_services
        post_deployment_checks
        ;;
    "check")
        log "Post-deployment checks only"
        post_deployment_checks
        ;;
    "help"|"-h"|"--help")
        echo "Homelab Deployment Script"
        echo
        echo "Usage: $0 [command]"
        echo
        echo "Commands:"
        echo "  (no args)  Full deployment (infrastructure + services)"
        echo "  infra      Deploy infrastructure only"
        echo "  services   Deploy Docker services only"
        echo "  check      Run post-deployment checks"
        echo "  help       Show this help"
        exit 0
        ;;
    "")
        main
        ;;
    *)
        error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac