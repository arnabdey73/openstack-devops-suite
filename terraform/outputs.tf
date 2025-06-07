# Outputs for VMware OpenStack DevOps Suite Infrastructure

# Floating IP addresses for external access
output "gitlab_floating_ip" {
  description = "GitLab server floating IP address (Primary CI/CD and SCM)"
  value       = openstack_networking_floatingip_v2.gitlab_fip.address
}

output "nginx_floating_ip" {
  description = "NGINX proxy floating IP address (Dashboard access)"
  value       = openstack_networking_floatingip_v2.nginx_fip.address
}

output "nexus_floating_ip" {
  description = "Nexus repository floating IP address"
  value       = openstack_networking_floatingip_v2.nexus_fip.address
}

output "keycloak_floating_ip" {
  description = "Keycloak floating IP address"
  value       = openstack_networking_floatingip_v2.keycloak_fip.address
}

output "rancher_floating_ip" {
  description = "Rancher floating IP address"
  value       = openstack_networking_floatingip_v2.rancher_fip.address
}

# Internal IP addresses for service communication
output "gitlab_ip" {
  description = "GitLab server internal IP address"
  value       = openstack_compute_instance_v2.gitlab.access_ip_v4
}

output "nexus_ip" {
  description = "Nexus repository server internal IP address"
  value       = openstack_compute_instance_v2.nexus.access_ip_v4
}

output "keycloak_ip" {
  description = "Keycloak server internal IP address"
  value       = openstack_compute_instance_v2.keycloak.access_ip_v4
}

output "rancher_ip" {
  description = "Rancher server internal IP address"
  value       = openstack_compute_instance_v2.rancher.access_ip_v4
}

output "kafka_ip" {
  description = "Kafka server IP address"
  value       = openstack_compute_instance_v2.kafka.access_ip_v4
}

output "redis_ip" {
  description = "Redis server IP address"
  value       = openstack_compute_instance_v2.redis.access_ip_v4
}

output "nginx_ip" {
  description = "NGINX proxy server IP address"
  value       = openstack_compute_instance_v2.nginx.access_ip_v4
}

output "security_group_id" {
  description = "Security group ID for DevOps suite"
  value       = openstack_networking_secgroup_v2.devops_suite.id
}

output "key_pair_name" {
  description = "Key pair name used for instances"
  value       = openstack_compute_keypair_v2.devops_suite.name
}

# Generate Ansible inventory from Terraform outputs
output "ansible_inventory" {
  description = "Ansible inventory in YAML format"
  value = templatefile("${path.module}/templates/inventory.yml.tpl", {
    gitlab_ip   = openstack_compute_instance_v2.gitlab.access_ip_v4
    nexus_ip    = openstack_compute_instance_v2.nexus.access_ip_v4
    keycloak_ip = openstack_compute_instance_v2.keycloak.access_ip_v4
    rancher_ip  = openstack_compute_instance_v2.rancher.access_ip_v4
    kafka_ip    = openstack_compute_instance_v2.kafka.access_ip_v4
    redis_ip    = openstack_compute_instance_v2.redis.access_ip_v4
    nginx_ip    = openstack_compute_instance_v2.nginx.access_ip_v4
  })
}

# =============================================================================
# KUBERNETES DEPLOYMENT OUTPUTS
# =============================================================================

output "kubernetes_deployment_enabled" {
  description = "Whether Kubernetes deployment is enabled"
  value       = var.enable_kubernetes_deployment
}

output "kubernetes_namespace" {
  description = "Kubernetes namespace for DevOps suite"
  value       = var.enable_kubernetes_deployment ? kubernetes_namespace.devops_suite[0].metadata[0].name : null
}

output "ingress_class" {
  description = "Kubernetes ingress class being used"
  value       = var.enable_kubernetes_deployment ? var.ingress_class : null
}

output "domain_name" {
  description = "Base domain name for services"
  value       = var.domain_name
}

# Service URLs for Kubernetes deployment
output "gitlab_k8s_url" {
  description = "GitLab URL in Kubernetes deployment"
  value       = var.enable_kubernetes_deployment ? "https://gitlab.${var.domain_name}" : null
}

output "rancher_k8s_url" {
  description = "Rancher URL in Kubernetes deployment"
  value       = var.enable_kubernetes_deployment ? "https://rancher.${var.domain_name}" : null
}

output "keycloak_k8s_url" {
  description = "Keycloak URL in Kubernetes deployment"
  value       = var.enable_kubernetes_deployment ? "https://keycloak.${var.domain_name}" : null
}

output "nexus_k8s_url" {
  description = "Nexus URL in Kubernetes deployment"
  value       = var.enable_kubernetes_deployment ? "https://nexus.${var.domain_name}" : null
}

output "dashboard_k8s_url" {
  description = "Dashboard URL in Kubernetes deployment"
  value       = var.enable_kubernetes_deployment ? "https://dashboard.${var.domain_name}" : null
}

output "docker_registry_k8s_url" {
  description = "Docker registry URL in Kubernetes deployment"
  value       = var.enable_kubernetes_deployment ? "https://docker.${var.domain_name}" : null
}

# SSL Certificate information
output "ssl_certificates_enabled" {
  description = "Whether SSL certificates are enabled"
  value       = var.enable_kubernetes_deployment && var.enable_ssl_certificates
}

output "letsencrypt_email" {
  description = "Email used for Let's Encrypt certificates"
  value       = var.enable_kubernetes_deployment && var.letsencrypt_email != "" ? var.letsencrypt_email : null
  sensitive   = true
}

# Deployment summary
output "deployment_summary" {
  description = "Summary of deployment configuration"
  value = {
    vm_deployment         = true
    kubernetes_deployment = var.enable_kubernetes_deployment
    ssl_enabled          = var.enable_kubernetes_deployment && var.enable_ssl_certificates
    environment          = var.environment_name
    domain              = var.domain_name
  }
}
