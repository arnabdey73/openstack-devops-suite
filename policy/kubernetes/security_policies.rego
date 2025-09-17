package kubernetes.security

import rego.v1

# Kubernetes Security Policies for DevOps Suite

# POD SECURITY POLICIES

# Deny privileged containers
deny contains msg if {
    input.kind == "Pod"
    container := input.spec.containers[_]
    container.securityContext.privileged == true
    
    msg := sprintf("Container %s is running in privileged mode", [container.name])
}

# Deny containers running as root
deny contains msg if {
    input.kind in ["Pod", "Deployment", "StatefulSet", "DaemonSet"]
    container := get_containers[_]
    container.securityContext.runAsUser == 0
    
    msg := sprintf("Container %s is running as root (UID 0)", [container.name])
}

# Require non-root filesystem
deny contains msg if {
    input.kind in ["Pod", "Deployment", "StatefulSet", "DaemonSet"]
    container := get_containers[_]
    not container.securityContext.readOnlyRootFilesystem == true
    
    # Exclude monitoring containers that need write access
    not container.name in ["prometheus", "grafana", "elasticsearch"]
    
    msg := sprintf("Container %s should have readOnlyRootFilesystem set to true", [container.name])
}

# NETWORK SECURITY POLICIES

# Ensure proper network policies are in place
warn contains msg if {
    input.kind == "Namespace"
    input.metadata.name != "kube-system"
    input.metadata.name != "kube-public"
    
    not has_network_policy(input.metadata.name)
    
    msg := sprintf("Namespace %s should have NetworkPolicy defined", [input.metadata.name])
}

has_network_policy(namespace) if {
    # This would be checked against existing NetworkPolicies in the cluster
    # In practice, you'd need additional context about existing resources
    true  # Placeholder
}

# RESOURCE MANAGEMENT POLICIES

# Require resource limits
deny contains msg if {
    input.kind in ["Pod", "Deployment", "StatefulSet", "DaemonSet"]
    container := get_containers[_]
    
    not container.resources.limits.memory
    not container.resources.limits.cpu
    
    msg := sprintf("Container %s must specify resource limits", [container.name])
}

# Require resource requests
deny contains msg if {
    input.kind in ["Pod", "Deployment", "StatefulSet", "DaemonSet"]
    container := get_containers[_]
    
    not container.resources.requests.memory
    not container.resources.requests.cpu
    
    msg := sprintf("Container %s must specify resource requests", [container.name])
}

# IMAGE SECURITY POLICIES

# Deny images without explicit tags or using 'latest'
deny contains msg if {
    input.kind in ["Pod", "Deployment", "StatefulSet", "DaemonSet"]
    container := get_containers[_]
    
    image := container.image
    
    # Check for 'latest' tag or no tag
    endswith(image, ":latest") or not contains(image, ":")
    
    msg := sprintf("Container %s uses image %s with 'latest' tag or no tag - use specific versions", [container.name, image])
}

# Require images from trusted registries
deny contains msg if {
    input.kind in ["Pod", "Deployment", "StatefulSet", "DaemonSet"]
    container := get_containers[_]
    
    image := container.image
    trusted_registries := [
        "gcr.io",
        "quay.io", 
        "registry.redhat.io",
        "docker.io/library",
        "nexus.devops-suite.local"  # Our internal registry
    ]
    
    not startswith_any(image, trusted_registries)
    
    msg := sprintf("Container %s uses image %s from untrusted registry", [container.name, image])
}

startswith_any(str, prefixes) if {
    prefix := prefixes[_]
    startswith(str, prefix)
}

# SERVICE SECURITY POLICIES

# Ensure sensitive services are not exposed via LoadBalancer
deny contains msg if {
    input.kind == "Service"
    input.spec.type == "LoadBalancer"
    
    sensitive_services := ["redis", "kafka", "elasticsearch", "prometheus"]
    service_name := input.metadata.name
    
    service_type := [service | 
        service := sensitive_services[_]
        contains(service_name, service)
    ][0]
    
    msg := sprintf("Service %s (%s) should not be exposed via LoadBalancer", [service_name, service_type])
}

# INGRESS SECURITY POLICIES

# Require TLS for ingress
warn contains msg if {
    input.kind == "Ingress"
    not input.spec.tls
    
    msg := sprintf("Ingress %s should configure TLS", [input.metadata.name])
}

# Ensure proper ingress annotations for security
warn contains msg if {
    input.kind == "Ingress"
    annotations := input.metadata.annotations
    
    # Check for security headers
    not annotations["nginx.ingress.kubernetes.io/configuration-snippet"]
    not contains(annotations["nginx.ingress.kubernetes.io/server-snippet"], "add_header X-Frame-Options")
    
    msg := sprintf("Ingress %s should include security headers configuration", [input.metadata.name])
}

# SECRETS MANAGEMENT POLICIES

# Ensure secrets are not defined inline
deny contains msg if {
    input.kind == "Secret"
    input.type == "Opaque"
    
    # Check if secret data contains common sensitive patterns
    secret_data := input.data
    sensitive_keys := ["password", "token", "key", "secret"]
    
    key := object.keys(secret_data)[_]
    sensitive_key := [sk | 
        sk := sensitive_keys[_]
        contains(lower(key), sk)
    ][0]
    
    # This is a simplified check - in practice, you'd want more sophisticated detection
    msg := sprintf("Secret %s contains sensitive data in key %s - consider using external secret management", [input.metadata.name, key])
}

# MONITORING AND OBSERVABILITY POLICIES

# Ensure monitoring labels are present
warn contains msg if {
    input.kind in ["Pod", "Deployment", "StatefulSet", "DaemonSet", "Service"]
    labels := input.metadata.labels
    
    required_labels := ["app", "version", "component"]
    missing_labels := [label | 
        label := required_labels[_]
        not labels[label]
    ]
    
    count(missing_labels) > 0
    
    msg := sprintf("Resource %s is missing monitoring labels: %v", [input.metadata.name, missing_labels])
}

# Ensure proper service monitor configuration
warn contains msg if {
    input.kind == "Service"
    input.spec.selector.app
    
    # Check if service has metrics port
    metrics_port := [port |
        port := input.spec.ports[_]
        port.name == "metrics"
    ]
    
    count(metrics_port) == 0
    
    # Exclude services that shouldn't have metrics
    not input.metadata.name in ["kubernetes", "kube-dns"]
    
    msg := sprintf("Service %s should expose a metrics port for monitoring", [input.metadata.name])
}

# COMPLIANCE POLICIES

# Ensure proper namespace resource quotas
warn contains msg if {
    input.kind == "Namespace"
    input.metadata.name not in ["kube-system", "kube-public", "default"]
    
    not has_resource_quota(input.metadata.name)
    
    msg := sprintf("Namespace %s should have ResourceQuota defined", [input.metadata.name])
}

has_resource_quota(namespace) if {
    # This would be checked against existing ResourceQuotas in the cluster
    true  # Placeholder
}

# Ensure proper pod disruption budgets for critical services
warn contains msg if {
    input.kind in ["Deployment", "StatefulSet"]
    replicas := input.spec.replicas
    replicas > 1
    
    critical_services := ["prometheus", "grafana", "gitlab", "nexus", "keycloak"]
    service_name := input.metadata.name
    
    service_type := [service | 
        service := critical_services[_]
        contains(service_name, service)
    ][0]
    
    not has_pod_disruption_budget(input.metadata.name)
    
    msg := sprintf("Critical service %s should have PodDisruptionBudget defined", [service_name])
}

has_pod_disruption_budget(name) if {
    # This would be checked against existing PDBs in the cluster
    true  # Placeholder
}

# HELPER FUNCTIONS

get_containers := containers if {
    input.kind == "Pod"
    containers := input.spec.containers
} else := containers if {
    input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
    containers := input.spec.template.spec.containers
}