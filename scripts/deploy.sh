#!/bin/bash

# DevOps Suite Deployment Script
# This script orchestrates Terraform infrastructure provisioning and Ansible configuration

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
ANSIBLE_DIR="$PROJECT_ROOT"
INVENTORY_FILE="$PROJECT_ROOT/inventory/terraform-hosts.yml"
LOG_FILE="$PROJECT_ROOT/deployment.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install Terraform 1.0 or higher."
        exit 1
    fi
    
    # Check Ansible
    if ! command -v ansible &> /dev/null; then
        log_error "Ansible is not installed. Please install Ansible 6.x or higher."
        exit 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install jq for JSON processing."
        exit 1
    fi
    
    # Check OpenStack environment variables
    if [[ -z "$OS_AUTH_URL" || -z "$OS_USERNAME" || -z "$OS_PASSWORD" ]]; then
        log_error "OpenStack environment variables are not set. Please source your OpenStack RC file."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Initialize Terraform
init_terraform() {
    log "Initializing Terraform..."
    cd "$TERRAFORM_DIR"
    
    terraform init
    terraform fmt
    terraform validate
    
    log_success "Terraform initialized successfully"
}

# Plan infrastructure
plan_infrastructure() {
    log "Planning infrastructure changes..."
    cd "$TERRAFORM_DIR"
    
    # Create terraform.tfvars if it doesn't exist
    if [[ ! -f "terraform.tfvars" ]]; then
        log "Creating terraform.tfvars from example..."
        cp terraform.tfvars.example terraform.tfvars
        
        # Replace environment variables
        sed -i.bak "s/\${OS_AUTH_URL}/$OS_AUTH_URL/g" terraform.tfvars
        sed -i.bak "s/\${OS_USERNAME}/$OS_USERNAME/g" terraform.tfvars
        sed -i.bak "s/\${OS_PASSWORD}/$OS_PASSWORD/g" terraform.tfvars
        sed -i.bak "s/\${OS_PROJECT_NAME}/${OS_PROJECT_NAME:-admin}/g" terraform.tfvars
        sed -i.bak "s/\${OS_USER_DOMAIN_NAME}/${OS_USER_DOMAIN_NAME:-Default}/g" terraform.tfvars
        sed -i.bak "s/\${OS_PROJECT_DOMAIN_NAME}/${OS_PROJECT_DOMAIN_NAME:-Default}/g" terraform.tfvars
        
        rm terraform.tfvars.bak
        log_warning "Please review and update terraform.tfvars with your specific settings"
    fi
    
    terraform plan -var-file="terraform.tfvars" -out=plan.cache
    log_success "Infrastructure plan created successfully"
}

# Apply infrastructure
apply_infrastructure() {
    log "Applying infrastructure changes..."
    cd "$TERRAFORM_DIR"
    
    terraform apply -auto-approve plan.cache
    
    # Generate outputs
    terraform output -json > ../terraform-outputs.json
    
    log_success "Infrastructure applied successfully"
}

# Generate Ansible inventory
generate_inventory() {
    log "Generating Ansible inventory from Terraform outputs..."
    
    # Extract the inventory from Terraform outputs
    jq -r '.ansible_inventory.value' "$PROJECT_ROOT/terraform-outputs.json" > "$INVENTORY_FILE"
    
    log_success "Ansible inventory generated at $INVENTORY_FILE"
}

# Wait for instances to be ready
wait_for_instances() {
    log "Waiting for instances to be ready..."
    cd "$ANSIBLE_DIR"
    
    # Wait for SSH connectivity
    ansible all -i "$INVENTORY_FILE" -m wait_for_connection \
        -a "connect_timeout=20 sleep=5 delay=5 timeout=300" \
        --timeout=600 || true
    
    # Gather facts to verify connectivity
    ansible all -i "$INVENTORY_FILE" -m setup -a "gather_subset=min" --one-line
    
    log_success "All instances are ready"
}

# Configure baseline settings
configure_baseline() {
    log "Configuring baseline settings..."
    cd "$ANSIBLE_DIR"
    
    ansible-playbook -i "$INVENTORY_FILE" playbooks/site.yml --tags baseline
    
    log_success "Baseline configuration complete"
}

# Deploy services
deploy_services() {
    log "Deploying services..."
    cd "$ANSIBLE_DIR"
    
    # Deploy GitLab first
    log "Deploying GitLab..."
    ansible-playbook -i "$INVENTORY_FILE" playbooks/gitlab.yml \
        --extra-vars "gitlab_root_password=${GITLAB_ROOT_PASSWORD:-ChangeMe123!}"
    
    # Deploy Jenkins
    log "Deploying Jenkins..."
    ansible-playbook -i "$INVENTORY_FILE" playbooks/jenkins.yml
    
    # Deploy other services
    log "Deploying remaining services..."
    for service in nexus keycloak rancher kafka redis; do
        log "Deploying $service..."
        ansible-playbook -i "$INVENTORY_FILE" "playbooks/$service.yml"
    done
    
    # Deploy NGINX proxy and dashboard
    log "Deploying NGINX proxy and dashboard..."
    ansible-playbook -i "$INVENTORY_FILE" playbooks/dashboard.yml
    
    log_success "All services deployed successfully"
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    # Extract service IPs
    NGINX_IP=$(jq -r '.nginx_ip.value' "$PROJECT_ROOT/terraform-outputs.json")
    GITLAB_IP=$(jq -r '.gitlab_ip.value' "$PROJECT_ROOT/terraform-outputs.json")
    JENKINS_IP=$(jq -r '.jenkins_ip.value' "$PROJECT_ROOT/terraform-outputs.json")
    
    # Check services
    log "Checking service availability..."
    
    if curl -f -s "http://$NGINX_IP" > /dev/null; then
        log_success "Dashboard is accessible at http://$NGINX_IP"
    else
        log_warning "Dashboard may not be ready yet"
    fi
    
    if curl -f -s "http://$GITLAB_IP:8090" > /dev/null; then
        log_success "GitLab is accessible at http://$GITLAB_IP:8090"
    else
        log_warning "GitLab may not be ready yet"
    fi
    
    if curl -f -s "http://$JENKINS_IP:8080" > /dev/null; then
        log_success "Jenkins is accessible at http://$JENKINS_IP:8080"
    else
        log_warning "Jenkins may not be ready yet"
    fi
}

# Print deployment summary
print_summary() {
    log "Deployment Summary"
    echo "===========================================" | tee -a "$LOG_FILE"
    
    # Service URLs
    NGINX_IP=$(jq -r '.nginx_ip.value' "$PROJECT_ROOT/terraform-outputs.json")
    GITLAB_IP=$(jq -r '.gitlab_ip.value' "$PROJECT_ROOT/terraform-outputs.json")
    JENKINS_IP=$(jq -r '.jenkins_ip.value' "$PROJECT_ROOT/terraform-outputs.json")
    NEXUS_IP=$(jq -r '.nexus_ip.value' "$PROJECT_ROOT/terraform-outputs.json")
    KEYCLOAK_IP=$(jq -r '.keycloak_ip.value' "$PROJECT_ROOT/terraform-outputs.json")
    RANCHER_IP=$(jq -r '.rancher_ip.value' "$PROJECT_ROOT/terraform-outputs.json")
    
    echo "🌐 Dashboard: http://$NGINX_IP" | tee -a "$LOG_FILE"
    echo "🦊 GitLab: http://$GITLAB_IP:8090" | tee -a "$LOG_FILE"
    echo "   - Username: root" | tee -a "$LOG_FILE"
    echo "   - Password: ${GITLAB_ROOT_PASSWORD:-ChangeMe123!}" | tee -a "$LOG_FILE"
    echo "   - Registry: http://$GITLAB_IP:5050" | tee -a "$LOG_FILE"
    echo "🔧 Jenkins: http://$JENKINS_IP:8080" | tee -a "$LOG_FILE"
    echo "📦 Nexus: http://$NEXUS_IP:8081" | tee -a "$LOG_FILE"
    echo "🔐 Keycloak: http://$KEYCLOAK_IP:8180" | tee -a "$LOG_FILE"
    echo "☸️  Rancher: http://$RANCHER_IP:8443" | tee -a "$LOG_FILE"
    echo "===========================================" | tee -a "$LOG_FILE"
    
    log_success "DevOps Suite deployment completed successfully!"
}

# Cleanup function
cleanup_infrastructure() {
    log "Cleaning up infrastructure..."
    cd "$TERRAFORM_DIR"
    
    terraform destroy -auto-approve -var-file="terraform.tfvars"
    
    log_success "Infrastructure cleanup completed"
}

# Main execution
main() {
    case "${1:-deploy}" in
        "deploy")
            log "Starting DevOps Suite deployment..."
            check_prerequisites
            init_terraform
            plan_infrastructure
            apply_infrastructure
            generate_inventory
            wait_for_instances
            configure_baseline
            deploy_services
            verify_deployment
            print_summary
            ;;
        "destroy")
            log "Starting DevOps Suite cleanup..."
            check_prerequisites
            cleanup_infrastructure
            ;;
        "plan")
            log "Planning infrastructure changes..."
            check_prerequisites
            init_terraform
            plan_infrastructure
            ;;
        *)
            echo "Usage: $0 {deploy|destroy|plan}"
            echo "  deploy  - Deploy the complete DevOps suite"
            echo "  destroy - Destroy all infrastructure"
            echo "  plan    - Plan infrastructure changes only"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
