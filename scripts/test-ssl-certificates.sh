#!/bin/bash

# SSL Certificate Validation Script for Hybrid Deployment
# Tests SSL certificate configuration and automatic provisioning
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

# Configuration
DOMAIN_NAME=${DOMAIN_NAME:-"yourdomain.com"}
TIMEOUT=${TIMEOUT:-30}

# Results tracking
SSL_TESTS_PASSED=0
SSL_TESTS_FAILED=0
SSL_RESULTS=()

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
    SSL_TESTS_PASSED=$((SSL_TESTS_PASSED + 1))
    SSL_RESULTS+=("✅ $1")
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
    SSL_TESTS_FAILED=$((SSL_TESTS_FAILED + 1))
    SSL_RESULTS+=("❌ $1")
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
    SSL_RESULTS+=("⚠️  $1")
}

log_info() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  $1${NC}"
}

# Test banner
show_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║                      SSL Certificate Validation                         ║"
    echo "║                  OpenStack DevOps Suite SSL Testing                     ║"
    echo "║                          VM + Kubernetes                                ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check SSL tools
check_ssl_tools() {
    log "🔍 Checking SSL testing tools..."
    
    local tools=("openssl" "curl")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing SSL tools: ${missing_tools[*]}"
        exit 1
    fi
    
    log_success "SSL tools available"
}

# Test cert-manager installation in Kubernetes
test_cert_manager() {
    if ! kubectl get namespace cert-manager &> /dev/null; then
        log_warning "cert-manager namespace not found (may not be deployed)"
        return
    fi
    
    log "🔧 Testing cert-manager installation..."
    
    # Check cert-manager pods
    local cert_manager_pods=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$cert_manager_pods" -gt 0 ]]; then
        log_success "cert-manager pods running ($cert_manager_pods pods)"
    else
        log_error "cert-manager pods not running"
    fi
    
    # Check cert-manager readiness
    if kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=30s &> /dev/null; then
        log_success "cert-manager is ready"
    else
        log_error "cert-manager is not ready"
    fi
    
    # Check ClusterIssuers
    local issuers=$(kubectl get clusterissuers --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$issuers" -gt 0 ]]; then
        log_success "ClusterIssuers configured ($issuers issuers)"
        
        # List issuer status
        kubectl get clusterissuers -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,AGE:.metadata.creationTimestamp 2>/dev/null | while read -r line; do
            if [[ "$line" != "NAME"* ]]; then
                log_info "Issuer: $line"
            fi
        done
    else
        log_error "No ClusterIssuers found"
    fi
}

# Test Kubernetes certificates
test_kubernetes_certificates() {
    if ! kubectl get namespace devops-suite &> /dev/null; then
        log_info "devops-suite namespace not found, skipping Kubernetes certificate tests"
        return
    fi
    
    log "📜 Testing Kubernetes certificates..."
    
    # Check certificate resources
    local certs=$(kubectl get certificates -n devops-suite --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$certs" -gt 0 ]]; then
        log_success "Certificate resources found ($certs certificates)"
        
        # Check certificate status
        kubectl get certificates -n devops-suite -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,SECRET:.spec.secretName,AGE:.metadata.creationTimestamp 2>/dev/null | while read -r line; do
            if [[ "$line" != "NAME"* ]]; then
                log_info "Certificate: $line"
            fi
        done
        
        # Check for ready certificates
        local ready_certs=$(kubectl get certificates -n devops-suite -o jsonpath='{.items[?(@.status.conditions[0].status=="True")].metadata.name}' 2>/dev/null | wc -w)
        if [[ "$ready_certs" -gt 0 ]]; then
            log_success "Ready certificates: $ready_certs"
        else
            log_warning "No certificates are ready yet (may be provisioning)"
        fi
    else
        log_warning "No certificate resources found"
    fi
    
    # Check certificate secrets
    local cert_secrets=$(kubectl get secrets -n devops-suite --field-selector type=kubernetes.io/tls --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$cert_secrets" -gt 0 ]]; then
        log_success "TLS secrets found ($cert_secrets secrets)"
    else
        log_warning "No TLS secrets found"
    fi
}

# Test SSL endpoint connectivity
test_ssl_endpoints() {
    log "🌐 Testing SSL endpoint connectivity..."
    
    # Get Kubernetes ingress IP
    local ingress_ip=""
    if kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller &> /dev/null; then
        ingress_ip=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    fi
    
    if [[ -n "$ingress_ip" && "$ingress_ip" != "null" ]]; then
        log_info "Testing Kubernetes ingress endpoints (IP: $ingress_ip)"
        
        local services=("gitlab" "dashboard" "nexus" "keycloak" "rancher" "docker")
        for service in "${services[@]}"; do
            test_ssl_certificate "$service.$DOMAIN_NAME" "$ingress_ip" "Kubernetes"
        done
    else
        log_warning "Kubernetes ingress IP not available"
    fi
    
    # Test VM SSL endpoints if available
    if [[ -f "$PROJECT_ROOT/terraform/terraform.tfstate" ]]; then
        cd "$PROJECT_ROOT/terraform"
        
        local nginx_ip=$(terraform output -raw nginx_floating_ip 2>/dev/null || echo "")
        if [[ -n "$nginx_ip" && "$nginx_ip" != "null" ]]; then
            log_info "Testing VM SSL endpoints (IP: $nginx_ip)"
            test_ssl_certificate "dashboard.vm" "$nginx_ip" "VM"
        fi
    fi
}

# Test individual SSL certificate
test_ssl_certificate() {
    local hostname="$1"
    local ip="$2"
    local deployment_type="$3"
    
    log_info "Testing SSL certificate for $hostname ($deployment_type)"
    
    # Test HTTPS connectivity
    local https_test=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" --resolve "$hostname:443:$ip" "https://$hostname" 2>/dev/null || echo "000")
    
    if [[ "$https_test" -ge 200 && "$https_test" -lt 400 ]]; then
        log_success "$hostname HTTPS accessible (HTTP $https_test)"
        
        # Get certificate details
        local cert_info=$(echo | openssl s_client -servername "$hostname" -connect "$ip:443" 2>/dev/null | openssl x509 -noout -text 2>/dev/null || echo "")
        
        if [[ -n "$cert_info" ]]; then
            # Extract certificate details
            local issuer=$(echo "$cert_info" | grep "Issuer:" | head -1 | sed 's/.*Issuer: //')
            local subject=$(echo "$cert_info" | grep "Subject:" | head -1 | sed 's/.*Subject: //')
            local not_after=$(echo "$cert_info" | grep "Not After" | sed 's/.*Not After : //')
            
            log_info "$hostname certificate issuer: $issuer"
            log_info "$hostname certificate subject: $subject"
            log_info "$hostname certificate expires: $not_after"
            
            # Check if it's a Let's Encrypt certificate
            if echo "$issuer" | grep -q "Let's Encrypt"; then
                log_success "$hostname uses Let's Encrypt certificate"
            else
                log_info "$hostname uses custom/self-signed certificate"
            fi
            
            # Check certificate validity period
            local expiry_date=$(date -d "$not_after" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$not_after" +%s 2>/dev/null || echo "0")
            local current_date=$(date +%s)
            local days_until_expiry=$(( (expiry_date - current_date) / 86400 ))
            
            if [[ "$days_until_expiry" -gt 30 ]]; then
                log_success "$hostname certificate valid for $days_until_expiry days"
            elif [[ "$days_until_expiry" -gt 0 ]]; then
                log_warning "$hostname certificate expires in $days_until_expiry days"
            else
                log_error "$hostname certificate expired"
            fi
        else
            log_warning "$hostname certificate details not available"
        fi
    elif [[ "$https_test" -ge 400 && "$https_test" -lt 500 ]]; then
        log_warning "$hostname HTTPS accessible but requires authentication (HTTP $https_test)"
    else
        log_error "$hostname HTTPS not accessible (HTTP $https_test)"
    fi
    
    # Test HTTP to HTTPS redirect
    local http_test=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" --resolve "$hostname:80:$ip" "http://$hostname" 2>/dev/null || echo "000")
    
    if [[ "$http_test" -eq 301 || "$http_test" -eq 302 ]]; then
        log_success "$hostname HTTP redirects to HTTPS (HTTP $http_test)"
    elif [[ "$http_test" -eq 200 ]]; then
        log_warning "$hostname HTTP accessible without redirect"
    else
        log_warning "$hostname HTTP not accessible (HTTP $http_test)"
    fi
}

# Test certificate renewal process
test_certificate_renewal() {
    if ! kubectl get namespace cert-manager &> /dev/null; then
        log_info "cert-manager not available, skipping renewal tests"
        return
    fi
    
    log "🔄 Testing certificate renewal process..."
    
    # Check for certificate requests
    local cert_requests=$(kubectl get certificaterequests -n devops-suite --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$cert_requests" -gt 0 ]]; then
        log_info "Found $cert_requests certificate requests"
        
        # Show recent certificate requests
        kubectl get certificaterequests -n devops-suite -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,AGE:.metadata.creationTimestamp 2>/dev/null | while read -r line; do
            if [[ "$line" != "NAME"* ]]; then
                log_info "CertificateRequest: $line"
            fi
        done
    fi
    
    # Check for challenges
    local challenges=$(kubectl get challenges -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$challenges" -gt 0 ]]; then
        log_info "Found $challenges ACME challenges"
        
        # Show challenge status
        kubectl get challenges -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATE:.status.state,AGE:.metadata.creationTimestamp 2>/dev/null | while read -r line; do
            if [[ "$line" != "NAMESPACE"* ]]; then
                log_info "Challenge: $line"
            fi
        done
    else
        log_success "No active ACME challenges (certificates may be ready)"
    fi
}

# Test DNS configuration for SSL
test_dns_configuration() {
    log "🌍 Testing DNS configuration for SSL..."
    
    # Get ingress IP
    local ingress_ip=""
    if kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller &> /dev/null; then
        ingress_ip=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    fi
    
    if [[ -n "$ingress_ip" && "$ingress_ip" != "null" ]]; then
        log_info "Ingress LoadBalancer IP: $ingress_ip"
        
        local services=("gitlab" "dashboard" "nexus" "keycloak" "rancher" "docker")
        for service in "${services[@]}"; do
            local hostname="$service.$DOMAIN_NAME"
            
            # Test DNS resolution
            local resolved_ip=$(dig +short "$hostname" 2>/dev/null | head -1 || echo "")
            
            if [[ "$resolved_ip" == "$ingress_ip" ]]; then
                log_success "$hostname resolves to correct IP ($resolved_ip)"
            elif [[ -n "$resolved_ip" ]]; then
                log_warning "$hostname resolves to different IP ($resolved_ip, expected $ingress_ip)"
            else
                log_error "$hostname does not resolve"
            fi
        done
    else
        log_warning "Ingress IP not available for DNS testing"
    fi
}

# Generate SSL test report
generate_ssl_report() {
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                        SSL TEST RESULTS SUMMARY                         ║"
    echo -e "╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${GREEN}SSL Tests Passed: $SSL_TESTS_PASSED${NC}"
    echo -e "${RED}SSL Tests Failed: $SSL_TESTS_FAILED${NC}"
    echo -e "${BLUE}Total SSL Tests: $((SSL_TESTS_PASSED + SSL_TESTS_FAILED))${NC}"
    echo ""
    
    if [[ $SSL_TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 All SSL tests passed! Certificate configuration is working.${NC}"
        ssl_exit_code=0
    else
        echo -e "${YELLOW}⚠️  Some SSL tests failed. Review the issues above.${NC}"
        ssl_exit_code=1
    fi
    
    echo ""
    echo "Detailed SSL Results:"
    printf '%s\n' "${SSL_RESULTS[@]}"
    
    # Save SSL report
    local ssl_report_file="$PROJECT_ROOT/ssl-test-results-$(date +%Y%m%d-%H%M%S).log"
    {
        echo "# SSL Certificate Test Results"
        echo "Generated: $(date)"
        echo "Domain: $DOMAIN_NAME"
        echo ""
        echo "## Summary"
        echo "- SSL Tests Passed: $SSL_TESTS_PASSED"
        echo "- SSL Tests Failed: $SSL_TESTS_FAILED" 
        echo "- Total SSL Tests: $((SSL_TESTS_PASSED + SSL_TESTS_FAILED))"
        echo ""
        echo "## Detailed Results"
        printf '%s\n' "${SSL_RESULTS[@]}"
        echo ""
        echo "## Recommendations"
        echo "1. Ensure DNS records point to the correct ingress IP"
        echo "2. Verify cert-manager is properly configured"
        echo "3. Check ACME challenge completion"
        echo "4. Monitor certificate expiration dates"
    } > "$ssl_report_file"
    
    log_info "SSL test report saved to: $ssl_report_file"
    
    return $ssl_exit_code
}

# Display usage
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -d, --domain DOMAIN      Domain name for testing (default: yourdomain.com)"
    echo "  -t, --timeout SECONDS    Connection timeout (default: 30)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  DOMAIN_NAME             Domain name for services"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Test with default domain"
    echo "  $0 -d mycompany.com                  # Test with custom domain"
    echo "  DOMAIN_NAME=test.com $0              # Set domain via environment"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain)
            DOMAIN_NAME="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    show_banner
    
    log "🔒 Starting SSL certificate validation..."
    log_info "Domain: $DOMAIN_NAME"
    log_info "Timeout: ${TIMEOUT}s"
    echo ""
    
    check_ssl_tools
    echo ""
    
    test_cert_manager
    echo ""
    
    test_kubernetes_certificates
    echo ""
    
    test_dns_configuration
    echo ""
    
    test_ssl_endpoints
    echo ""
    
    test_certificate_renewal
    echo ""
    
    generate_ssl_report
}

# Run main function
main "$@"
