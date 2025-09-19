# DevOps Suite Modernization Guide

This guide outlines the modernization of the OpenStack DevOps Suite, replacing the previous Ansible-only approach with a modern Infrastructure as Code (IaC) and Configuration Management setup.

## 🔄 Migration Overview

### What Changed

| **Before** | **After** | **Benefits** |
|------------|-----------|-------------|
| Ansible-only deployment | Terraform + Ansible | Infrastructure as Code, state management |
| Manual SCM | GitLab CE | Modern Git workflows, integrated CI/CD |
| Manual orchestration | GitLab CI/CD pipelines | Automated deployment, rollback capabilities |
| Single-tool approach | Best-of-breed tools | Each tool optimized for its purpose |

### Architecture Evolution

```
Old Architecture:
┌─────────────┐
│   Ansible   │ ──→ OpenStack ──→ Configure Everything
└─────────────┘

New Architecture:
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Terraform  │ ──→│ OpenStack   │    │   Ansible   │
│ (Provision) │    │(Infra Layer)│ ──→│ (Configure) │
└─────────────┘    └─────────────┘    └─────────────┘
                            │
                    ┌─────────────┐
                    │ GitLab CI/CD│
                    │(Orchestrate)│
                    └─────────────┘
```

## 🚀 Getting Started

### Prerequisites

1. **Terraform** (>= 1.0)
   ```bash
   # macOS
   brew install terraform
   
   # Linux
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

2. **Ansible** (>= 6.x)
   ```bash
   pip install ansible
   ```

3. **OpenStack CLI** (configured)
   ```bash
   pip install python-openstackclient
   source openstack-rc.sh  # Your OpenStack credentials
   ```

4. **jq** (for JSON processing)
   ```bash
   # macOS
   brew install jq
   
   # Linux
   sudo apt install jq
   ```

### Quick Deployment

```bash
# Clone the repository
git clone <repository-url>
cd openstack-devops-suite

# Set up environment
export GITLAB_ROOT_PASSWORD="YourSecurePassword123!"
source your-openstack-rc.sh

# Deploy everything
./scripts/deploy.sh deploy
```

### Step-by-Step Deployment

1. **Plan Infrastructure**
   ```bash
   ./scripts/deploy.sh plan
   ```

2. **Deploy Infrastructure and Services**
   ```bash
   ./scripts/deploy.sh deploy
   ```

3. **Access Services**
   - Dashboard: `http://<nginx-ip>`
   - GitLab: `http://<gitlab-ip>:8090` (Primary CI/CD and SCM)

## 📁 Directory Structure

```
openstack-devops-suite/
├── terraform/                 # Infrastructure as Code
│   ├── main.tf               # Main Terraform configuration
│   ├── variables.tf          # Input variables
│   ├── outputs.tf            # Output values
│   └── templates/            # Terraform templates
├── roles/                    # Ansible roles
│   ├── gitlab_scm/           # GitLab role for Git SCM and CI/CD
│   └── ...                   # Other service roles
├── playbooks/                # Ansible playbooks
│   ├── site.yml              # Main deployment playbook
│   ├── gitlab.yml            # GitLab deployment
│   └── ...                   # Individual service playbooks
├── .gitlab-ci.yml            # GitLab CI/CD pipeline
└── scripts/
    └── deploy.sh             # Deployment orchestration script
```

## 🔧 Configuration

### Terraform Variables

Edit `terraform/terraform.tfvars`:

```hcl
# OpenStack Configuration
auth_url             = "https://your-openstack:5000/v3"
username             = "your-username"
password             = "your-password"
project_name         = "your-project"

# Infrastructure Settings
environment_name        = "devops"
image_name             = "Ubuntu 22.04"
flavor_name            = "m1.medium"
external_network_name  = "public"
```

### GitLab Configuration

The GitLab role supports extensive configuration:

```yaml
# In roles/gitlab_scm/defaults/main.yml
gitlab_external_url: "http://{{ ansible_default_ipv4.address }}:8090"
gitlab_root_password: "ChangeMe123!"
gitlab_registry_enable: true
gitlab_pages_enabled: false
```

## 🔄 Jenkins CI/CD Pipeline

The included `Jenkinsfile` provides:

- **Validation**: Terraform and Ansible syntax checking
- **Planning**: Infrastructure change planning
- **Deployment**: Automated infrastructure provisioning and configuration
- **Verification**: Service health checks

### Pipeline Stages

1. **validate**: Syntax checking and validation
2. **plan**: Infrastructure planning
3. **infrastructure**: Resource provisioning
4. **configure**: Service configuration
5. **verify**: Health checks and validation
6. **cleanup**: Manual cleanup jobs

## 🔍 Monitoring and Management

### Service Endpoints

After deployment, services are available at:

- **Dashboard**: `http://<nginx-ip>` - Central dashboard
- **GitLab**: `http://<gitlab-ip>:8090` - Git SCM and CI/CD (Primary Platform)
- **Nexus**: `http://<nexus-ip>:8081` - Artifact repository
- **Keycloak**: `http://<keycloak-ip>:8180` - Identity management
- **Rancher**: `http://<rancher-ip>:8443` - Kubernetes management

### Health Monitoring

The deployment script includes verification steps:

```bash
# Check all services
./scripts/deploy.sh deploy

# Services are automatically verified during deployment
```

## 🛠️ Troubleshooting

### Common Issues

1. **Terraform State Issues**
   ```bash
   cd terraform
   terraform refresh
   terraform plan
   ```

2. **Ansible Connection Issues**
   ```bash
   ansible all -i inventory/terraform-hosts.yml -m ping
   ```

3. **Service Not Starting**
   ```bash
   # Check service logs
   ansible <service>_servers -i inventory/terraform-hosts.yml -a "systemctl status <service>"
   ```

### Rollback Procedures

1. **Configuration Rollback**
   ```bash
   # Re-run specific playbook
   ansible-playbook -i inventory/terraform-hosts.yml playbooks/<service>.yml
   ```

2. **Infrastructure Rollback**
   ```bash
   cd terraform
   terraform plan -destroy
   terraform destroy
   ```

## 🔄 Migration from Old Setup

### GitLab Setup and Configuration

1. **Export Legacy Data**
   - Export Git repositories from legacy systems
   - Export project data and documentation
   - Export user accounts and permissions

2. **Import to GitLab**
   - Create projects in GitLab
   - Import Git repositories
   - Configure users and permissions

3. **Update CI/CD Pipelines**
   - Migrate to GitLab CI/CD
   - Update webhook configurations
   - Test automated builds

### Ansible Role Updates

The modernized setup uses `gitlab_scm` for Git SCM management:

```diff
- roles:
-   - legacy_scm
+ roles:
+   - gitlab_scm
```

## 🚀 Next Steps

1. **Customize Configuration**: Adapt variables to your environment
2. **Set Up Monitoring**: Configure additional monitoring tools
3. **Enable SSL**: Configure SSL certificates for production
4. **Backup Strategy**: Implement automated backups
5. **Security Hardening**: Apply security best practices

## 📚 Additional Resources

- [Terraform OpenStack Provider](https://registry.terraform.io/providers/terraform-provider-openstack/openstack)
- [GitLab CE Documentation](https://docs.gitlab.com/ce/)
- [Ansible OpenStack Collection](https://docs.ansible.com/ansible/latest/collections/openstack/cloud/)

---

For questions or issues, please refer to the project documentation or open an issue in the repository.
