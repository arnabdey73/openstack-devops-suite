# Variables for VMware OpenStack DevOps Suite Infrastructure
variable "auth_url" {
  description = "OpenStack authentication URL (VMware Integrated OpenStack)"
  type        = string
  default     = "https://openstack.example.com:5000/v3"
}

variable "username" {
  description = "OpenStack username"
  type        = string
  default     = "admin"
}

variable "password" {
  description = "OpenStack password"
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "OpenStack project name"
  type        = string
  default     = "admin"
}

variable "user_domain_name" {
  description = "OpenStack user domain name"
  type        = string
  default     = "Default"
}

variable "project_domain_name" {
  description = "OpenStack project domain name"
  type        = string
  default     = "Default"
}

variable "environment_name" {
  description = "Environment name for resource naming"
  type        = string
  default     = "devops"
}

variable "image_name" {
  description = "OpenStack image name for instances"
  type        = string
  default     = "Ubuntu 22.04"
}

variable "flavor_name" {
  description = "OpenStack flavor for instances"
  type        = string
  default     = "m1.medium"
}

variable "external_network_name" {
  description = "External network name in OpenStack"
  type        = string
  default     = "public"
}

variable "public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "region" {
  description = "OpenStack region"
  type        = string
  default     = "RegionOne"
}

# VMware-specific optimizations
variable "vmware_datacenter" {
  description = "VMware datacenter name for VM placement"
  type        = string
  default     = ""
}

variable "vm_anti_affinity" {
  description = "Enable VM anti-affinity for high availability"
  type        = bool
  default     = true
}

variable "enable_vmware_tools" {
  description = "Enable VMware Tools installation on VMs"
  type        = bool
  default     = true
}

# Volume sizes for persistent storage
variable "gitlab_volume_size" {
  description = "Size of GitLab data volume in GB"
  type        = number
  default     = 50
}

variable "nexus_volume_size" {
  description = "Size of Nexus data volume in GB"
  type        = number
  default     = 30
}

variable "keycloak_volume_size" {
  description = "Size of Keycloak data volume in GB"
  type        = number
  default     = 10
}

# Kubernetes Integration Variables
variable "enable_kubernetes_deployment" {
  description = "Enable Kubernetes deployment alongside VM deployment"
  type        = bool
  default     = false
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig file for Kubernetes deployment"
  type        = string
  default     = "~/.kube/config"
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt certificates"
  type        = string
  default     = ""
}

variable "kubernetes_cluster_endpoint" {
  description = "Kubernetes cluster API endpoint"
  type        = string
  default     = ""
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for DevOps suite deployment"
  type        = string
  default     = "devops-suite"
}

variable "domain_name" {
  description = "Base domain name for services (e.g., yourdomain.com)"
  type        = string
  default     = "yourdomain.com"
}

variable "ingress_class" {
  description = "Kubernetes ingress class to use"
  type        = string
  default     = "nginx"
}

variable "enable_ssl_certificates" {
  description = "Enable automatic SSL certificate generation"
  type        = bool
  default     = true
}
