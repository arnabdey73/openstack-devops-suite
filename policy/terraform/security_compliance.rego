package terraform.analysis

import rego.v1

# Terraform Security and Compliance Policies for OpenStack DevOps Suite

# SECURITY POLICIES

# Deny resources without proper tags
required_tags := ["environment", "project", "owner", "created_by"]

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type in ["openstack_compute_instance_v2", "openstack_blockstorage_volume_v3"]
    
    missing_tags := required_tags - object.keys(resource.values.tags)
    count(missing_tags) > 0
    
    msg := sprintf("Resource %s is missing required tags: %v", [resource.address, missing_tags])
}

# Ensure SSH access is restricted
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "openstack_networking_secgroup_rule_v2"
    resource.values.protocol == "tcp"
    resource.values.port_range_min == 22
    resource.values.remote_ip_prefix == "0.0.0.0/0"
    
    msg := sprintf("Security group rule %s allows SSH access from anywhere (0.0.0.0/0)", [resource.address])
}

# Ensure HTTPS is used for web services
warn contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "openstack_networking_secgroup_rule_v2"
    resource.values.protocol == "tcp"
    resource.values.port_range_min == 80
    not has_https_rule
    
    msg := sprintf("Security group allows HTTP (port 80) but no HTTPS (port 443) rule found for %s", [resource.address])
}

has_https_rule if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "openstack_networking_secgroup_rule_v2"
    resource.values.protocol == "tcp"
    resource.values.port_range_min == 443
}

# COMPLIANCE POLICIES

# Ensure instances have minimum specifications
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "openstack_compute_instance_v2"
    
    # Get flavor details (would need to be enriched with actual flavor data)
    flavor_name := resource.values.flavor_name
    flavor_name in ["m1.nano", "m1.micro"]  # Disallow very small instances for production
    
    environment := resource.values.tags.environment
    environment == "production"
    
    msg := sprintf("Instance %s uses flavor %s which is too small for production environment", [resource.address, flavor_name])
}

# Ensure proper backup configuration for volumes
warn contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "openstack_blockstorage_volume_v3"
    
    not resource.values.backup_id
    not has_backup_policy(resource.values.name)
    
    msg := sprintf("Volume %s has no backup configuration", [resource.address])
}

has_backup_policy(volume_name) if {
    # This would be enhanced with actual backup policy checks
    contains(volume_name, "backup")
}

# COST OPTIMIZATION POLICIES

# Warn about oversized instances
warn contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "openstack_compute_instance_v2"
    
    flavor_name := resource.values.flavor_name
    flavor_name in ["m1.xlarge", "m1.2xlarge", "m1.4xlarge"]
    
    environment := resource.values.tags.environment
    environment in ["development", "testing"]
    
    msg := sprintf("Instance %s uses large flavor %s in %s environment - consider downsizing", [resource.address, flavor_name, environment])
}

# HIGH AVAILABILITY POLICIES

# Ensure production instances are in different availability zones
deny contains msg if {
    production_instances := [resource |
        resource := input.planned_values.root_module.resources[_]
        resource.type == "openstack_compute_instance_v2"
        resource.values.tags.environment == "production"
    ]
    
    count(production_instances) > 1
    
    # Check if all instances are in the same AZ
    az_list := [instance.values.availability_zone | instance := production_instances[_]]
    unique_azs := {az | az := az_list[_]}
    count(unique_azs) == 1
    
    msg := "All production instances are in the same availability zone - consider distributing across AZs"
}

# NETWORK SECURITY POLICIES

# Ensure internal services are not exposed to public internet
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "openstack_networking_secgroup_rule_v2"
    resource.values.remote_ip_prefix == "0.0.0.0/0"
    
    internal_ports := [6379, 9092, 5432, 3306, 27017]  # Redis, Kafka, PostgreSQL, MySQL, MongoDB
    resource.values.port_range_min in internal_ports
    
    msg := sprintf("Security group rule %s exposes internal service port %d to public internet", [resource.address, resource.values.port_range_min])
}

# MONITORING AND OBSERVABILITY POLICIES

# Ensure monitoring ports are configured
warn contains msg if {
    compute_instances := [resource |
        resource := input.planned_values.root_module.resources[_]
        resource.type == "openstack_compute_instance_v2"
    ]
    
    count(compute_instances) > 0
    
    not has_monitoring_ports
    
    msg := "No monitoring ports (9090, 9100, 3000) configured in security groups"
}

has_monitoring_ports if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "openstack_networking_secgroup_rule_v2"
    resource.values.port_range_min in [9090, 9100, 3000]  # Prometheus, Node Exporter, Grafana
}

# DATA PROTECTION POLICIES

# Ensure encryption for sensitive volumes
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "openstack_blockstorage_volume_v3"
    
    # Check if volume is for sensitive services
    sensitive_services := ["gitlab", "nexus", "keycloak"]
    volume_name := resource.values.name
    
    service_name := [service | 
        service := sensitive_services[_]
        contains(volume_name, service)
    ][0]
    
    # In a real scenario, you'd check encryption settings
    not resource.values.encrypted  # This field would need to be available
    
    msg := sprintf("Volume %s for service %s should be encrypted", [resource.address, service_name])
}

# RESOURCE NAMING CONVENTIONS

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type in ["openstack_compute_instance_v2", "openstack_blockstorage_volume_v3"]
    
    resource_name := resource.values.name
    not regex.match("^[a-z0-9-]+$", resource_name)
    
    msg := sprintf("Resource %s name '%s' does not follow naming convention (lowercase alphanumeric with hyphens)", [resource.address, resource_name])
}

# Ensure proper environment prefixing
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "openstack_compute_instance_v2"
    
    resource_name := resource.values.name
    environment := resource.values.tags.environment
    
    not startswith(resource_name, sprintf("%s-", [environment]))
    
    msg := sprintf("Instance %s name should start with environment prefix '%s-'", [resource.address, environment])
}