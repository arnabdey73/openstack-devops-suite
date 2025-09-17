# Infrastructure Testing & Validation Framework

## Overview

This directory contains comprehensive testing and validation tools for the OpenStack DevOps Suite infrastructure. The testing framework uses Terratest for infrastructure validation, Open Policy Agent (OPA) for policy enforcement, and automated compliance checking.

## Components

### 1. Terratest Infrastructure Tests (`terraform/tests/`)

- **infrastructure_test.go**: Comprehensive Go-based tests using Terratest framework
- **go.mod**: Go module dependencies for testing
- Tests include:
  - Infrastructure deployment validation
  - Security group configuration verification
  - Compute instance health checks
  - Network connectivity testing
  - Service endpoint availability
  - Monitoring stack validation
  - Performance benchmarks

### 2. Policy-as-Code Framework (`policy/`)

#### Terraform Policies (`policy/terraform/`)
- **security_compliance.rego**: Security and compliance policies for infrastructure
  - SSH key management enforcement
  - HTTPS/TLS requirement validation
  - Resource tagging compliance
  - Instance sizing policies
  - Backup configuration validation
  - Network security rules

#### Kubernetes Policies (`policy/kubernetes/`)
- **security_policies.rego**: Kubernetes security and governance policies
  - Pod Security Standards enforcement
  - Container image security validation
  - Resource quota management
  - Network policy compliance
  - RBAC validation

### 3. Automated Testing Scripts (`scripts/`)

- **test-infrastructure.sh**: Comprehensive testing orchestration script
  - Prerequisite validation
  - Terraform configuration testing
  - OPA policy validation
  - Infrastructure deployment testing
  - Test report generation

## Quick Start

### Prerequisites

1. **Go 1.21+** installed
2. **Terraform** installed and configured
3. **Open Policy Agent (OPA)** installed (optional, for policy validation)
4. **OpenStack credentials** configured:
   ```bash
   export OS_AUTH_URL="https://your-openstack-endpoint:5000/v3"
   export OS_USERNAME="your-username"
   export OS_PASSWORD="your-password"
   export OS_PROJECT_NAME="your-project"
   export OS_USER_DOMAIN_NAME="default"
   ```

### Running Tests

#### Quick Validation (No Infrastructure Deployment)
```bash
./scripts/test-infrastructure.sh quick
```

#### Full Infrastructure Test Suite
```bash
./scripts/test-infrastructure.sh full
```

#### Policy Validation Only
```bash
./scripts/test-infrastructure.sh policy-only
```

#### Manual Terratest Execution
```bash
cd terraform/tests
go test -v -timeout 30m ./...
```

## Test Coverage

### Infrastructure Components
- ✅ OpenStack VM provisioning
- ✅ Security group configuration
- ✅ Floating IP assignment
- ✅ Storage volume management
- ✅ Network connectivity
- ✅ Service deployment validation

### Service Health Checks
- ✅ GitLab SCM (Port 8090)
- ✅ Nexus Repository (Port 8081)
- ✅ Keycloak IAM (Port 8180)
- ✅ Rancher K8s (Port 8443)
- ✅ NGINX Proxy (Port 80)
- ✅ Kafka Broker (Port 9092)
- ✅ Redis Cache (Port 6379)

### Monitoring Stack Validation
- ✅ Prometheus metrics collection
- ✅ Grafana dashboard access
- ✅ Jaeger distributed tracing
- ✅ Alertmanager notification system

### Security & Compliance
- ✅ SSH key management policies
- ✅ TLS/HTTPS enforcement
- ✅ Resource tagging compliance
- ✅ Pod security standards
- ✅ Container image security
- ✅ Network security policies

## Test Execution Flow

1. **Prerequisite Check**: Validates Go, Terraform, and OpenStack credentials
2. **Environment Setup**: Initializes test dependencies and Terraform configuration
3. **Policy Validation**: Runs OPA policy tests for compliance verification
4. **Infrastructure Deployment**: Provisions test infrastructure using Terraform
5. **Service Validation**: Tests service endpoints and health checks
6. **Monitoring Validation**: Verifies monitoring and observability stack
7. **Cleanup**: Destroys test infrastructure (configurable)
8. **Report Generation**: Creates comprehensive test reports

## Configuration

### Test Environment Variables
```bash
# Override default test configuration
export TEST_TIMEOUT="45m"                    # Test execution timeout
export TEST_PARALLEL="2"                     # Parallel test execution
export TEST_ENVIRONMENT_NAME="test"          # Test environment identifier
export TEST_SKIP_CLEANUP="false"             # Skip infrastructure cleanup
```

### Terraform Test Variables
```bash
# terraform/tests/terraform.tfvars
environment_name       = "test"
image_name            = "ubuntu-20.04"
flavor_name           = "m1.medium"
external_network_name = "public"
```

## Policy Framework

### Terraform Policies
The framework enforces infrastructure security and compliance through OPA policies:

```rego
# Example: SSH key requirement
ssh_key_required {
    some resource
    input.resource_changes[resource].type == "openstack_compute_keypair_v2"
    input.resource_changes[resource].change.after.name != ""
}
```

### Kubernetes Policies
Enforces container and pod security standards:

```rego
# Example: Container image security
image_security_compliant {
    container := input.spec.containers[_]
    not startswith(container.image, "latest")
    not contains(container.image, ":")
}
```

## Continuous Integration

### GitHub Actions Integration
```yaml
- name: Run Infrastructure Tests
  run: |
    ./scripts/test-infrastructure.sh full
  env:
    OS_AUTH_URL: ${{ secrets.OS_AUTH_URL }}
    OS_USERNAME: ${{ secrets.OS_USERNAME }}
    OS_PASSWORD: ${{ secrets.OS_PASSWORD }}
```

### GitLab CI Integration
```yaml
infrastructure_tests:
  stage: test
  script:
    - ./scripts/test-infrastructure.sh full
  variables:
    TEST_TIMEOUT: "45m"
```

## Troubleshooting

### Common Issues

1. **OpenStack Authentication Failures**
   - Verify credentials are correctly set
   - Check network connectivity to OpenStack endpoint
   - Validate user permissions for resource creation

2. **Test Timeouts**
   - Increase TEST_TIMEOUT environment variable
   - Check OpenStack resource quotas
   - Verify network connectivity between resources

3. **Policy Validation Failures**
   - Review policy rules in `policy/` directories
   - Check Terraform plan output for compliance
   - Validate OPA installation and version

### Debug Mode
Enable debug logging:
```bash
export TF_LOG=DEBUG
export TERRATEST_LOG_LEVEL=DEBUG
./scripts/test-infrastructure.sh full
```

## Reporting

### Test Reports
- **Console Output**: Real-time test execution feedback
- **Log Files**: Detailed execution logs in `logs/testing/`
- **HTML Reports**: Comprehensive test results with timestamps
- **JUnit XML**: CI/CD integration compatible reports

### Metrics and Monitoring
Test execution metrics are collected and can be integrated with:
- Prometheus for test execution monitoring
- Grafana dashboards for test result visualization
- AlertManager for test failure notifications

## Best Practices

### Test Development
1. Use table-driven tests for multiple scenarios
2. Implement proper cleanup mechanisms
3. Add retry logic for flaky infrastructure operations
4. Use meaningful test names and descriptions

### Policy Development
1. Write clear, maintainable Rego policies
2. Include comprehensive test coverage for policies
3. Document policy intent and requirements
4. Version control policy changes

### Infrastructure Testing
1. Test both positive and negative scenarios
2. Validate security configurations
3. Include performance benchmarks
4. Test disaster recovery procedures

## Contributing

When adding new tests or policies:

1. Follow the existing code structure and conventions
2. Add comprehensive test coverage
3. Update documentation
4. Test locally before submitting changes
5. Include both unit and integration tests

## Support

For issues and questions:
- Review test logs in `logs/testing/`
- Check policy validation output
- Verify OpenStack environment configuration
- Consult Terratest documentation for advanced scenarios