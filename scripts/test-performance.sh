#!/bin/bash

# Performance Testing Script for Hybrid Deployment
# Tests load handling and response times for deployed services
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

# Test configuration
CONCURRENT_USERS=${CONCURRENT_USERS:-10}
TEST_DURATION=${TEST_DURATION:-60}
RAMP_UP_TIME=${RAMP_UP_TIME:-10}
REQUEST_TIMEOUT=${REQUEST_TIMEOUT:-30}

# Results storage
RESULTS_DIR="$PROJECT_ROOT/performance-results-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$RESULTS_DIR/test.log"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1" >> "$RESULTS_DIR/test.log"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1" >> "$RESULTS_DIR/test.log"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1" >> "$RESULTS_DIR/test.log"
}

log_info() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  $1" >> "$RESULTS_DIR/test.log"
}

# Test banner
show_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║                    Performance Testing Suite                            ║"
    echo "║                  OpenStack DevOps Suite Load Testing                    ║"
    echo "║                          VM + Kubernetes                                ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "🔍 Checking performance testing prerequisites..."
    
    # Check required tools
    local tools=("curl" "ab" "siege")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_warning "Missing performance testing tools: ${missing_tools[*]}"
        log_info "Installing available tools via Homebrew..."
        
        if command -v brew &> /dev/null; then
            for tool in "${missing_tools[@]}"; do
                case "$tool" in
                    "ab")
                        if ! brew list httpd &> /dev/null; then
                            brew install httpd
                        fi
                        ;;
                    "siege")
                        if ! brew list siege &> /dev/null; then
                            brew install siege
                        fi
                        ;;
                esac
            done
        else
            log_warning "Homebrew not available. Some advanced tests will be skipped."
        fi
    fi
    
    log_success "Prerequisites check completed"
}

# Discover deployment endpoints
discover_endpoints() {
    log "🔍 Discovering deployment endpoints..."
    
    local endpoints=()
    
    # Check VM deployment
    if [[ -f "$PROJECT_ROOT/terraform/terraform.tfstate" ]]; then
        cd "$PROJECT_ROOT/terraform"
        
        local gitlab_ip=$(terraform output -raw gitlab_floating_ip 2>/dev/null || echo "")
        local nginx_ip=$(terraform output -raw nginx_floating_ip 2>/dev/null || echo "")
        local nexus_ip=$(terraform output -raw nexus_floating_ip 2>/dev/null || echo "")
        local keycloak_ip=$(terraform output -raw keycloak_floating_ip 2>/dev/null || echo "")
        local rancher_ip=$(terraform output -raw rancher_floating_ip 2>/dev/null || echo "")
        
        if [[ -n "$gitlab_ip" && "$gitlab_ip" != "null" ]]; then
            endpoints+=("http://$gitlab_ip:8090|GitLab VM")
        fi
        
        if [[ -n "$nginx_ip" && "$nginx_ip" != "null" ]]; then
            endpoints+=("http://$nginx_ip|Dashboard VM")
        fi
        
        if [[ -n "$nexus_ip" && "$nexus_ip" != "null" ]]; then
            endpoints+=("http://$nexus_ip:8081|Nexus VM")
        fi
        
        if [[ -n "$keycloak_ip" && "$keycloak_ip" != "null" ]]; then
            endpoints+=("http://$keycloak_ip:8180|Keycloak VM")
        fi
        
        if [[ -n "$rancher_ip" && "$rancher_ip" != "null" ]]; then
            endpoints+=("https://$rancher_ip:8443|Rancher VM")
        fi
    fi
    
    # Check Kubernetes deployment
    if kubectl get namespace devops-suite &> /dev/null; then
        local ingress_ip=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        
        if [[ -n "$ingress_ip" && "$ingress_ip" != "null" ]]; then
            local domain=${DOMAIN_NAME:-"yourdomain.com"}
            endpoints+=("http://$ingress_ip|GitLab K8s|gitlab.$domain")
            endpoints+=("http://$ingress_ip|Dashboard K8s|dashboard.$domain")
            endpoints+=("http://$ingress_ip|Nexus K8s|nexus.$domain")
            endpoints+=("http://$ingress_ip|Keycloak K8s|keycloak.$domain")
            endpoints+=("http://$ingress_ip|Rancher K8s|rancher.$domain")
        fi
    fi
    
    if [[ ${#endpoints[@]} -eq 0 ]]; then
        log_error "No deployment endpoints found. Deploy the infrastructure first."
        exit 1
    fi
    
    log_success "Found ${#endpoints[@]} endpoints for testing"
    printf '%s\n' "${endpoints[@]}" > "$RESULTS_DIR/endpoints.txt"
    
    # Set global endpoints array
    ENDPOINTS=("${endpoints[@]}")
}

# Basic connectivity test
test_basic_connectivity() {
    log "🌐 Testing basic connectivity to all endpoints..."
    
    local connectivity_results="$RESULTS_DIR/connectivity.txt"
    echo "# Connectivity Test Results" > "$connectivity_results"
    echo "# Generated: $(date)" >> "$connectivity_results"
    echo "" >> "$connectivity_results"
    
    for endpoint in "${ENDPOINTS[@]}"; do
        IFS='|' read -r url name host <<< "$endpoint"
        
        local test_cmd="curl -s -o /dev/null -w '%{http_code}|%{time_total}|%{time_connect}|%{time_starttransfer}'"
        if [[ -n "$host" ]]; then
            test_cmd="$test_cmd -H 'Host: $host'"
        fi
        test_cmd="$test_cmd --max-time $REQUEST_TIMEOUT '$url'"
        
        local result=$(eval "$test_cmd" 2>/dev/null || echo "000|0|0|0")
        IFS='|' read -r status total_time connect_time transfer_time <<< "$result"
        
        echo "$name|$status|$total_time|$connect_time|$transfer_time" >> "$connectivity_results"
        
        if [[ "$status" -ge 200 && "$status" -lt 400 ]]; then
            log_success "$name: HTTP $status (${total_time}s)"
        elif [[ "$status" -ge 400 && "$status" -lt 500 ]]; then
            log_warning "$name: HTTP $status (may need authentication)"
        else
            log_error "$name: HTTP $status or connection failed"
        fi
    done
}

# Apache Bench load testing
run_apache_bench_tests() {
    if ! command -v ab &> /dev/null; then
        log_warning "Apache Bench (ab) not available, skipping load tests"
        return
    fi
    
    log "🚀 Running Apache Bench load tests..."
    
    local ab_results="$RESULTS_DIR/apache_bench"
    mkdir -p "$ab_results"
    
    for endpoint in "${ENDPOINTS[@]}"; do
        IFS='|' read -r url name host <<< "$endpoint"
        
        log_info "Testing $name with $CONCURRENT_USERS concurrent users..."
        
        local ab_cmd="ab -n $((CONCURRENT_USERS * 10)) -c $CONCURRENT_USERS"
        if [[ -n "$host" ]]; then
            ab_cmd="$ab_cmd -H 'Host: $host'"
        fi
        ab_cmd="$ab_cmd '$url' > '$ab_results/${name// /_}.txt' 2>&1"
        
        eval "$ab_cmd" || true
        
        # Extract key metrics
        if [[ -f "$ab_results/${name// /_}.txt" ]]; then
            local requests_per_sec=$(grep "Requests per second" "$ab_results/${name// /_}.txt" | awk '{print $4}' || echo "0")
            local mean_time=$(grep "Time per request" "$ab_results/${name// /_}.txt" | head -1 | awk '{print $4}' || echo "0")
            local failed_requests=$(grep "Failed requests" "$ab_results/${name// /_}.txt" | awk '{print $3}' || echo "0")
            
            log_info "$name: $requests_per_sec req/sec, ${mean_time}ms avg, $failed_requests failures"
        fi
    done
}

# Siege stress testing
run_siege_tests() {
    if ! command -v siege &> /dev/null; then
        log_warning "Siege not available, skipping stress tests"
        return
    fi
    
    log "⚔️  Running Siege stress tests..."
    
    local siege_results="$RESULTS_DIR/siege"
    mkdir -p "$siege_results"
    
    # Create URL file for siege
    local urls_file="$siege_results/urls.txt"
    for endpoint in "${ENDPOINTS[@]}"; do
        IFS='|' read -r url name host <<< "$endpoint"
        if [[ -n "$host" ]]; then
            echo "$url HOST:$host" >> "$urls_file"
        else
            echo "$url" >> "$urls_file"
        fi
    done
    
    log_info "Running siege test for ${TEST_DURATION}s with $CONCURRENT_USERS concurrent users..."
    
    siege -f "$urls_file" \
          -c "$CONCURRENT_USERS" \
          -t "${TEST_DURATION}s" \
          --log="$siege_results/siege.log" \
          > "$siege_results/siege_summary.txt" 2>&1 || true
    
    # Extract key metrics
    if [[ -f "$siege_results/siege_summary.txt" ]]; then
        local availability=$(grep "Availability" "$siege_results/siege_summary.txt" | awk '{print $2}' || echo "0%")
        local response_time=$(grep "Response time" "$siege_results/siege_summary.txt" | awk '{print $3}' || echo "0")
        local transaction_rate=$(grep "Transaction rate" "$siege_results/siege_summary.txt" | awk '{print $3}' || echo "0")
        
        log_success "Siege results: $availability availability, ${response_time}s response time, $transaction_rate trans/sec"
    fi
}

# Resource monitoring during tests
monitor_resources() {
    log "📊 Starting resource monitoring..."
    
    local monitor_results="$RESULTS_DIR/monitoring"
    mkdir -p "$monitor_results"
    
    # Monitor Kubernetes resources if available
    if kubectl get namespace devops-suite &> /dev/null; then
        log_info "Monitoring Kubernetes resources..."
        
        # Start resource monitoring in background
        {
            while true; do
                echo "$(date): $(kubectl top nodes --no-headers 2>/dev/null || echo 'N/A')" >> "$monitor_results/k8s_nodes.log"
                echo "$(date): $(kubectl top pods -n devops-suite --no-headers 2>/dev/null || echo 'N/A')" >> "$monitor_results/k8s_pods.log"
                sleep 5
            done
        } &
        local k8s_monitor_pid=$!
        
        # Store PID for cleanup
        echo "$k8s_monitor_pid" > "$monitor_results/k8s_monitor.pid"
    fi
    
    # Monitor system resources
    {
        while true; do
            echo "$(date): $(top -l 1 -s 0 | grep "CPU usage" | head -1)" >> "$monitor_results/system_cpu.log"
            echo "$(date): $(vm_stat | head -5)" >> "$monitor_results/system_memory.log"
            sleep 5
        done
    } &
    local system_monitor_pid=$!
    echo "$system_monitor_pid" > "$monitor_results/system_monitor.pid"
    
    log_success "Resource monitoring started"
}

# Stop resource monitoring
stop_monitoring() {
    log "⏹️  Stopping resource monitoring..."
    
    local monitor_results="$RESULTS_DIR/monitoring"
    
    # Stop Kubernetes monitoring
    if [[ -f "$monitor_results/k8s_monitor.pid" ]]; then
        local k8s_pid=$(cat "$monitor_results/k8s_monitor.pid")
        kill "$k8s_pid" 2>/dev/null || true
        rm -f "$monitor_results/k8s_monitor.pid"
    fi
    
    # Stop system monitoring
    if [[ -f "$monitor_results/system_monitor.pid" ]]; then
        local system_pid=$(cat "$monitor_results/system_monitor.pid")
        kill "$system_pid" 2>/dev/null || true
        rm -f "$monitor_results/system_monitor.pid"
    fi
    
    log_success "Resource monitoring stopped"
}

# Generate performance report
generate_performance_report() {
    log "📋 Generating performance report..."
    
    local report_file="$RESULTS_DIR/performance_report.md"
    
    cat > "$report_file" << EOF
# Performance Test Report

**Generated:** $(date)  
**Test Configuration:**
- Concurrent Users: $CONCURRENT_USERS
- Test Duration: ${TEST_DURATION}s
- Request Timeout: ${REQUEST_TIMEOUT}s

## Test Summary

### Endpoints Tested
$(cat "$RESULTS_DIR/endpoints.txt" | sed 's/^/- /')

### Connectivity Results
| Service | Status | Total Time (s) | Connect Time (s) | Transfer Time (s) |
|---------|--------|----------------|------------------|------------------|
EOF

    if [[ -f "$RESULTS_DIR/connectivity.txt" ]]; then
        while IFS='|' read -r name status total connect transfer; do
            if [[ "$name" != \#* ]]; then
                echo "| $name | $status | $total | $connect | $transfer |" >> "$report_file"
            fi
        done < "$RESULTS_DIR/connectivity.txt"
    fi
    
    cat >> "$report_file" << EOF

## Load Testing Results

### Apache Bench Summary
EOF

    if [[ -d "$RESULTS_DIR/apache_bench" ]]; then
        for result_file in "$RESULTS_DIR/apache_bench"/*.txt; do
            if [[ -f "$result_file" ]]; then
                local service_name=$(basename "$result_file" .txt | tr '_' ' ')
                echo "#### $service_name" >> "$report_file"
                echo '```' >> "$report_file"
                grep -E "(Requests per second|Time per request|Failed requests)" "$result_file" >> "$report_file" || true
                echo '```' >> "$report_file"
                echo "" >> "$report_file"
            fi
        done
    fi
    
    cat >> "$report_file" << EOF

### Siege Stress Test Summary
EOF

    if [[ -f "$RESULTS_DIR/siege/siege_summary.txt" ]]; then
        echo '```' >> "$report_file"
        cat "$RESULTS_DIR/siege/siege_summary.txt" >> "$report_file"
        echo '```' >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Resource Monitoring

### System Resources
EOF

    if [[ -d "$RESULTS_DIR/monitoring" ]]; then
        echo "Resource monitoring logs available in: \`monitoring/\`" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Recommendations

### Performance Optimizations
1. **Response Time**: Monitor services with >2s response times
2. **Error Rate**: Investigate any endpoints with >5% failure rate
3. **Resource Usage**: Scale services showing high CPU/memory usage
4. **Load Balancing**: Consider additional replicas for high-traffic services

### Infrastructure Scaling
1. **Kubernetes**: Use HPA (Horizontal Pod Autoscaler) for automatic scaling
2. **VM**: Consider larger instance types or additional nodes
3. **Database**: Optimize database connections and queries
4. **Caching**: Implement Redis caching for frequently accessed data

EOF
    
    log_success "Performance report generated: $report_file"
}

# Cleanup function
cleanup() {
    log "🧹 Cleaning up..."
    stop_monitoring
}

# Error handling
handle_error() {
    log_error "Performance test failed at line $1"
    cleanup
    exit 1
}

trap 'handle_error $LINENO' ERR
trap cleanup EXIT

# Main execution
main() {
    show_banner
    
    log "🚀 Starting performance testing suite..."
    log_info "Results will be saved to: $RESULTS_DIR"
    echo ""
    
    check_prerequisites
    echo ""
    
    discover_endpoints
    echo ""
    
    test_basic_connectivity
    echo ""
    
    monitor_resources
    echo ""
    
    run_apache_bench_tests
    echo ""
    
    run_siege_tests
    echo ""
    
    stop_monitoring
    echo ""
    
    generate_performance_report
    echo ""
    
    log_success "🎉 Performance testing completed!"
    log_info "📁 Results available in: $RESULTS_DIR"
    log_info "📋 Report: $RESULTS_DIR/performance_report.md"
}

# Display usage
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -c, --concurrent USERS    Number of concurrent users (default: 10)"
    echo "  -d, --duration SECONDS    Test duration in seconds (default: 60)"
    echo "  -t, --timeout SECONDS     Request timeout in seconds (default: 30)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  DOMAIN_NAME              Domain name for Kubernetes services (default: yourdomain.com)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Run with defaults"
    echo "  $0 -c 20 -d 120                     # 20 users for 2 minutes"
    echo "  DOMAIN_NAME=mycompany.com $0        # Custom domain"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--concurrent)
            CONCURRENT_USERS="$2"
            shift 2
            ;;
        -d|--duration)
            TEST_DURATION="$2"
            shift 2
            ;;
        -t|--timeout)
            REQUEST_TIMEOUT="$2"
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

# Run main function
main "$@"
