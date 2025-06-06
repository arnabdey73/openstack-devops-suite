# Variables for OpenStack DevOps Suite Infrastructure
variable "auth_url" {
  description = "OpenStack authentication URL"
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
