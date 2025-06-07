# Hybrid Deployment Guide - VM + Kubernetes Support

## Overview

The OpenStack DevOps Suite now supports hybrid deployment to both traditional VM environments and modern Kubernetes clusters. This enables flexibility in deployment strategies while maintaining compatibility with existing infrastructure.

## Architecture Options

### 1. VM-Only Deployment (Traditional)
- **Infrastructure**: OpenStack VMs via Terraform
- **Networking**: NGINX reverse proxy with floating IPs
- **SSL**: Optional Let's Encrypt via certbot
- **Services**: Direct deployment on VMs

### 2. Kubernetes-Only Deployment (Cloud-Native)
- **Infrastructure**: Kubernetes cluster (any provider)
- **Networking**: Ingress Controller with LoadBalancer
- **SSL**: Automatic Let's Encrypt via cert-manager
- **Services**: Containerized deployments

### 3. Hybrid Deployment (Recommended)
- **Infrastructure**: Both VMs and Kubernetes
- **Networking**: Dual access methods
- **SSL**: Both traditional and modern approaches
- **Services**: Gradual migration path

## Prerequisites

### Common Requirements
- **Git**: Version control
- **Ansible** >= 6.x: Configuration management
- **kubectl**: Kubernetes CLI
- **Helm** >= 3.x: Kubernetes package manager
- **jq**: JSON processing

### VM Deployment Requirements
- **Terraform** >= 1.0: Infrastructure as Code
- **OpenStack**: Access credentials and endpoint
- **SSH**: Key-based authentication
- **Python** >= 3.8: OpenStack SDK

### Kubernetes Deployment Requirements
- **Kubernetes Cluster**: Running cluster with admin access
- **Ingress Controller**: NGINX Ingress (auto-installed if missing)
- **cert-manager**: SSL certificate automation (auto-installed)
- **LoadBalancer**: External IP provisioning capability

## Quick Start

### 1. Clone and Setup
```bash
git clone <repository-url>
cd openstack-devops-suite

# Set required environment variables
export DOMAIN_NAME="yourdomain.com"
export LETSENCRYPT_EMAIL="admin@yourdomain.com"
export GITLAB_ROOT_PASSWORD="YourSecurePassword123!"
```

### 2. Choose Deployment Method

#### Option A: Hybrid Deployment (VM + Kubernetes)
```bash
export ENABLE_VMS=true
export ENABLE_KUBERNETES=true
./scripts/deploy-hybrid.sh deploy
```

#### Option B: Kubernetes Only
```bash
./scripts/deploy-hybrid.sh k8s-only
```

#### Option C: VMs Only (Traditional)
```bash
./scripts/deploy-hybrid.sh vm-only
```

## Detailed Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_VMS` | `true` | Deploy VM infrastructure |
| `ENABLE_KUBERNETES` | `false` | Deploy to Kubernetes |
| `ENABLE_SSL` | `true` | Enable SSL certificates |
| `DOMAIN_NAME` | `yourdomain.com` | Domain for services |
| `LETSENCRYPT_EMAIL` | _(required)_ | Email for SSL certificates |
| `AUTO_APPROVE` | `false` | Auto-approve Terraform changes |
| `ENVIRONMENT_NAME` | `production` | Environment prefix |

### DNS Configuration

For Kubernetes deployments, configure these DNS records:

```dns
gitlab.yourdomain.com      A    <ingress-lb-ip>
dashboard.yourdomain.com   A    <ingress-lb-ip>
rancher.yourdomain.com     A    <ingress-lb-ip>
keycloak.yourdomain.com    A    <ingress-lb-ip>
nexus.yourdomain.com       A    <ingress-lb-ip>
docker.yourdomain.com      A    <ingress-lb-ip>
```

Get the Ingress LoadBalancer IP:
```bash
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller
```

### SSL Certificate Configuration

#### Automatic (Kubernetes with cert-manager)
```yaml
# Automatic SSL certificates via Let's Encrypt
letsencrypt_email: "admin@yourdomain.com"
enable_ssl_certificates: true
```

#### Manual (VM deployments)
```bash
# Configure in group_vars or inventory
nginx_ssl_enabled: true
nginx_ssl_cert_path: "/etc/letsencrypt/live/domain/fullchain.pem"
nginx_ssl_key_path: "/etc/letsencrypt/live/domain/privkey.pem"
```

## Service Access

### VM-Based Services
| Service | URL | Port | Description |
|---------|-----|------|-------------|
| Dashboard | `http://<nginx-ip>` | 80 | Central DevOps portal |
| GitLab | `http://<gitlab-ip>:8090` | 8090 | Primary CI/CD & SCM |
| Nexus | `http://<nexus-ip>:8081` | 8081 | Artifact repository |
| Keycloak | `http://<keycloak-ip>:8180` | 8180 | Identity management |
| Rancher | `https://<rancher-ip>:8443` | 8443 | Kubernetes management |

### Kubernetes Services
| Service | URL | Description |
|---------|-----|-------------|
| Dashboard | `https://dashboard.yourdomain.com` | Central DevOps portal |
| GitLab | `https://gitlab.yourdomain.com` | Primary CI/CD & SCM |
| Nexus | `https://nexus.yourdomain.com` | Artifact repository |
| Docker Registry | `https://docker.yourdomain.com` | Container registry |
| Keycloak | `https://keycloak.yourdomain.com` | Identity management |
| Rancher | `https://rancher.yourdomain.com` | Kubernetes management |

## Advanced Usage

### Custom Kubernetes Configuration

Edit `roles/k8s_deployment/defaults/main.yml`:

```yaml
# Custom domain and SSL configuration
domain_name: "mycompany.com"
letsencrypt_email: "devops@mycompany.com"

# Ingress controller customization
ingress_controller:
  values:
    controller:
      service:
        type: "LoadBalancer"
        annotations:
          service.beta.kubernetes.io/aws-load-balancer-type: "nlb"  # AWS
          # service.beta.kubernetes.io/openstack-internal-load-balancer: "true"  # OpenStack

# Resource limits
resource_limits:
  default_memory: "1Gi"
  default_cpu: "1000m"
```

### VM Infrastructure Customization

Edit `terraform/terraform.tfvars`:

```hcl
# OpenStack Configuration
auth_url = "https://your-openstack:5000/v3"
username = "your-username"
password = "your-password"
project_name = "your-project"

# Infrastructure Settings
environment_name = "devops-prod"
image_name = "Ubuntu 22.04"
flavor_name = "m1.large"

# Enable hybrid deployment
enable_kubernetes_deployment = true
domain_name = "mycompany.com"
enable_ssl_certificates = true
letsencrypt_email = "devops@mycompany.com"
```

### GitLab CI/CD Integration

The hybrid deployment supports GitLab CI/CD automation:

```yaml
# .gitlab-ci.yml
variables:
  DEPLOYMENT_TYPE: "hybrid"  # or "kubernetes" or "vm"
  DOMAIN_NAME: "mycompany.com"
  ENABLE_VMS: "true"
  ENABLE_KUBERNETES: "true"

# Use the provided hybrid deployment job
include:
  - local: '.gitlab-ci.yml'
```

## Troubleshooting

### Common Issues

#### 1. Kubernetes Connectivity
```bash
# Check cluster access
kubectl cluster-info

# Check current context
kubectl config current-context

# List available contexts
kubectl config get-contexts
```

#### 2. SSL Certificate Issues
```bash
# Check certificate status (Kubernetes)
kubectl get certificates -n devops-suite

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Manual certificate request
kubectl describe certificaterequest -n devops-suite
```

#### 3. Ingress Controller Issues
```bash
# Check ingress controller status
kubectl get pods -n ingress-nginx

# Check ingress resources
kubectl get ingress -n devops-suite

# Check service endpoints
kubectl get endpoints -n devops-suite
```

#### 4. VM Deployment Issues
```bash
# Check Terraform state
cd terraform && terraform show

# Test Ansible connectivity
ansible all -m ping -i inventory/openstack-hosts.yml

# Check OpenStack credentials
openstack server list
```

### Debugging Commands

```bash
# Check deployment status
./scripts/deploy-hybrid.sh status

# Verify Kubernetes resources
kubectl get all -n devops-suite
kubectl get ingress -n devops-suite
kubectl get certificates -n devops-suite

# Test service connectivity
curl -I https://gitlab.yourdomain.com
curl -I https://dashboard.yourdomain.com

# Check DNS resolution
nslookup gitlab.yourdomain.com
dig gitlab.yourdomain.com
```

### Recovery Procedures

#### Kubernetes Recovery
```bash
# Reinstall ingress controller
helm uninstall nginx-ingress -n ingress-nginx
kubectl delete namespace ingress-nginx
./scripts/deploy-hybrid.sh k8s-only

# Reinstall cert-manager
helm uninstall cert-manager -n cert-manager
kubectl delete namespace cert-manager
./scripts/deploy-hybrid.sh k8s-only
```

#### VM Recovery
```bash
# Redeploy specific service
ansible-playbook -i inventory/openstack-hosts.yml playbooks/gitlab.yml

# Full VM redeployment
./scripts/deploy-hybrid.sh vm-only
```

## Migration Strategies

### From VM-Only to Hybrid

1. **Current VM deployment**:
   ```bash
   ./scripts/deploy.sh deploy  # Traditional deployment
   ```

2. **Add Kubernetes support**:
   ```bash
   export ENABLE_KUBERNETES=true
   ./scripts/deploy-hybrid.sh deploy
   ```

3. **Gradual migration**:
   - Start with new services on Kubernetes
   - Migrate existing services over time
   - Maintain dual access during transition

### From VM-Only to Kubernetes-Only

1. **Backup data from VMs**:
   ```bash
   # GitLab backup
   ansible gitlab_servers -i inventory/openstack-hosts.yml -a "gitlab-backup create"
   
   # Download backups
   ansible gitlab_servers -i inventory/openstack-hosts.yml -m fetch \
     -a "src=/var/opt/gitlab/backups/ dest=./backups/"
   ```

2. **Deploy to Kubernetes**:
   ```bash
   ./scripts/deploy-hybrid.sh k8s-only
   ```

3. **Restore data**:
   ```bash
   # Upload backups to Kubernetes GitLab
   kubectl cp backups/ devops-suite/gitlab-pod:/var/opt/gitlab/backups/
   
   # Restore GitLab
   kubectl exec -n devops-suite gitlab-pod -- gitlab-backup restore
   ```

4. **Destroy VMs**:
   ```bash
   ./scripts/deploy-hybrid.sh destroy
   ```

## Monitoring and Maintenance

### Health Checks

```bash
# Overall deployment status
./scripts/deploy-hybrid.sh status

# Kubernetes-specific checks
kubectl get pods -n devops-suite
kubectl get ingress -n devops-suite
kubectl top nodes
kubectl top pods -n devops-suite

# VM-specific checks
ansible all -m ping -i inventory/openstack-hosts.yml
terraform show | grep -E "(gitlab|nexus|keycloak|rancher)"
```

### Backup Strategies

#### Kubernetes Backups
```bash
# Velero backup (if installed)
velero backup create devops-suite-backup --include-namespaces devops-suite

# Manual GitLab backup
kubectl exec -n devops-suite gitlab-pod -- gitlab-backup create

# PVC snapshots (provider-specific)
kubectl get pvc -n devops-suite
```

#### VM Backups
```bash
# OpenStack snapshots
openstack server image create gitlab-server --name gitlab-backup-$(date +%Y%m%d)

# Volume snapshots
openstack volume snapshot create gitlab-data --name gitlab-data-backup-$(date +%Y%m%d)
```

### Scaling

#### Horizontal Scaling (Kubernetes)
```bash
# Scale deployments
kubectl scale deployment gitlab -n devops-suite --replicas=3
kubectl scale deployment nexus -n devops-suite --replicas=2

# Auto-scaling (if HPA is configured)
kubectl get hpa -n devops-suite
```

#### Vertical Scaling (VM)
```bash
# Update Terraform configuration
# Edit terraform/terraform.tfvars
flavor_name = "m1.large"  # Increase from m1.medium

# Apply changes
terraform plan
terraform apply
```

## Security Considerations

### Network Security

#### Kubernetes Network Policies
```yaml
# Example network policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: devops-suite-network-policy
  namespace: devops-suite
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
```

#### VM Security Groups
- SSH (22): Admin access only
- HTTP/HTTPS (80/443): Public web access
- Service ports: Internal network only
- Database ports: Service-specific access

### SSL/TLS Configuration

#### Kubernetes (cert-manager)
- Automatic certificate renewal
- Let's Encrypt integration
- Certificate monitoring
- OCSP stapling support

#### VM (certbot/manual)
- Manual certificate management
- Renewal automation via cron
- Custom certificate authorities
- Proxy SSL termination

## Performance Optimization

### Kubernetes Optimizations

```yaml
# Resource requests and limits
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"

# Ingress optimizations
nginx.ingress.kubernetes.io/proxy-body-size: "500m"
nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
```

### VM Optimizations

```yaml
# NGINX proxy optimizations
nginx_worker_processes: "auto"
nginx_worker_connections: 2048
nginx_proxy_cache_enabled: true
nginx_gzip_enabled: true
nginx_http2_enabled: true
```

## Support and Contributing

### Getting Help

1. **Check logs**:
   ```bash
   # Kubernetes logs
   kubectl logs -n devops-suite <pod-name>
   
   # VM logs
   ansible <service>_servers -i inventory/openstack-hosts.yml -a "journalctl -u <service> -n 50"
   ```

2. **Documentation**: Review service-specific documentation in `/docs/`

3. **Issues**: Open GitHub issues with deployment logs and configuration

### Contributing

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/new-deployment-option`
3. **Test changes**: Validate with both VM and Kubernetes deployments
4. **Submit pull request**: Include documentation updates

---

## Conclusion

The hybrid deployment approach provides maximum flexibility for teams transitioning from traditional infrastructure to cloud-native architectures. Whether you need VM compatibility, Kubernetes scalability, or a gradual migration path, this implementation supports all scenarios while maintaining the GitLab-centered DevOps philosophy.

For additional help, refer to the service-specific documentation or open an issue in the repository.
