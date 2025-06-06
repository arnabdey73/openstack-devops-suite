# Outputs for OpenStack DevOps Suite Infrastructure
output "jenkins_ip" {
  description = "Jenkins server IP address"
  value       = openstack_compute_instance_v2.jenkins.access_ip_v4
}

output "gitlab_ip" {
  description = "GitLab server IP address"
  value       = openstack_compute_instance_v2.gitlab.access_ip_v4
}

output "nexus_ip" {
  description = "Nexus repository server IP address"
  value       = openstack_compute_instance_v2.nexus.access_ip_v4
}

output "keycloak_ip" {
  description = "Keycloak server IP address"
  value       = openstack_compute_instance_v2.keycloak.access_ip_v4
}

output "rancher_ip" {
  description = "Rancher server IP address"
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
    jenkins_ip  = openstack_compute_instance_v2.jenkins.access_ip_v4
    gitlab_ip   = openstack_compute_instance_v2.gitlab.access_ip_v4
    nexus_ip    = openstack_compute_instance_v2.nexus.access_ip_v4
    keycloak_ip = openstack_compute_instance_v2.keycloak.access_ip_v4
    rancher_ip  = openstack_compute_instance_v2.rancher.access_ip_v4
    kafka_ip    = openstack_compute_instance_v2.kafka.access_ip_v4
    redis_ip    = openstack_compute_instance_v2.redis.access_ip_v4
    nginx_ip    = openstack_compute_instance_v2.nginx.access_ip_v4
  })
}
