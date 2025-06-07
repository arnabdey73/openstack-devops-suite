#!/bin/bash

# Hybrid Deployment Test Script
# Tests both VM and Kubernetes deployments with comprehensive validation
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

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TEST_RESULTS=()

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TEST_RESULTS+=("✅ $1")
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TEST_RESULTS+=("❌ $1")
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

log_info() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  $1${NC}"
}

# Test banner
show_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║                    Hybrid Deployment Test Suite                         ║"
    echo "║                  OpenStack DevOps Suite Validation                      ║"
    echo "║                          VM + Kubernetes                                ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Test prerequisites
test_prerequisites() {
    log "🔍 Testing prerequisites..."
    
    # Test required tools
    local tools=("terraform" "ansible" "kubectl" "helm" "jq" "curl")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_success "$tool is installed"
        else
            log_error "$tool is not installed"
        fi
    done
    
    # Test OpenStack credentials
    if [[ -n "$OS_AUTH_URL" && -n "$OS_USERNAME" && -n "$OS_PASSWORD" ]]; then
        log_success "OpenStack credentials configured"
    else
        log_warning "OpenStack credentials not fully configured (required for VM deployment)"
    fi
    
    # Test Kubernetes connectivity
    if kubectl cluster-info &> /dev/null; then
        local cluster_name=$(kubectl config current-context)
        local k8s_version=$(kubectl version --client --output=yaml | grep gitVersion | cut -d'"' -f4 | head -1)
        log_success "Kubernetes cluster accessible: $cluster_name (kubectl $k8s_version)"
    else
        log_warning "Kubernetes cluster not accessible (required for K8s deployment)"
    fi
}

# Test configuration files
test_configuration_files() {
    log "📄 Testing configuration files..."
    
    local config_files=(
        "terraform/main.tf"
        "terraform/variables.tf"
        "terraform/outputs.tf"
        "terraform/terraform.tfvars.example"
        "k8s/namespace.yaml"
        "k8s/services.yaml"
        "k8s/ingress.yaml"
        "k8s/certificates.yaml"
        "playbooks/kubernetes.yml"
        "roles/k8s_deployment/tasks/main.yml"
        "scripts/deploy-hybrid.sh"
        ".gitlab-ci.yml"
    )
    
    for file in "${config_files[@]}"; do
        local full_path="$PROJECT_ROOT/$file"
        if [[ -f "$full_path" ]]; then
            log_success "Configuration file exists: $file"
        else
            log_error "Configuration file missing: $file"
        fi
    done
}

# Test Kubernetes manifests validation
test_kubernetes_manifests() {
    log "☸️  Testing Kubernetes manifests..."
    
    cd "$PROJECT_ROOT"
    
    # Test YAML syntax using yq
    local k8s_files=("k8s/namespace.yaml" "k8s/services.yaml" "k8s/ingress.yaml" "k8s/certificates.yaml")
    local validation_errors=0
    
    for file in "${k8s_files[@]}"; do
        # Basic syntax validation using yq
        if yq eval '.' "$file" >/dev/null 2>&1; then
            log_success "Valid Kubernetes manifest: $file"
        else
            log_error "Invalid Kubernetes manifest: $file"
            validation_errors=$((validation_errors + 1))
        fi
    done
    
    # Overall validation summary
    if [[ $validation_errors -eq 0 ]]; then
        log_success "All Kubernetes manifests have valid YAML syntax"
    else
        log_error "Some Kubernetes manifests have validation errors"
    fi
}

# Test Terraform configuration
test_terraform_configuration() {
    log "🏗️  Testing Terraform configuration..."
    
    cd "$PROJECT_ROOT/terraform"
    
    # Test Terraform init
    if terraform init -upgrade &> /dev/null; then
        log_success "Terraform initialization successful"
    else
        log_error "Terraform initialization failed"
        return
    fi
    
    # Test Terraform format
    if terraform fmt -check &> /dev/null; then
        log_success "Terraform files are properly formatted"
    else
        log_warning "Terraform files need formatting (non-critical)"
    fi
    
    # Test Terraform validation
    if terraform validate &> /dev/null; then
        log_success "Terraform configuration is valid"
    else
        log_error "Terraform configuration validation failed"
    fi
    
    # Test with example variables
    if [[ -f terraform.tfvars.example ]]; then
        cp terraform.tfvars.example terraform.tfvars.test
        if terraform plan -var-file=terraform.tfvars.test &> /dev/null; then
            log_success "Terraform planning with example variables successful"
        else
            log_warning "Terraform planning failed (may need real credentials)"
        fi
        rm -f terraform.tfvars.test
    fi
}

# Test Ansible playbooks
test_ansible_playbooks() {
    log "📋 Testing Ansible playbooks..."
    
    cd "$PROJECT_ROOT"
    
    # Test playbook syntax
    local playbooks=("playbooks/site.yml" "playbooks/kubernetes.yml")
    for playbook in "${playbooks[@]}"; do
        if ansible-playbook --syntax-check "$playbook" &> /dev/null; then
            log_success "Valid Ansible playbook: $playbook"
        else
            log_error "Invalid Ansible playbook: $playbook"
        fi
    done
    
    # Test inventory syntax
    if [[ -f inventory/openstack-hosts.yml ]]; then
        if ansible-inventory -i inventory/openstack-hosts.yml --list &> /dev/null; then
            log_success "Valid Ansible inventory"
        else
            log_error "Invalid Ansible inventory"
        fi
    fi
}

# Test GitLab CI/CD configuration
test_gitlab_ci() {
    log "🦊 Testing GitLab CI/CD configuration..."
    
    cd "$PROJECT_ROOT"
    
    # Check if .gitlab-ci.yml exists and has required sections
    if [[ -f .gitlab-ci.yml ]]; then
        log_success "GitLab CI configuration file exists"
        
        # Check for hybrid deployment support
        if grep -q "kubernetes:validate" .gitlab-ci.yml; then
            log_success "Kubernetes validation job configured"
        else
            log_error "Kubernetes validation job missing"
        fi
        
        if grep -q "kubernetes:deploy" .gitlab-ci.yml; then
            log_success "Kubernetes deployment job configured"
        else
            log_error "Kubernetes deployment job missing"
        fi
        
        if grep -q "hybrid:deploy" .gitlab-ci.yml; then
            log_success "Hybrid deployment job configured"
        else
            log_error "Hybrid deployment job missing"
        fi
    else
        log_error "GitLab CI configuration file missing"
    fi
}

# Test deployment script functionality
test_deployment_script() {
    log "🚀 Testing deployment script functionality..."
    
    cd "$PROJECT_ROOT"
    
    # Test script exists and is executable
    if [[ -x scripts/deploy-hybrid.sh ]]; then
        log_success "Deployment script is executable"
    else
        log_error "Deployment script is not executable"
        return
    fi
    
    # Test script help/usage
    if scripts/deploy-hybrid.sh --help &> /dev/null || scripts/deploy-hybrid.sh unknown-command &> /dev/null; then
        log_success "Deployment script shows usage information"
    else
        log_warning "Deployment script usage information may be incomplete"
    fi
    
    # Test script validation mode (dry-run like functionality)
    export ENABLE_VMS=false
    export ENABLE_KUBERNETES=false
    if timeout 30s scripts/deploy-hybrid.sh status &> /dev/null; then
        log_success "Deployment script status command works"
    else
        log_warning "Deployment script status command may need infrastructure"
    fi
}

# Test SSL certificate configuration
test_ssl_configuration() {
    log "🔒 Testing SSL certificate configuration..."
    
    cd "$PROJECT_ROOT"
    
    # Check cert-manager configuration in K8s manifests
    if grep -q "cert-manager.io" k8s/certificates.yaml; then
        log_success "cert-manager configuration found"
    else
        log_error "cert-manager configuration missing"
    fi
    
    # Check Let's Encrypt issuers
    if grep -q "letsencrypt" k8s/certificates.yaml; then
        log_success "Let's Encrypt issuer configuration found"
    else
        log_error "Let's Encrypt issuer configuration missing"
    fi
    
    # Check Ingress SSL configuration
    if grep -q "tls:" k8s/ingress.yaml; then
        log_success "Ingress TLS configuration found"
    else
        log_error "Ingress TLS configuration missing"
    fi
}

# Test service connectivity (if deployed)
test_service_connectivity() {
    log "🌐 Testing service connectivity..."
    
    # Test VM services (if accessible)
    if command -v terraform &> /dev/null && [[ -f "$PROJECT_ROOT/terraform/terraform.tfstate" ]]; then
        cd "$PROJECT_ROOT/terraform"
        
        # Try to get IPs from Terraform state
        local gitlab_ip=$(terraform output -raw gitlab_floating_ip 2>/dev/null || echo "")
        local nginx_ip=$(terraform output -raw nginx_floating_ip 2>/dev/null || echo "")
        
        if [[ -n "$gitlab_ip" && "$gitlab_ip" != "null" ]]; then
            if curl -f -s -m 10 "http://$gitlab_ip:8090" > /dev/null; then
                log_success "GitLab VM service is accessible"
            else
                log_warning "GitLab VM service not accessible (may be starting up)"
            fi
        fi
        
        if [[ -n "$nginx_ip" && "$nginx_ip" != "null" ]]; then
            if curl -f -s -m 10 "http://$nginx_ip" > /dev/null; then
                log_success "NGINX proxy is accessible"
            else
                log_warning "NGINX proxy not accessible (may be starting up)"
            fi
        fi
    fi
    
    # Test Kubernetes services (if deployed)
    if kubectl get namespace devops-suite &> /dev/null; then
        log_success "DevOps Suite namespace exists in Kubernetes"
        
        # Check pod status
        local pod_count=$(kubectl get pods -n devops-suite --no-headers 2>/dev/null | wc -l || echo "0")
        if [[ "$pod_count" -gt 0 ]]; then
            log_success "Kubernetes pods are deployed ($pod_count pods)"
        else
            log_warning "No Kubernetes pods found (may not be deployed yet)"
        fi
        
        # Check ingress status
        if kubectl get ingress -n devops-suite &> /dev/null; then
            log_success "Kubernetes ingress resources exist"
        else
            log_warning "Kubernetes ingress resources not found"
        fi
    else
        log_info "DevOps Suite not deployed to Kubernetes (test skipped)"
    fi
}

# Test documentation completeness
test_documentation() {
    log "📚 Testing documentation completeness..."
    
    cd "$PROJECT_ROOT"
    
    local doc_files=(
        "docs/HYBRID_DEPLOYMENT_GUIDE.md"
        "docs/DNS_CONFIGURATION_GUIDE.md"
        "README.md"
    )
    
    for doc in "${doc_files[@]}"; do
        if [[ -f "$doc" ]]; then
            log_success "Documentation exists: $doc"
            
            # Check for key sections
            if grep -q "Prerequisites" "$doc"; then
                log_success "Prerequisites section found in $doc"
            else
                log_warning "Prerequisites section missing in $doc"
            fi
        else
            log_error "Documentation missing: $doc"
        fi
    done
}

# Generate test report
generate_report() {
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                           TEST RESULTS SUMMARY                          ║"
    echo -e "╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
    echo -e "${BLUE}Total Tests: $((TESTS_PASSED + TESTS_FAILED))${NC}"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 All tests passed! The hybrid deployment is ready.${NC}"
        exit_code=0
    else
        echo -e "${YELLOW}⚠️  Some tests failed. Review the issues above.${NC}"
        exit_code=1
    fi
    
    echo ""
    echo "Detailed Results:"
    printf '%s\n' "${TEST_RESULTS[@]}"
    
    # Save report to file
    local report_file="$PROJECT_ROOT/test-results-$(date +%Y%m%d-%H%M%S).log"
    {
        echo "# Hybrid Deployment Test Results"
        echo "Generated: $(date)"
        echo ""
        echo "## Summary"
        echo "- Tests Passed: $TESTS_PASSED"
        echo "- Tests Failed: $TESTS_FAILED" 
        echo "- Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
        echo ""
        echo "## Detailed Results"
        printf '%s\n' "${TEST_RESULTS[@]}"
    } > "$report_file"
    
    log_info "Test report saved to: $report_file"
    
    return $exit_code
}

# Main test execution
main() {
    show_banner
    
    log "🧪 Starting comprehensive hybrid deployment tests..."
    echo ""
    
    test_prerequisites
    echo ""
    
    test_configuration_files
    echo ""
    
    test_kubernetes_manifests
    echo ""
    
    test_terraform_configuration
    echo ""
    
    test_ansible_playbooks
    echo ""
    
    test_gitlab_ci
    echo ""
    
    test_deployment_script
    echo ""
    
    test_ssl_configuration
    echo ""
    
    test_service_connectivity
    echo ""
    
    test_documentation
    echo ""
    
    generate_report
}

# Run main function
main "$@"
