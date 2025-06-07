#!/bin/bash

# Hybrid Deployment Script - VM + Kubernetes Support
# OpenStack DevOps Suite with GitLab-Centered Architecture
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

log_info() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  $1${NC}"
}

# Banner
show_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║                    OpenStack DevOps Suite Deployment                    ║"
    echo "║                   GitLab-Centered Hybrid Architecture                   ║"
    echo "║                          VM + Kubernetes Support                        ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check deployment configuration
check_deployment_type() {
    log "🔍 Checking deployment configuration..."
    
    # Set defaults if not provided
    ENABLE_VMS=${ENABLE_VMS:-true}
    ENABLE_KUBERNETES=${ENABLE_KUBERNETES:-false}
    
    log_info "VM Deployment: ${ENABLE_VMS}"
    log_info "Kubernetes Deployment: ${ENABLE_KUBERNETES}"
    
    if [[ "$ENABLE_VMS" == "false" && "$ENABLE_KUBERNETES" == "false" ]]; then
        log_error "At least one deployment method must be enabled"
        exit 1
    fi
    
    if [[ "$ENABLE_KUBERNETES" == "true" ]]; then
        check_kubernetes_tools
    fi
    
    if [[ "$ENABLE_VMS" == "true" ]]; then
        check_openstack_tools
    fi
}

# Check Kubernetes tools and connectivity
check_kubernetes_tools() {
    log "🔧 Checking Kubernetes tools..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is required for Kubernetes deployment"
        log_info "Install kubectl: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        log_error "Helm is required for Kubernetes deployment"
        log_info "Install Helm: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    
    # Test kubectl connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        log_info "Check your kubeconfig and cluster connectivity"
        exit 1
    fi
    
    # Get cluster info
    CLUSTER_VERSION=$(kubectl version --client --output=yaml | grep gitVersion | cut -d'"' -f4)
    CLUSTER_NAME=$(kubectl config current-context)
    
    log_success "Kubernetes tools available"
    log_info "kubectl version: $CLUSTER_VERSION"
    log_info "Current context: $CLUSTER_NAME"
}

# Check OpenStack tools and credentials
check_openstack_tools() {
    log "☁️  Checking OpenStack tools..."
    
    # Check required environment variables
    if [[ -z "$OS_AUTH_URL" ]]; then
        log_error "OpenStack credentials not configured"
        log_info "Set environment variables: OS_AUTH_URL, OS_USERNAME, OS_PASSWORD, etc."
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is required for infrastructure deployment"
        exit 1
    fi
    
    # Check Ansible
    if ! command -v ansible &> /dev/null; then
        log_error "Ansible is required for service configuration"
        exit 1
    fi
    
    log_success "OpenStack tools available"
    log_info "OpenStack endpoint: $OS_AUTH_URL"
    log_info "Project: ${OS_PROJECT_NAME:-$OS_TENANT_NAME}"
}

# Deploy infrastructure using Terraform
deploy_infrastructure() {
    if [[ "$ENABLE_VMS" != "true" ]]; then
        log_info "Skipping VM infrastructure deployment"
        return
    fi
    
    log "🏗️  Deploying OpenStack infrastructure..."
    
    cd "$PROJECT_ROOT/terraform"
    
    # Initialize Terraform
    log "Initializing Terraform..."
    terraform init
    
    # Create terraform.tfvars if it doesn't exist
    if [[ ! -f terraform.tfvars ]]; then
        if [[ -f terraform.tfvars.example ]]; then
            cp terraform.tfvars.example terraform.tfvars
            log_warning "Created terraform.tfvars from example. Please configure it."
            log_info "Edit terraform.tfvars with your OpenStack and deployment settings"
            return 1
        else
            log_error "terraform.tfvars.example not found"
            return 1
        fi
    fi
    
    # Validate configuration
    log "Validating Terraform configuration..."
    terraform validate
    
    # Plan deployment
    log "Planning infrastructure deployment..."
    terraform plan -out=tfplan
    
    # Ask for confirmation unless auto-approved
    if [[ "${AUTO_APPROVE:-false}" != "true" ]]; then
        echo ""
        read -p "Do you want to apply these changes? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deployment cancelled by user"
            return 1
        fi
    fi
    
    # Apply infrastructure
    log "Applying infrastructure changes..."
    terraform apply tfplan
    
    log_success "Infrastructure deployed successfully"
    
    # Generate inventory for Ansible
    if [[ -f templates/inventory.yml.tpl ]]; then
        log "Generating Ansible inventory from Terraform state..."
        terraform output -json > terraform-outputs.json
    fi
}

# Deploy Kubernetes resources
deploy_kubernetes_resources() {
    if [[ "$ENABLE_KUBERNETES" != "true" ]]; then
        log_info "Skipping Kubernetes deployment"
        return
    fi
    
    log "☸️  Deploying Kubernetes resources..."
    
    cd "$PROJECT_ROOT"
    
    # Apply namespace first
    log "Creating namespace..."
    kubectl apply -f k8s/namespace.yaml
    
    # Wait for namespace to be ready
    kubectl wait --for=condition=Ready namespace/devops-suite --timeout=30s || true
    
    # Apply services
    log "Creating services..."
    kubectl apply -f k8s/services.yaml
    
    # Install NGINX Ingress Controller if not present
    if ! kubectl get ingressclass nginx &> /dev/null; then
        log "Installing NGINX Ingress Controller..."
        helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
        helm repo update
        
        helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
            --namespace ingress-nginx \
            --create-namespace \
            --set controller.service.type=LoadBalancer \
            --set controller.service.annotations."service\.beta\.kubernetes\.io/openstack-internal-load-balancer"="true" \
            --set controller.config.proxy-body-size="500m" \
            --wait --timeout=300s
    fi
    
    # Install cert-manager if SSL is enabled
    if [[ "${ENABLE_SSL:-true}" == "true" && ! -z "${LETSENCRYPT_EMAIL:-}" ]]; then
        if ! kubectl get crd certificates.cert-manager.io &> /dev/null; then
            log "Installing cert-manager..."
            helm repo add jetstack https://charts.jetstack.io
            helm repo update
            
            helm upgrade --install cert-manager jetstack/cert-manager \
                --namespace cert-manager \
                --create-namespace \
                --set installCRDs=true \
                --wait --timeout=300s
        fi
        
        # Apply certificates
        log "Creating SSL certificates..."
        kubectl apply -f k8s/certificates.yaml
    fi
    
    # Apply ingress
    log "Creating ingress resources..."
    kubectl apply -f k8s/ingress.yaml
    
    # Wait for ingress controller to be ready
    log "Waiting for ingress controller to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
    
    log_success "Kubernetes resources deployed successfully"
}

# Configure VM services using Ansible
configure_services() {
    if [[ "$ENABLE_VMS" != "true" ]]; then
        log_info "Skipping VM service configuration"
        return
    fi
    
    log "⚙️  Configuring VM services with Ansible..."
    
    cd "$PROJECT_ROOT"
    
    # Check if inventory exists
    if [[ ! -f inventory/openstack-hosts.yml ]]; then
        log_error "Ansible inventory not found at inventory/openstack-hosts.yml"
        return 1
    fi
    
    # Test connectivity
    log "Testing Ansible connectivity..."
    if ! ansible all -m ping -i inventory/openstack-hosts.yml &> /dev/null; then
        log_warning "Some hosts may not be reachable yet. Waiting 30 seconds..."
        sleep 30
    fi
    
    # Run playbooks
    log "Running Ansible playbooks..."
    ansible-playbook -i inventory/openstack-hosts.yml playbooks/site.yml
    
    log_success "VM services configured successfully"
}

# Show access information for deployed services
show_access_info() {
    log "📋 Deployment completed! Access information:"
    echo ""
    
    if [[ "$ENABLE_VMS" == "true" ]]; then
        echo -e "${CYAN}VM-based services (via NGINX Proxy):${NC}"
        cd "$PROJECT_ROOT/terraform"
        
        if [[ -f terraform.tfstate ]]; then
            GITLAB_IP=$(terraform output -raw gitlab_floating_ip 2>/dev/null || echo "N/A")
            NGINX_IP=$(terraform output -raw nginx_floating_ip 2>/dev/null || echo "N/A")
            NEXUS_IP=$(terraform output -raw nexus_floating_ip 2>/dev/null || echo "N/A")
            KEYCLOAK_IP=$(terraform output -raw keycloak_floating_ip 2>/dev/null || echo "N/A")
            RANCHER_IP=$(terraform output -raw rancher_floating_ip 2>/dev/null || echo "N/A")
            
            echo "  GitLab (Primary):  http://$GITLAB_IP"
            echo "  Dashboard:         http://$NGINX_IP"
            echo "  Nexus Repository:  http://$NEXUS_IP"
            echo "  Keycloak IAM:      http://$KEYCLOAK_IP"
            echo "  Rancher K8s:       http://$RANCHER_IP"
        else
            echo "  Run 'terraform output' in terraform/ directory for IP addresses"
        fi
        echo ""
    fi
    
    if [[ "$ENABLE_KUBERNETES" == "true" ]]; then
        echo -e "${CYAN}Kubernetes-based services (via Ingress):${NC}"
        DOMAIN=${DOMAIN_NAME:-"yourdomain.com"}
        
        echo "  GitLab (Primary):   https://gitlab.$DOMAIN"
        echo "  Dashboard:          https://dashboard.$DOMAIN"
        echo "  Nexus Repository:   https://nexus.$DOMAIN"
        echo "  Docker Registry:    https://docker.$DOMAIN"
        echo "  Keycloak IAM:       https://keycloak.$DOMAIN"
        echo "  Rancher K8s:        https://rancher.$DOMAIN"
        echo ""
        
        # Show ingress IP
        INGRESS_IP=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
        echo "  Ingress Load Balancer IP: $INGRESS_IP"
        echo ""
        
        if [[ "$INGRESS_IP" != "Pending" && "$INGRESS_IP" != "" ]]; then
            echo -e "${YELLOW}DNS Configuration Required:${NC}"
            echo "  Add these DNS records to your domain:"
            echo "    gitlab.$DOMAIN     A    $INGRESS_IP"
            echo "    rancher.$DOMAIN    A    $INGRESS_IP"
            echo "    keycloak.$DOMAIN   A    $INGRESS_IP"
            echo "    nexus.$DOMAIN      A    $INGRESS_IP"
            echo "    docker.$DOMAIN     A    $INGRESS_IP"
            echo "    dashboard.$DOMAIN  A    $INGRESS_IP"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}🎉 Deployment Summary:${NC}"
    echo "  ✅ VM Deployment: $ENABLE_VMS"
    echo "  ✅ Kubernetes Deployment: $ENABLE_KUBERNETES"
    echo "  ✅ SSL Certificates: ${ENABLE_SSL:-true}"
    echo "  ✅ Environment: ${ENVIRONMENT_NAME:-production}"
}

# Cleanup function
cleanup() {
    log "🧹 Cleaning up temporary files..."
    cd "$PROJECT_ROOT/terraform"
    rm -f tfplan terraform-outputs.json
}

# Error handling
handle_error() {
    log_error "Deployment failed at line $1"
    cleanup
    exit 1
}

trap 'handle_error $LINENO' ERR

# Main deployment function
main() {
    show_banner
    
    case "${1:-deploy}" in
        "deploy")
            check_deployment_type
            deploy_infrastructure
            deploy_kubernetes_resources
            configure_services
            show_access_info
            ;;
        "k8s-only")
            ENABLE_VMS=false
            ENABLE_KUBERNETES=true
            check_deployment_type
            deploy_kubernetes_resources
            show_access_info
            ;;
        "vm-only")
            ENABLE_VMS=true
            ENABLE_KUBERNETES=false
            check_deployment_type
            deploy_infrastructure
            configure_services
            show_access_info
            ;;
        "destroy")
            log_warning "Destroying infrastructure..."
            if [[ "$ENABLE_KUBERNETES" == "true" ]]; then
                kubectl delete -f k8s/ --ignore-not-found=true
            fi
            if [[ "$ENABLE_VMS" == "true" ]]; then
                cd "$PROJECT_ROOT/terraform"
                terraform destroy
            fi
            log_success "Infrastructure destroyed"
            ;;
        "status")
            log "📊 Checking deployment status..."
            if [[ "$ENABLE_VMS" == "true" ]]; then
                cd "$PROJECT_ROOT/terraform"
                terraform show | head -20
            fi
            if [[ "$ENABLE_KUBERNETES" == "true" ]]; then
                kubectl get all -n devops-suite
            fi
            ;;
        *)
            echo "Usage: $0 [deploy|k8s-only|vm-only|destroy|status]"
            echo ""
            echo "Commands:"
            echo "  deploy     - Deploy both VMs and Kubernetes (hybrid)"
            echo "  k8s-only   - Deploy only to Kubernetes"
            echo "  vm-only    - Deploy only VMs"
            echo "  destroy    - Destroy all infrastructure"
            echo "  status     - Show deployment status"
            echo ""
            echo "Environment Variables:"
            echo "  ENABLE_VMS=true|false         - Enable VM deployment (default: true)"
            echo "  ENABLE_KUBERNETES=true|false  - Enable Kubernetes deployment (default: false)"
            echo "  ENABLE_SSL=true|false         - Enable SSL certificates (default: true)"
            echo "  AUTO_APPROVE=true|false       - Auto-approve Terraform changes (default: false)"
            echo "  DOMAIN_NAME=yourdomain.com    - Domain for Kubernetes services"
            echo "  LETSENCRYPT_EMAIL=email       - Email for SSL certificates"
            exit 1
            ;;
    esac
    
    cleanup
    log_success "🎉 Deployment completed successfully!"
}

# Run main function with all arguments
main "$@"
