---
# Generated Ansible inventory from Terraform for GitLab-Centered DevOps Suite
all:
  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
    ansible_python_interpreter: /usr/bin/python3
    
  children:
    # Infrastructure nodes
    infrastructure:
      children:        
        gitlab_servers:
          hosts:
            gitlab:
              ansible_host: ${gitlab_ip}
              service_type: gitlab
              service_port: 8090
              role: ci-cd-scm
              
        nexus_servers:
          hosts:
            nexus:
              ansible_host: ${nexus_ip}
              service_type: nexus
              service_port: 8081
              
        keycloak_servers:
          hosts:
            keycloak:
              ansible_host: ${keycloak_ip}
              service_type: keycloak
              service_port: 8180
              
        rancher_servers:
          hosts:
            rancher:
              ansible_host: ${rancher_ip}
              service_type: rancher
              service_port: 8443
              
        kafka_servers:
          hosts:
            kafka:
              ansible_host: ${kafka_ip}
              service_type: kafka
              service_port: 9092
              
        redis_servers:
          hosts:
            redis:
              ansible_host: ${redis_ip}
              service_type: redis
              service_port: 6379
              
        nginx_servers:
          hosts:
            nginx:
              ansible_host: ${nginx_ip}
              service_type: nginx
              service_port: 80
