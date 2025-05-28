# OpenStack DevOps Suite

A modular Ansible-based library to deploy a complete DevOps and developer platform on OpenStack. This suite provisions and configures core components like Jenkins, Tuleap, Rancher, Nexus, Keycloak, Kafka, Redis, and NGINX—ideal for private cloud environments.

## ✨ Features

- ✅ Automated provisioning of VMs in OpenStack
- ⚙️ CI/CD with Jenkins
- 🔁 Git SCM and project management with Tuleap
- ☸️ Kubernetes orchestration with Rancher
- 📦 Artifact and Docker registry with Nexus
- 🔐 Centralized identity management with Keycloak
- 💬 Messaging system with Kafka
- 🧠 Cache store with Redis
- 🌐 NGINX as a reverse proxy or static content host

## 📦 Roles

| Role            | Purpose                              |
|-----------------|--------------------------------------|
| `openstack_vm`  | Creates and manages VMs in OpenStack |
| `jenkins_ci`    | Installs and configures Jenkins      |
| `tuleap_git`    | Deploys Tuleap for Git/Project Mgmt  |
| `rancher_k8s`   | Installs Rancher & bootstraps K8s    |
| `nexus_repo`    | Sets up Nexus OSS repository         |
| `keycloak_iam`  | Configures Keycloak for IAM          |
| `kafka_broker`  | Deploys Kafka and manages topics     |
| `redis_cache`   | Sets up Redis for caching            |
| `nginx_proxy`   | Deploys NGINX as reverse proxy       |

## 🚀 Quick Start

### Prerequisites

- OpenStack access (API or CLI configured)
- Python 3.8+
- Ansible 6.x or higher
- SSH access to provisioned VMs

### Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/openstack-devops-suite.git
cd openstack-devops-suite
