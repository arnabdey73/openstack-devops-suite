#cloud-config
# Cloud-init configuration for VMware OpenStack DevOps Suite
# Environment: ${environment_name}

package_update: true
package_upgrade: true

packages:
  - curl
  - wget
  - git
  - vim
  - htop
  - iotop
  - ntp
  - rsync
  - unzip
  - ca-certificates
  - open-vm-tools
  - python3
  - python3-pip

# VMware Tools installation and configuration
runcmd:
  # Ensure VMware Tools are running
  - systemctl enable open-vm-tools
  - systemctl start open-vm-tools
  
  # Set timezone
  - timedatectl set-timezone UTC
  
  # Configure firewall
  - ufw --force enable
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow ssh
  
  # Update hostname
  - hostnamectl set-hostname ${environment_name}-vm
  
  # Configure VM for optimal performance in VMware
  - echo 'net.core.rmem_max = 134217728' >> /etc/sysctl.conf
  - echo 'net.core.wmem_max = 134217728' >> /etc/sysctl.conf
  - echo 'vm.swappiness = 10' >> /etc/sysctl.conf
  - sysctl -p

# SSH configuration
ssh_authorized_keys: []

# Disable cloud-init on subsequent boots
cloud_final_modules:
  - scripts-user
  - ssh-authkey-fingerprints
  - keys-to-console
  - phone-home
  - final-message
  - power-state-change

write_files:
  - path: /etc/motd
    content: |
      =====================================
      ${environment_name} DevOps Suite VM
      GitLab-Centered Infrastructure
      VMware OpenStack Deployment
      =====================================
    owner: root:root
    permissions: '0644'

  - path: /etc/systemd/system/vm-optimization.service
    content: |
      [Unit]
      Description=VMware VM Optimization
      After=network.target

      [Service]
      Type=oneshot
      ExecStart=/bin/bash -c 'echo "VM optimized for VMware environment"'
      RemainAfterExit=yes

      [Install]
      WantedBy=multi-user.target
    owner: root:root
    permissions: '0644'

final_message: "VMware OpenStack VM for ${environment_name} DevOps Suite is ready!"
