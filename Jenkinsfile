// Jenkins Pipeline for Jenkins & Gitea DevOps Suite on VMware OpenStack
pipeline {
    agent any
    
    parameters {
        choice(
            name: 'DEPLOYMENT_TYPE',
            choices: ['hybrid', 'vm', 'kubernetes'],
            description: 'Type of deployment to execute'
        )
        booleanParam(
            name: 'ENABLE_VMS',
            defaultValue: true,
            description: 'Deploy VM infrastructure'
        )
        booleanParam(
            name: 'ENABLE_KUBERNETES',
            defaultValue: false,
            description: 'Deploy Kubernetes resources'
        )
        booleanParam(
            name: 'ENABLE_SSL',
            defaultValue: true,
            description: 'Enable SSL certificate management'
        )
        string(
            name: 'DOMAIN_NAME',
            defaultValue: 'yourdomain.com',
            description: 'Base domain name for services'
        )
        booleanParam(
            name: 'VMWARE_OPTIMIZED',
            defaultValue: true,
            description: 'Enable VMware-specific optimizations'
        )
    }
    
    environment {
        TF_ROOT = "${WORKSPACE}/terraform"
        ANSIBLE_ROOT = "${WORKSPACE}"
        TF_STATE_NAME = "vmware-openstack-jenkins-gitea-devops"
        ANSIBLE_HOST_KEY_CHECKING = "False"
        ANSIBLE_STDOUT_CALLBACK = "yaml"
        KUBERNETES_NAMESPACE = "devops-suite"
        
        // OpenStack credentials (configured in Jenkins credentials)
        OS_AUTH_URL = credentials('openstack-auth-url')
        OS_USERNAME = credentials('openstack-username')
        OS_PASSWORD = credentials('openstack-password')
        OS_PROJECT_NAME = credentials('openstack-project-name')
        OS_USER_DOMAIN_NAME = credentials('openstack-user-domain')
        OS_PROJECT_DOMAIN_NAME = credentials('openstack-project-domain')
        
        // Ansible vault password (configured in Jenkins credentials)
        ANSIBLE_VAULT_PASSWORD_FILE = credentials('ansible-vault-password')
    }
    
    options {
        timeout(time: 2, unit: 'HOURS')
        retry(1)
        skipDefaultCheckout(false)
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }
    
    tools {
        terraform 'terraform-latest'
    }
    
    stages {
        stage('Checkout & Validate') {
            parallel {
                stage('Terraform Validation') {
                    steps {
                        dir('terraform') {
                            script {
                                sh '''
                                    echo "🔍 Validating Terraform configuration..."
                                    terraform init -backend=false
                                    terraform validate
                                    terraform fmt -check=true -diff=true
                                '''
                            }
                        }
                    }
                }
                
                stage('Ansible Validation') {
                    steps {
                        script {
                            sh '''
                                echo "🔍 Validating Ansible configuration..."
                                ansible --version
                                ansible-playbook --syntax-check playbooks/site.yml
                                ansible-playbook --list-tasks playbooks/site.yml
                                
                                echo "🔍 Validating individual service playbooks..."
                                ansible-playbook --syntax-check playbooks/gitea.yml
                                ansible-playbook --syntax-check playbooks/jenkins.yml
                                ansible-playbook --syntax-check playbooks/nexus.yml
                                ansible-playbook --syntax-check playbooks/keycloak.yml
                            '''
                        }
                    }
                }
                
                stage('Policy Validation') {
                    steps {
                        script {
                            sh '''
                                echo "🔍 Validating OPA policies..."
                                if command -v opa >/dev/null 2>&1; then
                                    find policy/ -name "*.rego" -exec opa fmt --diff {} +
                                    find policy/ -name "*.rego" -exec opa test {} +
                                else
                                    echo "⚠️  OPA not installed, skipping policy validation"
                                fi
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Infrastructure Planning') {
            when {
                anyOf {
                    params.ENABLE_VMS == true
                    params.DEPLOYMENT_TYPE == 'vm'
                    params.DEPLOYMENT_TYPE == 'hybrid'
                }
            }
            steps {
                dir('terraform') {
                    script {
                        sh '''
                            echo "📋 Planning Terraform infrastructure changes..."
                            terraform init
                            terraform plan \
                                -var="environment_name=jenkins-gitea-devops" \
                                -var="enable_kubernetes_deployment=${ENABLE_KUBERNETES}" \
                                -var="domain_name=${DOMAIN_NAME}" \
                                -var="enable_vmware_tools=${VMWARE_OPTIMIZED}" \
                                -out=tfplan
                        '''
                    }
                }
            }
        }
        
        stage('Infrastructure Deployment') {
            when {
                anyOf {
                    params.ENABLE_VMS == true
                    params.DEPLOYMENT_TYPE == 'vm'
                    params.DEPLOYMENT_TYPE == 'hybrid'
                }
            }
            steps {
                dir('terraform') {
                    script {
                        sh '''
                            echo "🚀 Deploying infrastructure with Terraform..."
                            terraform apply -auto-approve tfplan
                            
                            echo "📝 Generating Ansible inventory from Terraform outputs..."
                            terraform output -json > terraform_outputs.json
                            terraform output ansible_inventory > ../inventory/terraform-hosts.yml
                        '''
                    }
                }
            }
        }
        
        stage('Service Configuration') {
            when {
                anyOf {
                    params.ENABLE_VMS == true
                    params.DEPLOYMENT_TYPE == 'vm'
                    params.DEPLOYMENT_TYPE == 'hybrid'
                }
            }
            parallel {
                stage('Core Infrastructure') {
                    steps {
                        script {
                            sh '''
                                echo "🔧 Configuring core infrastructure services..."
                                ansible-playbook -i inventory/terraform-hosts.yml \
                                    playbooks/rancher.yml \
                                    --extra-vars "domain_name=${DOMAIN_NAME}" \
                                    --vault-password-file ${ANSIBLE_VAULT_PASSWORD_FILE}
                            '''
                        }
                    }
                }
                
                stage('SCM & CI/CD') {
                    steps {
                        script {
                            sh '''
                                echo "🗃️  Deploying Gitea SCM server..."
                                ansible-playbook -i inventory/terraform-hosts.yml \
                                    playbooks/gitea.yml \
                                    --extra-vars "domain_name=${DOMAIN_NAME}" \
                                    --vault-password-file ${ANSIBLE_VAULT_PASSWORD_FILE}
                                
                                echo "🔧 Deploying Jenkins CI/CD server..."
                                ansible-playbook -i inventory/terraform-hosts.yml \
                                    playbooks/jenkins.yml \
                                    --extra-vars "domain_name=${DOMAIN_NAME}" \
                                    --extra-vars "gitea_url=http://gitea.${DOMAIN_NAME}" \
                                    --vault-password-file ${ANSIBLE_VAULT_PASSWORD_FILE}
                            '''
                        }
                    }
                }
                
                stage('Repository & Identity') {
                    steps {
                        script {
                            sh '''
                                echo "📦 Deploying Nexus repository..."
                                ansible-playbook -i inventory/terraform-hosts.yml \
                                    playbooks/nexus.yml \
                                    --extra-vars "domain_name=${DOMAIN_NAME}" \
                                    --vault-password-file ${ANSIBLE_VAULT_PASSWORD_FILE}
                                
                                echo "🔐 Deploying Keycloak identity management..."
                                ansible-playbook -i inventory/terraform-hosts.yml \
                                    playbooks/keycloak.yml \
                                    --extra-vars "domain_name=${DOMAIN_NAME}" \
                                    --vault-password-file ${ANSIBLE_VAULT_PASSWORD_FILE}
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Observability Stack') {
            when {
                anyOf {
                    params.ENABLE_VMS == true
                    params.DEPLOYMENT_TYPE == 'vm'
                    params.DEPLOYMENT_TYPE == 'hybrid'
                }
            }
            parallel {
                stage('Monitoring') {
                    steps {
                        script {
                            sh '''
                                echo "📊 Deploying monitoring stack..."
                                ansible-playbook -i inventory/terraform-hosts.yml \
                                    playbooks/monitoring.yml \
                                    --extra-vars "domain_name=${DOMAIN_NAME}" \
                                    --vault-password-file ${ANSIBLE_VAULT_PASSWORD_FILE}
                            '''
                        }
                    }
                }
                
                stage('Messaging & Cache') {
                    steps {
                        script {
                            sh '''
                                echo "💬 Deploying Kafka messaging..."
                                ansible-playbook -i inventory/terraform-hosts.yml \
                                    playbooks/kafka.yml \
                                    --vault-password-file ${ANSIBLE_VAULT_PASSWORD_FILE}
                                
                                echo "🧠 Deploying Redis cache..."
                                ansible-playbook -i inventory/terraform-hosts.yml \
                                    playbooks/redis.yml \
                                    --vault-password-file ${ANSIBLE_VAULT_PASSWORD_FILE}
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Kubernetes Deployment') {
            when {
                anyOf {
                    params.ENABLE_KUBERNETES == true
                    params.DEPLOYMENT_TYPE == 'kubernetes'
                    params.DEPLOYMENT_TYPE == 'hybrid'
                }
            }
            steps {
                script {
                    sh '''
                        echo "☸️  Deploying Kubernetes resources..."
                        kubectl apply -f k8s/namespace.yaml
                        kubectl apply -f k8s/certificates.yaml
                        kubectl apply -f k8s/services.yaml
                        kubectl apply -f k8s/ingress.yaml
                        kubectl apply -f k8s/onboarding-portal.yaml
                    '''
                }
            }
        }
        
        stage('Verification & Testing') {
            parallel {
                stage('Infrastructure Tests') {
                    steps {
                        dir('terraform/tests') {
                            script {
                                sh '''
                                    echo "🧪 Running infrastructure tests..."
                                    if [ -f "infrastructure_test.go" ]; then
                                        go test -v -timeout 30m
                                    else
                                        echo "⚠️  Infrastructure tests not found, running basic connectivity tests..."
                                        ../scripts/test-infrastructure.sh
                                    fi
                                '''
                            }
                        }
                    }
                }
                
                stage('Service Health Checks') {
                    steps {
                        script {
                            sh '''
                                echo "🏥 Running service health checks..."
                                ./scripts/test-deployment-flow.py --basic-health
                                ./scripts/test-onboarding.py --smoke-test
                            '''
                        }
                    }
                }
                
                stage('Dashboard Tests') {
                    steps {
                        script {
                            sh '''
                                echo "📊 Testing dashboard functionality..."
                                ./scripts/test-dashboard.sh
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Performance Testing') {
            when {
                anyOf {
                    params.DEPLOYMENT_TYPE == 'hybrid'
                    currentBuild.getBuildCauses()[0]._class.contains('UserIdCause')
                }
            }
            steps {
                script {
                    sh '''
                        echo "⚡ Running performance tests..."
                        ./scripts/test-performance.sh --quick
                    '''
                }
            }
        }
        
        stage('SSL Certificate Validation') {
            when {
                params.ENABLE_SSL == true
            }
            steps {
                script {
                    sh '''
                        echo "🔒 Validating SSL certificates..."
                        ./scripts/test-ssl-certificates.sh
                    '''
                }
            }
        }
        
        stage('Integration Testing') {
            steps {
                script {
                    sh '''
                        echo "🔗 Running integration tests..."
                        ./scripts/test-hybrid-deployment.sh
                        
                        echo "🧪 Running comprehensive test suite..."
                        python3 scripts/test_runner.py --comprehensive
                    '''
                }
            }
        }
    }
    
    post {
        always {
            script {
                // Archive important artifacts
                archiveArtifacts artifacts: 'terraform/tfplan, terraform/terraform_outputs.json, inventory/terraform-hosts.yml', allowEmptyArchive: true
                
                // Publish test results if they exist
                if (fileExists('test-results.xml')) {
                    publishTestResults testResultsPattern: 'test-results.xml'
                }
                
                // Generate deployment report
                sh '''
                    echo "📋 Generating deployment report..."
                    ./scripts/test_runner.py --generate-report > deployment-report.txt
                '''
                archiveArtifacts artifacts: 'deployment-report.txt', allowEmptyArchive: true
            }
        }
        
        success {
            echo '''
            ✅ Jenkins & Gitea DevOps Suite deployment completed successfully!
            
            📋 Access Information:
            • Gitea: http://gitea.${DOMAIN_NAME} (Git repositories)
            • Jenkins: http://jenkins.${DOMAIN_NAME} (This CI/CD server)
            • Nexus: http://nexus.${DOMAIN_NAME} (Artifact repository)
            • Keycloak: http://keycloak.${DOMAIN_NAME} (Identity management)
            • Grafana: http://grafana.${DOMAIN_NAME} (Monitoring dashboards)
            
            🔧 Next Steps:
            1. Configure Gitea-Jenkins integration
            2. Create your first repository in Gitea
            3. Set up webhook for automatic builds
            4. Access monitoring dashboards
            '''
        }
        
        failure {
            echo '''
            ❌ Deployment failed! Check the logs above for details.
            
            🔧 Troubleshooting:
            1. Check OpenStack credentials and quotas
            2. Verify network connectivity
            3. Review Ansible playbook logs
            4. Check Terraform state consistency
            
            📞 Support: See docs/TROUBLESHOOTING.md for common issues
            '''
        }
        
        unstable {
            echo '''
            ⚠️  Deployment completed with warnings!
            
            Some tests may have failed, but core services are running.
            Check the test results and logs for specific issues.
            '''
        }
        
        cleanup {
            // Clean up temporary files
            sh '''
                rm -f terraform/tfplan
                rm -f terraform/terraform_outputs.json
            '''
        }
    }
}