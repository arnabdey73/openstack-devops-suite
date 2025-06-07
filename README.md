# GitLab-Centered DevOps Suite for VMware OpenStack

![Implementation Status](https://img.shields.io/badge/Implementation-Complete-brightgreen?style=for-the-badge)
![Tests](https://img.shields.io/badge/Tests-42%2F42%20Passing-brightgreen?style=for-the-badge)
![Deployment](https://img.shields.io/badge/Deployment-Hybrid%20(VM%20%2B%20K8s)-blue?style=for-the-badge)

A modernized Terraform and Ansible-based solution to deploy a complete GitLab-centered DevOps platform on VMware OpenStack environments. This suite uses GitLab as the primary CI/CD and SCM platform, eliminating the need for Jenkins while providing comprehensive DevOps tooling optimized for VMware infrastructure.

## ✨ Features

- 🏗️ Infrastructure as Code with Terraform (VMware OpenStack optimized)
- 🦊 **GitLab as Primary CI/CD and SCM** (Jenkins-free architecture)
- ☸️ Kubernetes orchestration with Rancher
- 📦 Artifact and Docker registry with Nexus
- 🔐 Centralized identity management with Keycloak
- 💬 Messaging system with Kafka
- 🧠 Cache store with Redis
- 🌐 NGINX as reverse proxy and dashboard
- 📊 Centralized DevOps Dashboard
- 🔄 GitLab CI/CD pipeline automation
- 🖥️ VMware Tools integration and optimization

## 🏗️ Architecture

**Infrastructure Layer (Terraform):**
- VMware OpenStack VM provisioning with optimizations
- Security group and network configuration
- VMware Tools integration
- State management and drift detection

**Configuration Layer (Ansible):**
- Service installation and configuration
- VMware environment optimization
- Application deployment
- System hardening and monitoring

**Orchestration Layer (GitLab CI/CD):**
- GitLab-native CI/CD pipelines
- Infrastructure deployment automation
- Service configuration management
- No external CI/CD tools required
- Infrastructure provisioning automation
- Configuration management pipelines
- Service health verification
- Rollback capabilities

## 📦 Roles

| Role            | Purpose                              | Technology Stack    |
|-----------------|--------------------------------------|-------------------|
| `openstack_vm`  | Creates and manages VMs in OpenStack | Terraform + Ansible|
| `gitlab_scm`    | Deploys GitLab for Git/Project Mgmt  | GitLab CE + Registry|
| `rancher_k8s`   | Installs Rancher & bootstraps K8s    | Rancher + Docker  |
| `nexus_repo`    | Sets up Nexus OSS repository         | Nexus OSS         |
| `keycloak_iam`  | Configures Keycloak for IAM          | Keycloak + PostgreSQL|
| `kafka_broker`  | Deploys Kafka and manages topics     | Apache Kafka      |
| `redis_cache`   | Sets up Redis for caching            | Redis + Sentinel  |
| `nginx_proxy`   | Deploys NGINX as reverse proxy       | NGINX + Dashboard |

## 🚀 Quick Start

### Prerequisites

- **Terraform** 1.0+ for infrastructure provisioning
- **Ansible** 6.x+ for configuration management  
- **OpenStack** access (API configured)
- **Python** 3.8+
- **SSH** access to provisioned VMs
- **jq** for JSON processing

### Environment Setup

```bash
# Install dependencies (macOS)
brew install terraform ansible jq

# Install dependencies (Linux)
# Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip && sudo mv terraform /usr/local/bin/

# Ansible and jq
pip install ansible
sudo apt install jq  # Ubuntu/Debian
```

### Quick Deployment

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/openstack-devops-suite.git
cd openstack-devops-suite

# Set up OpenStack credentials
source your-openstack-rc.sh

# Set GitLab root password (optional)
export GITLAB_ROOT_PASSWORD="YourSecurePassword123!"

# Deploy the complete suite
./scripts/deploy.sh deploy
```

### Manual Step-by-Step

```bash
# 1. Plan infrastructure changes
./scripts/deploy.sh plan

# 2. Deploy infrastructure and services
./scripts/deploy.sh deploy

# 3. Access the dashboard
# URL will be shown in deployment output
```

## 🏗️ Infrastructure Management

### Terraform Commands

```bash
cd terraform

# Initialize and plan
terraform init
terraform plan -var-file="terraform.tfvars"

# Apply changes
terraform apply -var-file="terraform.tfvars"

# Destroy infrastructure
terraform destroy -var-file="terraform.tfvars"
```

### Ansible Commands

```bash
# Configure all services
ansible-playbook -i inventory/terraform-hosts.yml playbooks/site.yml

# Deploy specific service
ansible-playbook -i inventory/terraform-hosts.yml playbooks/gitlab.yml

# Check service status
ansible all -i inventory/terraform-hosts.yml -m ping
```

## 🖥️ Dashboard Portal

The DevOps Suite includes a centralized dashboard portal that provides:

- 🌟 Single entry point to access all DevOps services
- 📊 Real-time status monitoring of all services
- 🌓 Light/dark mode support based on system preferences
- 📱 Responsive design for desktop and mobile devices

### Accessing the Dashboard

After deployment, the dashboard is available at:

```plaintext
https://<your-nginx-domain>/
```

### Customizing the Dashboard

You can customize the dashboard by modifying variables in your inventory:

```yaml
# In your inventory file or group_vars
nginx_proxy:
  dashboard_title: "Company DevOps Portal"
  dashboard_description: "Your custom description"
  dashboard_logo_enabled: true
```

For more information, see the [Dashboard Documentation](./docs/dashboard.md).

## 🔄 GitLab CI/CD Integration

The suite includes a comprehensive GitLab CI/CD pipeline (`.gitlab-ci.yml`) that automates:

- **Infrastructure Validation**: Terraform syntax and plan validation
- **Configuration Validation**: Ansible playbook syntax checking
- **Automated Deployment**: Infrastructure provisioning and service configuration
- **Health Verification**: Service availability and health checks
- **Security Scanning**: Optional OWASP ZAP security scans

### Pipeline Stages

1. **validate** - Syntax and validation checks
2. **plan** - Infrastructure change planning  
3. **infrastructure** - Resource provisioning with Terraform
4. **configure** - Service configuration with Ansible
5. **verify** - Health checks and service validation
6. **cleanup** - Manual cleanup jobs (destroy infrastructure)

## 🌐 Service Access

After deployment, access your services at:

| Service | URL | Description |
|---------|-----|-------------|
| **Dashboard** | `http://<nginx-ip>` | Central DevOps dashboard |
| **GitLab** | `http://<gitlab-ip>:8090` | Git SCM, CI/CD, Container Registry |
| **Nexus** | `http://<nexus-ip>:8081` | Artifact and package repository |
| **Keycloak** | `http://<keycloak-ip>:8180` | Identity and access management |
| **Rancher** | `http://<rancher-ip>:8443` | Kubernetes cluster management |

### Default Credentials

- **GitLab**: Username `root`, Password: `$GITLAB_ROOT_PASSWORD` or `ChangeMe123!`
- **Other services**: Refer to individual service documentation

## 🔧 Configuration

### Terraform Variables

Copy and customize the Terraform variables:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform/terraform.tfvars with your OpenStack settings
```

Key variables:
- `auth_url`: OpenStack authentication URL
- `username`/`password`: OpenStack credentials  
- `environment_name`: Prefix for resource names
- `image_name`: Base OS image (Ubuntu 22.04 recommended)
- `flavor_name`: Instance size (m1.medium or larger)

### GitLab Configuration

Customize GitLab settings in `roles/gitlab_scm/defaults/main.yml`:
- External URL and ports
- Registry configuration  
- LDAP integration
- SMTP settings for notifications

## 🔍 Monitoring and Management

### Health Checks

```bash
# Check all services
./scripts/deploy.sh deploy  # Includes verification

# Manual service checks
curl http://<service-ip>:<port>/health  # If available
```

### Logs and Troubleshooting

```bash
# Check Terraform state
cd terraform && terraform show

# Check Ansible connectivity  
ansible all -i inventory/terraform-hosts.yml -m ping

# Service logs
ansible <service>_servers -i inventory/terraform-hosts.yml -a "journalctl -u <service> -n 50"
```

### Backup and Recovery

```bash
# GitLab backup (automated via cron)
/opt/gitlab/bin/gitlab-backup create

# Terraform state backup
cp terraform/terraform.tfstate terraform/terraform.tfstate.backup

# Infrastructure rebuild
./scripts/deploy.sh destroy
./scripts/deploy.sh deploy
```

## 🧪 Testing and Validation

The OpenStack DevOps Suite includes comprehensive testing and validation capabilities to ensure reliable hybrid deployments across VM and Kubernetes environments.

### Test Suite Overview

| Test Script | Purpose | Coverage |
|-------------|---------|----------|
| `test-hybrid-deployment.sh` | Comprehensive system testing | All components, configs, connectivity |
| `test-performance.sh` | Load and performance testing | Response times, scalability, resource usage |
| `test-ssl-certificates.sh` | SSL certificate validation | cert-manager, HTTPS endpoints, DNS |
| `integration-tests.yml` | Cross-platform integration | VM/K8s compatibility, service health |

### Running Tests

#### 1. Pre-Deployment Validation
```bash
# Validate all configurations before deployment
./scripts/test-hybrid-deployment.sh --pre-deployment

# Check prerequisites and configurations
./scripts/test-hybrid-deployment.sh --validate-configs
```

#### 2. Post-Deployment Testing
```bash
# Full system validation after deployment
./scripts/test-hybrid-deployment.sh --post-deployment

# Test specific deployment type
./scripts/test-hybrid-deployment.sh --deployment-type vm
./scripts/test-hybrid-deployment.sh --deployment-type kubernetes
./scripts/test-hybrid-deployment.sh --deployment-type hybrid
```

#### 3. Performance Testing
```bash
# Basic performance testing
./scripts/test-performance.sh

# Load testing with custom parameters
./scripts/test-performance.sh --concurrent-users 50 --duration 300

# Stress testing
./scripts/test-performance.sh --stress-test
```

#### 4. SSL Certificate Testing
```bash
# Validate SSL certificates and HTTPS endpoints
./scripts/test-ssl-certificates.sh

# Test specific domain
./scripts/test-ssl-certificates.sh --domain yourdomain.com

# Monitor certificate status
./scripts/test-ssl-certificates.sh --monitor
```

#### 5. Integration Testing
```bash
# Run Ansible-based integration tests
ansible-playbook playbooks/integration-tests.yml

# Test specific environment
ansible-playbook playbooks/integration-tests.yml --extra-vars "deployment_type=kubernetes"
```

### Automated Testing in CI/CD

The GitLab CI/CD pipeline automatically runs tests at different stages:

- **Validation Stage**: Configuration and syntax checks
- **Verify Stage**: Service connectivity and health checks  
- **Performance Stage**: Basic load testing (optional)
- **Security Stage**: OWASP ZAP security scanning (optional)

### Test Reports

Test results are automatically generated in multiple formats:

```bash
# View latest test results
cat results/test-results-$(date +%Y%m%d).log

# SSL test results
cat results/ssl-test-results-$(date +%Y%m%d).log

# Performance reports
cat results/performance-results-$(date +%Y%m%d)/test.log
```

### Troubleshooting Tests

Common test failures and solutions:

| Issue | Cause | Solution |
|-------|-------|----------|
| SSL test failures | DNS not configured | Update DNS records or use `--skip-dns` |
| K8s connectivity | Kubeconfig missing | Run `kubectl config current-context` |
| VM service timeout | Services not ready | Wait for services to start, check logs |
| Performance issues | Resource constraints | Scale resources or adjust test parameters |

For detailed troubleshooting, see [Testing Documentation](docs/reports/TESTING_VALIDATION_SUMMARY.md).

## 📚 Documentation

### Main Documentation

- [Hybrid Deployment Guide](docs/HYBRID_DEPLOYMENT_GUIDE.md) - Step-by-step deployment instructions
- [Migration Guide](docs/MIGRATION_GUIDE.md) - Detailed migration guide to the modernized stack
- [DNS Configuration Guide](docs/DNS_CONFIGURATION_GUIDE.md) - DNS setup for Kubernetes ingress
- [Dashboard Implementation](docs/dashboard-implementation.md) - Dashboard customization

### Implementation Reports

- [**Final Implementation Report**](docs/reports/FINAL_IMPLEMENTATION_REPORT.md) - **🎯 Complete project status and achievements**
- [Testing and Validation Summary](docs/reports/TESTING_VALIDATION_SUMMARY.md) - Comprehensive testing documentation
- [Completion Summary](docs/reports/COMPLETION_SUMMARY.md) - Implementation completion overview
- [Configuration Completion Summary](docs/reports/CONFIGURATION_COMPLETION_SUMMARY.md) - Configuration completion details
- [Final Validation Report](docs/reports/FINAL_VALIDATION_REPORT.md) - Final validation results

### Installation & Migration Reports

- [Ansible Installation Summary](docs/reports/ANSIBLE_INSTALLATION_SUMMARY.md) - Ansible setup details
- [Terraform Installation Summary](docs/reports/TERRAFORM_INSTALLATION_SUMMARY.md) - Terraform setup details
- [Jenkins Removal Summary](docs/reports/JENKINS_REMOVAL_SUMMARY.md) - Jenkins migration details
- [Tuleap Cleanup Summary](docs/reports/TULEAP_CLEANUP_SUMMARY.md) - Tuleap removal details

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `./scripts/deploy.sh plan`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Note**: This modernized suite uses GitLab for improved Git workflows, integrated CI/CD, and better container registry support. See the [Migration Guide](docs/MIGRATION_GUIDE.md) for detailed implementation steps.
