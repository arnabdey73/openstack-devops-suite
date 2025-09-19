# Enterprise OpenStack DevOps Platform

![Implementation Status](https://img.shields.io/badge/Implementation-Complete-brightgreen?style=for-the-badge)
![Architecture](https://img.shields.io/badge/Architecture-Enterprise%20Grade-orange?style=for-the-badge)
![Deployment](https://img.shields.io/badge/Deployment-Hybrid%20(VM%20%2B%20K8s)-blue?style=for-the-badge)
![Observability](https://img.shields.io/badge/Observability-Full%20Stack-purple?style=for-the-badge)

A comprehensive enterprise-grade DevOps platform built on VMware OpenStack with complete observability and modernization capabilities. This solution provides a Jenkins CI/CD ecosystem with Gitea self-hosted Git repositories, enhanced with enterprise monitoring, centralized logging, and scalable artifact management. The architecture separates source control management (Gitea) from continuous integration (Jenkins) for better scalability and maintenance.

## 🚀 Enterprise Features

### 🏗️ Core Infrastructure

- 🏗️ Infrastructure as Code with Terraform (VMware OpenStack optimized)  
- 🔧 **Jenkins CI/CD Server** - Modern automation and pipeline management
- 🗃️ **Gitea Self-Hosted Git** - Lightweight, fast Git repository hosting
- 🌐 **NGINX API Gateway** - Centralized routing, rate limiting, SSL termination, and load balancing
- ☸️ Kubernetes orchestration with Rancher
- 📦 Artifact and Docker registry with Nexus
- 🔐 Centralized identity management with Keycloak
- 💬 Messaging system with Kafka
- 🧠 Cache store with Redis

### 📊 Enterprise Observability Stack

- 🔍 **Prometheus + Grafana** - Comprehensive metrics and monitoring
- 📋 **ELK Stack** - Centralized logging and analysis (Elasticsearch, Logstash, Kibana)
-  **Alertmanager** - Intelligent alerting and notification management
- 📈 **Node Exporter** - Infrastructure metrics collection

### 🔒 Security & Compliance

- 🛡️ **HashiCorp Vault** - Centralized secrets management and encryption
- 🔐 **Multi-Auth Support** - LDAP, AppRole, Kubernetes, JWT authentication
-  **OPA Policies** - Policy-as-code compliance and governance
- 🔒 **SSL/TLS Management** - Automated certificate management and PKI

### 🔄 Modern DevOps Automation

- 🧪 **Terratest** - Infrastructure testing and validation framework
- 🔀 **CI/CD Integration** - Seamless Jenkins pipeline automation
- 📈 **Performance Testing** - Load testing with JMeter and Locust
- 🚀 **Deployment Automation** - Zero-downtime deployments and rollbacks

### 🔮 Future Feature Extensions

The following components can be added as future enhancements:

- 🕸️ **Jaeger** - Distributed tracing and microservices observability
- 🎯 **ArgoCD GitOps** - Declarative continuous delivery and application lifecycle
- 🛡️ **OWASP ZAP** - Automated security vulnerability scanning
- � **Kong API Gateway** - Enterprise traffic management and routing

## 🏗️ Enterprise Architecture

**Infrastructure Layer (Terraform + Terratest):**

- VMware OpenStack VM provisioning with optimizations
- Security group and network configuration with compliance policies
- VMware Tools integration and performance tuning
- State management with drift detection and automated remediation
- Infrastructure testing and validation with Go-based Terratest framework

**Configuration Layer (Ansible + Enterprise Automation):**

- Service installation with enterprise-grade configurations
- VMware environment optimization and monitoring
- Application deployment with zero-downtime strategies
- System hardening and compliance automation
- Secrets management integration with HashiCorp Vault

**Observability Layer (Full Stack Monitoring):**

- Prometheus metrics collection with comprehensive service discovery
- Grafana dashboards with enterprise-grade visualizations
- ELK Stack centralized logging with automated log parsing
- Alertmanager intelligent alerting with multi-channel notifications

**Security Layer (DevSecOps Integration):**

- HashiCorp Vault centralized secrets management
- OWASP ZAP automated security vulnerability scanning
- OPA policy-as-code compliance and governance
- Multi-authentication methods (LDAP, JWT, AppRole, Kubernetes)
- SSL/TLS automation with PKI certificate management

**CI/CD Layer (Modern Deployment):**

- Jenkins CI/CD pipelines with Gitea integration and enterprise workflows
- Infrastructure provisioning automation with approval gates
- Configuration management with GitOps principles
- Service health verification and automated rollback capabilities

## 📦 Enterprise Roles

| Role                    | Purpose                                    | Technology Stack         |
|------------------------|--------------------------------------------|-------------------------|
| `openstack_vm`         | Creates and manages VMs in OpenStack      | Terraform + Ansible     |
| `jenkins_ci`           | Deploys Jenkins CI/CD Server              | Jenkins + Java           |
| `rancher_k8s`          | Installs Rancher & bootstraps K8s         | Rancher + Docker         |
| `nexus_repo`           | Sets up Nexus OSS repository              | Nexus OSS                |
| `keycloak_iam`         | Configures Keycloak for IAM               | Keycloak + PostgreSQL    |
| `kafka_broker`         | Deploys Kafka and manages topics          | Apache Kafka             |
| `redis_cache`          | Sets up Redis for caching                 | Redis + Sentinel         |
| `nginx_proxy`          | Deploys NGINX as reverse proxy            | NGINX + Dashboard        |
| **Enterprise Roles**   | **Purpose**                                | **Technology Stack**     |
| `prometheus_monitoring`| Complete monitoring infrastructure         | Prometheus + Alertmanager|
| `grafana_visualization`| Dashboard and metrics visualization        | Grafana + Enterprise     |
| `elasticsearch_logging`| Centralized logging platform              | ELK Stack (E+L+K)        |
| `vault_secrets`        | Centralized secrets management            | HashiCorp Vault          |

### Removed Components (Available as Future Features)

| Component              | Purpose                                    | Technology Stack         |
|------------------------|--------------------------------------------|-------------------------|
| `jaeger_tracing`       | Distributed tracing system                | Jaeger + OpenTracing     |
| `argocd_gitops`        | GitOps continuous delivery                | ArgoCD + Helm            |
| `security_scanning`    | Automated security testing                | OWASP ZAP + Trivy        |
| `api_gateway`          | Enterprise API gateway                    | Kong + PostgreSQL        |

## 🚀 Enterprise Deployment

### Prerequisites

**Core Requirements:**

- **Terraform** 1.0+ for infrastructure provisioning
- **Ansible** 6.x+ for configuration management  
- **OpenStack** access (API configured)
- **Python** 3.8+ with pip
- **SSH** access to provisioned VMs
- **jq** for JSON processing

**Enterprise Requirements:**

- **Go** 1.21+ for Terratest infrastructure testing
- **Docker** for container management and scanning
- **Vault CLI** for secrets management
- **kubectl** for Kubernetes operations
- **Helm** 3.x+ for GitOps deployments

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

### Enterprise Deployment

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/openstack-devops-suite.git
cd openstack-devops-suite

# Set up OpenStack credentials
source your-openstack-rc.sh

# Set enterprise environment variables
export JENKINS_ADMIN_PASSWORD="YourSecurePassword123!"
export GITEA_ADMIN_PASSWORD="YourSecureGiteaPassword123!"
export VAULT_TOKEN="your-vault-token"
export MONITORING_DOMAIN="monitoring.your-domain.com"

# Deploy the complete enterprise platform
./scripts/deploy.sh deploy

# Deploy with enterprise features
ansible-playbook -i inventory/openstack-hosts.yml playbooks/site.yml
```

### Production-Grade Deployment

```bash
# 1. Infrastructure validation and testing
cd terraform/tests && go test -v

# 2. Policy compliance validation  
cd policy && opa test .

# 3. Deploy with enterprise monitoring
./scripts/deploy.sh deploy --monitoring --security --gitops

# 4. Validate deployment health
./scripts/test-deployment-flow.py --comprehensive

# 5. Access enterprise dashboards (URLs will be displayed)
```

## 📊 Enterprise Dashboards & Access Points

### Core Services

- **Jenkins**: `http://jenkins.your-domain.com` - Primary CI/CD Server
- **Rancher**: `http://rancher.your-domain.com` - Kubernetes management  
- **Nexus**: `http://nexus.your-domain.com` - Artifact repository
- **Keycloak**: `http://keycloak.your-domain.com` - Identity management

### Enterprise Monitoring Stack

- **Grafana**: `http://grafana.your-domain.com` - Unified monitoring dashboards
- **Prometheus**: `http://prometheus.your-domain.com` - Metrics and alerting
- **Kibana**: `http://kibana.your-domain.com` - Centralized log analysis
- **AlertManager**: `http://alerts.your-domain.com` - Alert management

### Security & Secrets Management

- **Vault**: `http://vault.your-domain.com` - Secrets management

## 🔗 Recommended Git Hosting Solutions

Since this suite now uses Jenkins for CI/CD, you'll need to connect it to a Git repository. Here are the recommended open source and hosted Git solutions:

### Open Source Self-Hosted Options

1. **Gitea** - Lightweight, fast, and easy to deploy
   - Minimal resource requirements
   - GitHub-like interface
   - Built-in CI/CD actions support
   - Perfect for small to medium teams

2. **Jenkins CI/CD Server** - Automation and pipeline management
3. **Gitea Self-Hosted Git** - Lightweight Git repository hosting
   - Comprehensive project management
   - Built-in container registry
   - Issue tracking and wiki
   - Suitable for larger organizations

4. **Forgejo** - Community-driven Gitea fork
   - Enhanced privacy features
   - Active community development
   - Compatible with Gitea

### Cloud-Hosted Options

1. **GitHub** - Industry standard with excellent ecosystem
   - Free for public repositories
   - Extensive marketplace and integrations
   - Best-in-class collaboration features

2. **Bitbucket** - Atlassian's Git solution
   - Tight integration with Jira and Confluence
   - Good for teams already using Atlassian tools
   - Competitive pricing

3. **SourceForge** - Classic open source hosting
   - Free for open source projects
   - Long-established platform

### Integration with Jenkins

The Jenkins CI role in this suite can be easily configured to work with any of these Git hosting solutions by:
- Installing appropriate Git plugins
- Configuring webhooks for automatic builds
- Setting up SSH keys or access tokens for repository access

### Enterprise Features

- **📊 50+ Pre-built Grafana Dashboards** - Infrastructure, applications, security metrics
- **🔍 Automated Log Correlation** - ELK stack with intelligent parsing
- **🚨 Multi-Channel Alerting** - Email, Slack, PagerDuty integration  
- **🔒 Zero-Trust Security** - Vault-backed secret rotation and PKI
- **🚀 CI/CD Automation** - Jenkins with comprehensive pipeline management
- **📊 50+ Pre-built Grafana Dashboards** - Infrastructure, applications, security metrics
- **🔍 Automated Log Correlation** - ELK stack with intelligent parsing
- **🚨 Multi-Channel Alerting** - Email, Slack, PagerDuty integration  
- **🔒 Zero-Trust Security** - Vault-backed secret rotation and PKI

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
ansible-playbook -i inventory/terraform-hosts.yml playbooks/gitea.yml
ansible-playbook -i inventory/terraform-hosts.yml playbooks/jenkins.yml

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

## 🔄 Jenkins & Gitea Integration

The suite includes a comprehensive Jenkins CI/CD setup with Gitea integration that automates:

- **Infrastructure Validation**: Terraform syntax and plan validation
- **Configuration Validation**: Ansible playbook syntax checking
- **Automated Deployment**: Infrastructure provisioning and service configuration
- **Health Verification**: Service availability and health checks

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
| **Dashboard** | `http://<api-gateway>/` | Central DevOps dashboard |
| **Gitea** | `http://<api-gateway>/gitea/` | Git SCM, Repository hosting |
| **Jenkins** | `http://<api-gateway>/jenkins/` | CI/CD, Pipeline automation |
| **Nexus** | `http://<api-gateway>/nexus/` | Artifact and package repository |
| **Keycloak** | `http://<api-gateway>/keycloak/` | Identity and access management |
| **Rancher** | `http://<api-gateway>/rancher/` | Kubernetes cluster management |

### Default Credentials

- **Gitea**: Username `gitea`, Password: `$GITEA_ADMIN_PASSWORD` or `ChangeMe123!`
- **Jenkins**: Username `admin`, Password: `$JENKINS_ADMIN_PASSWORD` or `ChangeMe123!`
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

### Gitea & Jenkins Configuration

Customize Gitea settings in `roles/gitea_scm/defaults/main.yml` and Jenkins settings in `roles/jenkins_ci/defaults/main.yml`:
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
# Gitea backup (automated via cron)
gitea dump -c /etc/gitea/app.ini

# Jenkins backup (automated via cron) 
tar -czf /backup/jenkins-$(date +%Y%m%d).tar.gz /var/lib/jenkins/

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

The Jenkins CI/CD pipeline automatically runs tests at different stages:

- **Validation Stage**: Configuration and syntax checks
- **Verify Stage**: Service connectivity and health checks  
- **Performance Stage**: Basic load testing (optional)

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

**Note**: This modernized suite uses Jenkins for CI/CD automation and Gitea for self-hosted Git repositories, providing a lightweight yet powerful DevOps platform. The separation of concerns between SCM (Gitea) and CI/CD (Jenkins) offers better scalability and maintenance. See the [Migration Guide](docs/MIGRATION_GUIDE.md) for detailed implementation steps.
