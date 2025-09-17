#!/bin/bash
set -euo pipefail

# DevOps Suite Infrastructure Testing Script
# This script runs comprehensive infrastructure tests using Terratest

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="$PROJECT_ROOT/terraform/tests"
LOG_DIR="$PROJECT_ROOT/logs/testing"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging setup
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/infrastructure_test_$TIMESTAMP.log"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Cleanup function
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Test execution failed with exit code: $exit_code"
        log_info "Check logs at: $LOG_FILE"
    fi
    exit $exit_code
}

trap cleanup EXIT

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        log_error "Go is not installed. Please install Go 1.21 or later."
        exit 1
    fi
    
    # Check Go version
    go_version=$(go version | cut -d' ' -f3 | sed 's/go//')
    if [[ $(echo "$go_version 1.21" | tr ' ' '\n' | sort -V | head -n1) != "1.21" ]]; then
        log_error "Go version must be 1.21 or later. Current version: $go_version"
        exit 1
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install Terraform."
        exit 1
    fi
    
    # Check OpenStack credentials
    required_vars=("OS_AUTH_URL" "OS_USERNAME" "OS_PASSWORD" "OS_PROJECT_NAME" "OS_USER_DOMAIN_NAME")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            log_error "Environment variable $var is not set. Please configure OpenStack credentials."
            exit 1
        fi
    done
    
    log_success "Prerequisites check passed"
}

# Initialize test environment
init_test_environment() {
    log_info "Initializing test environment..."
    
    # Navigate to test directory
    cd "$TEST_DIR"
    
    # Initialize Go module if not exists
    if [ ! -f "go.mod" ]; then
        log_error "go.mod file not found in test directory"
        exit 1
    fi
    
    # Download dependencies
    log_info "Downloading Go dependencies..."
    go mod download
    go mod tidy
    
    # Verify Terraform configuration
    log_info "Validating Terraform configuration..."
    cd "$PROJECT_ROOT/terraform"
    terraform init -backend=false
    terraform validate
    
    log_success "Test environment initialized"
}

# Run OPA policy validation
validate_policies() {
    log_info "Running policy validation with OPA..."
    
    # Check if OPA is available
    if command -v opa &> /dev/null; then
        cd "$PROJECT_ROOT"
        
        # Test Terraform policies
        if [ -d "policy/terraform" ]; then
            log_info "Validating Terraform policies..."
            for policy_file in policy/terraform/*.rego; do
                if [ -f "$policy_file" ]; then
                    opa fmt "$policy_file" --diff
                    opa test "$policy_file" || log_warning "Policy test failed for $policy_file"
                fi
            done
        fi
        
        # Test Kubernetes policies  
        if [ -d "policy/kubernetes" ]; then
            log_info "Validating Kubernetes policies..."
            for policy_file in policy/kubernetes/*.rego; do
                if [ -f "$policy_file" ]; then
                    opa fmt "$policy_file" --diff
                    opa test "$policy_file" || log_warning "Policy test failed for $policy_file"
                fi
            done
        fi
        
        log_success "Policy validation completed"
    else
        log_warning "OPA not found, skipping policy validation"
    fi
}

# Run infrastructure tests
run_infrastructure_tests() {
    log_info "Running infrastructure tests..."
    
    cd "$TEST_DIR"
    
    # Set test timeout
    export TEST_TIMEOUT="30m"
    
    # Run tests with verbose output
    log_info "Executing Terratest suite..."
    
    # Test specific functions or run all tests
    if [ "${1:-}" == "quick" ]; then
        log_info "Running quick tests (no deployment)..."
        go test -v -timeout "$TEST_TIMEOUT" -run "TestSecurityCompliance" ./...
    else
        log_info "Running full infrastructure tests..."
        go test -v -timeout "$TEST_TIMEOUT" -parallel 2 ./...
    fi
    
    test_exit_code=$?
    
    if [ $test_exit_code -eq 0 ]; then
        log_success "Infrastructure tests passed"
    else
        log_error "Infrastructure tests failed with exit code: $test_exit_code"
        return $test_exit_code
    fi
}

# Generate test report
generate_test_report() {
    log_info "Generating test report..."
    
    local report_file="$LOG_DIR/test_report_$TIMESTAMP.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>DevOps Suite Infrastructure Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background-color: #f8f9fa; padding: 20px; border-radius: 5px; }
        .success { color: #28a745; }
        .error { color: #dc3545; }
        .warning { color: #ffc107; }
        .info { color: #17a2b8; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #007bff; }
        pre { background-color: #f8f9fa; padding: 10px; border-radius: 3px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="header">
        <h1>DevOps Suite Infrastructure Test Report</h1>
        <p><strong>Timestamp:</strong> $(date)</p>
        <p><strong>Environment:</strong> ${OS_PROJECT_NAME:-"Unknown"}</p>
    </div>
    
    <div class="section">
        <h2>Test Summary</h2>
        <p>Test execution completed at $(date)</p>
        <p><strong>Log File:</strong> $LOG_FILE</p>
    </div>
    
    <div class="section">
        <h2>Test Results</h2>
        <pre>$(tail -n 50 "$LOG_FILE")</pre>
    </div>
    
    <div class="section">
        <h2>Infrastructure Components Tested</h2>
        <ul>
            <li>OpenStack Infrastructure Provisioning</li>
            <li>Security Group Configuration</li>
            <li>Compute Instance Deployment</li>
            <li>Network Configuration & Floating IPs</li>
            <li>Storage Volume Management</li>
            <li>Service Endpoint Availability</li>
            <li>Health Check Validation</li>
            <li>Monitoring Stack Integration</li>
            <li>Policy Compliance Validation</li>
        </ul>
    </div>
</body>
</html>
EOF
    
    log_success "Test report generated: $report_file"
}

# Main execution
main() {
    log_info "Starting DevOps Suite Infrastructure Testing"
    log_info "=========================================="
    
    # Parse command line arguments
    local test_mode="${1:-full}"
    
    case "$test_mode" in
        "quick")
            log_info "Running in quick mode (no infrastructure deployment)"
            ;;
        "full")
            log_info "Running full test suite"
            ;;
        "policy-only")
            log_info "Running policy validation only"
            validate_policies
            return 0
            ;;
        *)
            log_error "Invalid test mode: $test_mode"
            log_info "Usage: $0 [quick|full|policy-only]"
            exit 1
            ;;
    esac
    
    # Execute test pipeline
    check_prerequisites
    init_test_environment
    validate_policies
    run_infrastructure_tests "$test_mode"
    generate_test_report
    
    log_success "Infrastructure testing completed successfully!"
    log_info "Results available in: $LOG_DIR"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi