#!/bin/bash
# Test script for DevOps Dashboard deployment

set -eo pipefail

echo "===== DevOps Dashboard Test Script ====="
echo "Date: $(date)"
echo

# Check if ansible is available
if ! command -v ansible >/dev/null 2>&1; then
    echo "ERROR: Ansible is not installed. Please install Ansible first."
    exit 1
fi

# Check if ansible-playbook is available
if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "ERROR: ansible-playbook is not available. Please check your Ansible installation."
    exit 1
fi

# Check if inventory exists
if [ ! -f "./inventory/openstack-hosts.yml" ]; then
    echo "ERROR: Inventory file not found at ./inventory/openstack-hosts.yml"
    exit 1
fi

echo "Testing Ansible connectivity to nginx proxy server..."
ansible nginx_servers -m ping -i ./inventory/openstack-hosts.yml

echo "Checking if dashboard playbook exists..."
if [ ! -f "./playbooks/dashboard.yml" ]; then
    echo "ERROR: Dashboard playbook not found at ./playbooks/dashboard.yml"
    exit 1
fi

echo "Verifying dashboard role exists..."
if [ ! -d "./roles/nginx_proxy" ]; then
    echo "ERROR: nginx_proxy role not found at ./roles/nginx_proxy"
    exit 1
fi

echo "Checking required templates..."
required_files=(
    "./roles/nginx_proxy/templates/index.html.j2"
    "./roles/nginx_proxy/templates/assets/dashboard.css.j2"
    "./roles/nginx_proxy/files/devops-suite-logo.svg"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "ERROR: Required file not found: $file"
        exit 1
    fi
done

echo "All required files are present."
echo "Running syntax check on dashboard playbook..."
ansible-playbook ./playbooks/dashboard.yml -i ./inventory/openstack-hosts.yml --syntax-check

echo
echo "Dashboard test completed successfully!"
echo "To deploy the dashboard, run:"
echo "ansible-playbook ./playbooks/dashboard.yml -i ./inventory/openstack-hosts.yml"
echo
echo "Once deployed, access the dashboard at https://YOUR_NGINX_SERVER/"
