# Terraform configuration for OpenStack DevOps Suite Infrastructure
terraform {
  required_version = ">= 1.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
  }
}

# Configure the OpenStack Provider
provider "openstack" {
  auth_url    = var.auth_url
  user_name   = var.username
  password    = var.password
  tenant_name = var.project_name
  domain_name = var.user_domain_name
}

# Data sources for existing OpenStack resources
data "openstack_images_image_v2" "ubuntu" {
  name        = var.image_name
  most_recent = true
}

data "openstack_compute_flavor_v2" "medium" {
  name = var.flavor_name
}

data "openstack_networking_network_v2" "external" {
  name = var.external_network_name
}

# Security group for DevOps suite
resource "openstack_networking_secgroup_v2" "devops_suite" {
  name        = "${var.environment_name}-devops-suite-sg"
  description = "Security group for DevOps suite services"
}

# Security group rules
resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.devops_suite.id
}

resource "openstack_networking_secgroup_rule_v2" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.devops_suite.id
}

resource "openstack_networking_secgroup_rule_v2" "https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.devops_suite.id
}

resource "openstack_networking_secgroup_rule_v2" "jenkins" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8080
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.devops_suite.id
}

resource "openstack_networking_secgroup_rule_v2" "gitlab" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8090
  port_range_max    = 8090
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.devops_suite.id
}

resource "openstack_networking_secgroup_rule_v2" "nexus" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8081
  port_range_max    = 8081
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.devops_suite.id
}

resource "openstack_networking_secgroup_rule_v2" "keycloak" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8180
  port_range_max    = 8180
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.devops_suite.id
}

resource "openstack_networking_secgroup_rule_v2" "rancher" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8443
  port_range_max    = 8443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.devops_suite.id
}

resource "openstack_networking_secgroup_rule_v2" "kafka" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9092
  port_range_max    = 9092
  remote_ip_prefix  = "10.0.0.0/8"
  security_group_id = openstack_networking_secgroup_v2.devops_suite.id
}

resource "openstack_networking_secgroup_rule_v2" "redis" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6379
  port_range_max    = 6379
  remote_ip_prefix  = "10.0.0.0/8"
  security_group_id = openstack_networking_secgroup_v2.devops_suite.id
}

# Key pair for instances
resource "openstack_compute_keypair_v2" "devops_suite" {
  name       = "${var.environment_name}-devops-suite-key"
  public_key = file(var.public_key_path)
}

# Jenkins server
resource "openstack_compute_instance_v2" "jenkins" {
  name            = "${var.environment_name}-jenkins"
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_id       = data.openstack_compute_flavor_v2.medium.id
  key_pair        = openstack_compute_keypair_v2.devops_suite.name
  security_groups = [openstack_networking_secgroup_v2.devops_suite.name]

  network {
    name = data.openstack_networking_network_v2.external.name
  }

  tags = [
    "service:jenkins",
    "environment:${var.environment_name}",
    "role:ci-cd"
  ]
}

# GitLab server
resource "openstack_compute_instance_v2" "gitlab" {
  name            = "${var.environment_name}-gitlab"
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_id       = data.openstack_compute_flavor_v2.medium.id
  key_pair        = openstack_compute_keypair_v2.devops_suite.name
  security_groups = [openstack_networking_secgroup_v2.devops_suite.name]

  network {
    name = data.openstack_networking_network_v2.external.name
  }

  tags = [
    "service:gitlab",
    "environment:${var.environment_name}",
    "role:scm"
  ]
}

# Nexus repository manager
resource "openstack_compute_instance_v2" "nexus" {
  name            = "${var.environment_name}-nexus"
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_id       = data.openstack_compute_flavor_v2.medium.id
  key_pair        = openstack_compute_keypair_v2.devops_suite.name
  security_groups = [openstack_networking_secgroup_v2.devops_suite.name]

  network {
    name = data.openstack_networking_network_v2.external.name
  }

  tags = [
    "service:nexus",
    "environment:${var.environment_name}",
    "role:repository"
  ]
}

# Keycloak identity management
resource "openstack_compute_instance_v2" "keycloak" {
  name            = "${var.environment_name}-keycloak"
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_id       = data.openstack_compute_flavor_v2.medium.id
  key_pair        = openstack_compute_keypair_v2.devops_suite.name
  security_groups = [openstack_networking_secgroup_v2.devops_suite.name]

  network {
    name = data.openstack_networking_network_v2.external.name
  }

  tags = [
    "service:keycloak",
    "environment:${var.environment_name}",
    "role:iam"
  ]
}

# Rancher Kubernetes management
resource "openstack_compute_instance_v2" "rancher" {
  name            = "${var.environment_name}-rancher"
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_id       = data.openstack_compute_flavor_v2.medium.id
  key_pair        = openstack_compute_keypair_v2.devops_suite.name
  security_groups = [openstack_networking_secgroup_v2.devops_suite.name]

  network {
    name = data.openstack_networking_network_v2.external.name
  }

  tags = [
    "service:rancher",
    "environment:${var.environment_name}",
    "role:k8s"
  ]
}

# Kafka message broker
resource "openstack_compute_instance_v2" "kafka" {
  name            = "${var.environment_name}-kafka"
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_id       = data.openstack_compute_flavor_v2.medium.id
  key_pair        = openstack_compute_keypair_v2.devops_suite.name
  security_groups = [openstack_networking_secgroup_v2.devops_suite.name]

  network {
    name = data.openstack_networking_network_v2.external.name
  }

  tags = [
    "service:kafka",
    "environment:${var.environment_name}",
    "role:messaging"
  ]
}

# Redis cache server
resource "openstack_compute_instance_v2" "redis" {
  name            = "${var.environment_name}-redis"
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_id       = data.openstack_compute_flavor_v2.medium.id
  key_pair        = openstack_compute_keypair_v2.devops_suite.name
  security_groups = [openstack_networking_secgroup_v2.devops_suite.name]

  network {
    name = data.openstack_networking_network_v2.external.name
  }

  tags = [
    "service:redis",
    "environment:${var.environment_name}",
    "role:cache"
  ]
}

# NGINX proxy server
resource "openstack_compute_instance_v2" "nginx" {
  name            = "${var.environment_name}-nginx"
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_id       = data.openstack_compute_flavor_v2.medium.id
  key_pair        = openstack_compute_keypair_v2.devops_suite.name
  security_groups = [openstack_networking_secgroup_v2.devops_suite.name]

  network {
    name = data.openstack_networking_network_v2.external.name
  }

  tags = [
    "service:nginx",
    "environment:${var.environment_name}",
    "role:proxy"
  ]
}
