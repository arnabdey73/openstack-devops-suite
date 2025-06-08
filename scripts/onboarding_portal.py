#!/usr/bin/env python3
"""
GitLab-Centered DevOps Suite - 1-Click Application Onboarding Portal
-------------------------------------------------------------------
A Vercel-like onboarding experience for the OpenStack DevOps Suite.
"""

import os
import sys
import json
import time
# import yaml  # Comment out until PyYAML is installed
import subprocess
import logging
import traceback
import secrets
from datetime import datetime, timedelta
from flask import Flask, jsonify, request, render_template, redirect, url_for, session, Response, make_response, flash
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from functools import wraps

app = Flask(__name__, 
            static_folder="static",
            template_folder="templates")

# Authentication decorator
def requires_auth(f):
    """
    Decorator to require authentication for routes
    In a production environment, this would integrate with your SSO/LDAP system
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # Check if user is authenticated
        if 'authenticated' not in session or not session['authenticated']:
            if request.path.startswith('/api/'):
                return jsonify({
                    "status": "error",
                    "message": "Authentication required"
                }), 401
            else:
                return redirect(url_for('login', next=request.url))
        return f(*args, **kwargs)
    return decorated_function

# Configure secure session
app.secret_key = os.getenv('SECRET_KEY', os.urandom(24))
app.config['SESSION_COOKIE_SECURE'] = os.getenv('SECURE_COOKIES', 'True').lower() == 'true'
app.config['SESSION_COOKIE_HTTPONLY'] = True
app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'
app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(hours=1)
# Uncomment when flask-wtf is installed
# app.config['WTF_CSRF_ENABLED'] = True
# app.config['WTF_CSRF_TIME_LIMIT'] = 3600  # 1 hour

# Configure CSRF protection (uncomment when flask-wtf is installed)
# csrf = CSRFProtect(app)

# Configure rate limiting
limiter = Limiter(
    get_remote_address,
    app=app,
    default_limits=["200 per day", "50 per hour"],
    storage_uri="memory://",
)

# Security headers configuration
def add_security_headers(response):
    """Add security headers to all responses"""
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    response.headers['Content-Security-Policy'] = (
        "default-src 'self'; "
        "script-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com https://cdn.jsdelivr.net; "
        "style-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com https://cdn.jsdelivr.net; "
        "font-src 'self' https://cdnjs.cloudflare.com; "
        "img-src 'self' data: https:; "
        "connect-src 'self'"
    )
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    response.headers['Permissions-Policy'] = (
        "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=()"
    )
    return response

# Apply security headers to all responses
app.after_request(add_security_headers)

# Configure logging
logging.basicConfig(
    level=logging.INFO, 
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("onboarding.log"),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("onboarding-portal")

# Constants
GITLAB_URL = os.getenv('GITLAB_URL', 'https://gitlab.yourdomain.com')
GITLAB_TOKEN = os.getenv('GITLAB_TOKEN', '')
NEXUS_URL = os.getenv('NEXUS_URL', 'https://nexus.yourdomain.com')
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TERRAFORM_DIR = os.path.join(PROJECT_ROOT, 'terraform')
K8S_DIR = os.path.join(PROJECT_ROOT, 'k8s')

# Authentication credentials
ADMIN_USERNAME = os.getenv('ADMIN_USERNAME', 'admin')
ADMIN_PASSWORD = os.getenv('ADMIN_PASSWORD', 'changeme')

# Error constants
ERROR_GITLAB_CONNECTION = "Unable to connect to GitLab API"
ERROR_INSUFFICIENT_PARAMS = "Insufficient parameters provided"
ERROR_PROJECT_CREATION = "Failed to create GitLab project"
ERROR_PIPELINE_CREATION = "Failed to generate CI/CD pipeline"
ERROR_K8S_MANIFEST_CREATION = "Failed to create Kubernetes manifest"
ERROR_DOCKERFILE_CREATION = "Failed to generate Dockerfile"
ERROR_FILE_CREATION = "Failed to add files to repository"
ERROR_PROJECT_EXISTS = "Project already exists"
ERROR_UNKNOWN = "An unknown error occurred"

class OnboardingError(Exception):
    """Custom exception for onboarding errors"""
    def __init__(self, message, status_code=500, details=None):
        self.message = message
        self.status_code = status_code
        self.details = details
        super().__init__(self.message)

class OnboardingService:
    """Main service for application onboarding"""
    
    def __init__(self):
        self.gitlab_url = GITLAB_URL
        self.gitlab_token = GITLAB_TOKEN
        self._verify_credentials()
        
    def _verify_credentials(self):
        """Verify GitLab credentials are valid"""
        try:
            # Test connection and token validity
            cmd = [
                'curl', '-s',
                f"{self.gitlab_url}/api/v4/user",
                '-H', f"PRIVATE-TOKEN: {self.gitlab_token}"
            ]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0 or "error" in result.stdout.lower():
                logger.error(f"GitLab credentials verification failed: {result.stderr or result.stdout}")
                raise OnboardingError(
                    ERROR_GITLAB_CONNECTION,
                    status_code=401,
                    details="Please check GitLab URL and token in environment variables"
                )
            
            logger.info("GitLab credentials verified successfully")
        except Exception as e:
            if isinstance(e, OnboardingError):
                raise
            logger.error(f"Error during credential verification: {str(e)}")
            logger.debug(traceback.format_exc())
            raise OnboardingError(
                ERROR_GITLAB_CONNECTION,
                status_code=500,
                details=f"Exception: {str(e)}"
            )
        
    def create_project(self, app_data):
        """Create a new GitLab project with appropriate settings"""
        try:
            if not app_data.get('app_name'):
                raise OnboardingError(
                    ERROR_INSUFFICIENT_PARAMS,
                    status_code=400,
                    details="Application name is required"
                )
                
            logger.info(f"Creating GitLab project {app_data['app_name']}")
            
            # Use GitLab API to create project
            cmd = [
                'curl', '-s', '-X', 'POST',
                f"{self.gitlab_url}/api/v4/projects",
                '-H', f"PRIVATE-TOKEN: {self.gitlab_token}",
                '-H', 'Content-Type: application/json',
                '-d', json.dumps({
                    'name': app_data['app_name'],
                    'description': app_data['description'],
                    'initialize_with_readme': True,
                    'visibility': 'private',
                    'tag_list': ['onboarded', app_data.get('framework', 'generic')],
                })
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                logger.error(f"Failed to create GitLab project: {result.stderr}")
                raise OnboardingError(
                    ERROR_PROJECT_CREATION,
                    status_code=500,
                    details=f"GitLab API error: {result.stderr}"
                )
            
            project_data = json.loads(result.stdout)
            logger.info(f"Project created: {project_data['web_url']}")
            return project_data
        except Exception as e:
            logger.error(f"Failed to create GitLab project: {str(e)}")
            logger.debug(traceback.format_exc())
            raise OnboardingError(
                ERROR_PROJECT_CREATION,
                status_code=500,
                details=f"Exception: {str(e)}"
            )
            
    def generate_ci_cd_pipeline(self, app_data):
        """Generate the GitLab CI/CD pipeline based on application type"""
        try:
            logger.info(f"Generating CI/CD pipeline for {app_data['app_name']}")
            
            # Select template based on application framework
            template_function = getattr(
                self, 
                f"_generate_{app_data['framework']}_pipeline", 
                self._generate_generic_pipeline
            )
            
            return template_function(app_data)
        except Exception as e:
            logger.error(f"Failed to generate CI/CD pipeline: {str(e)}")
            logger.debug(traceback.format_exc())
            raise OnboardingError(
                ERROR_PIPELINE_CREATION,
                status_code=500,
                details=f"Exception: {str(e)}"
            )
    
    def _generate_nodejs_pipeline(self, app_data):
        """Generate Node.js specific GitLab CI/CD pipeline"""
        return f"""# GitLab CI/CD Pipeline for {app_data['app_name']}
# Generated by DevOps Suite 1-Click Onboarding

stages:
  - validate
  - test
  - security-scan
  - build
  - deploy-dev
  - deploy-prod

variables:
  NODE_VERSION: "{app_data.get('node_version', '18')}"
  APP_NAME: "{app_data['app_name']}"
  DOCKER_REGISTRY: "{app_data.get('registry_url', 'nexus.yourdomain.com:8082')}"

cache:
  paths:
    - node_modules/

validate:
  stage: validate
  image: node:$NODE_VERSION
  script:
    - npm ci
    - npm run lint || echo "Linting step skipped"
    - npm run type-check || echo "Type checking skipped"

test:
  stage: test
  image: node:$NODE_VERSION
  script:
    - npm ci
    - npm test || echo "No tests found"
  coverage: '/Lines\\s*:\\s*(\\d+\\.?\\d*)%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml

security-scan:
  stage: security-scan
  image: node:$NODE_VERSION
  script:
    - npm audit --audit-level high || echo "Vulnerabilities found"
    - npx retire --severity high || echo "Outdated packages found"

build:
  stage: build
  image: docker:24.0
  services:
    - docker:24.0-dind
  script:
    - echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin $DOCKER_REGISTRY
    - docker build -t $DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA .
    - docker push $DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA
    - docker tag $DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA $DOCKER_REGISTRY/$APP_NAME:latest
    - docker push $DOCKER_REGISTRY/$APP_NAME:latest

deploy-dev:
  stage: deploy-dev
  image: bitnami/kubectl:latest
  script:
    - kubectl create namespace apps-dev --dry-run=client -o yaml | kubectl apply -f -
    - sed -e "s|__IMAGE__|$DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA|g" deploy/deployment.yaml | kubectl -n apps-dev apply -f -
    - kubectl -n apps-dev apply -f deploy/service.yaml
    - kubectl -n apps-dev apply -f deploy/ingress.yaml
    - kubectl -n apps-dev rollout status deployment/$APP_NAME
  environment:
    name: development
    url: https://$APP_NAME-dev.yourdomain.com
  only:
    - develop
    - main

deploy-prod:
  stage: deploy-prod
  image: bitnami/kubectl:latest
  script:
    - kubectl create namespace apps-prod --dry-run=client -o yaml | kubectl apply -f -
    - sed -e "s|__IMAGE__|$DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA|g" deploy/deployment.yaml | kubectl -n apps-prod apply -f -
    - kubectl -n apps-prod apply -f deploy/service.yaml
    - kubectl -n apps-prod apply -f deploy/ingress.yaml
    - kubectl -n apps-prod rollout status deployment/$APP_NAME
  environment:
    name: production
    url: https://$APP_NAME.yourdomain.com
  only:
    - main
  when: manual
"""

    def _generate_python_pipeline(self, app_data):
        """Generate Python specific GitLab CI/CD pipeline"""
        return f"""# GitLab CI/CD Pipeline for {app_data['app_name']}
# Generated by DevOps Suite 1-Click Onboarding

stages:
  - validate
  - test
  - security-scan
  - build
  - deploy-dev
  - deploy-prod

variables:
  PYTHON_VERSION: "{app_data.get('python_version', '3.11')}"
  APP_NAME: "{app_data['app_name']}"
  DOCKER_REGISTRY: "{app_data.get('registry_url', 'nexus.yourdomain.com:8082')}"

validate:
  stage: validate
  image: python:$PYTHON_VERSION
  script:
    - pip install flake8 black
    - flake8 . || echo "Linting issues found"
    - black --check . || echo "Formatting issues found"

test:
  stage: test
  image: python:$PYTHON_VERSION
  script:
    - pip install -r requirements.txt
    - pip install pytest pytest-cov
    - python -m pytest --cov=./ --cov-report=xml
  coverage: '/TOTAL.+ ([0-9]{1,3}%)/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml

security-scan:
  stage: security-scan
  image: python:$PYTHON_VERSION
  script:
    - pip install safety
    - safety check || echo "Vulnerabilities found"

build:
  stage: build
  image: docker:24.0
  services:
    - docker:24.0-dind
  script:
    - echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin $DOCKER_REGISTRY
    - docker build -t $DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA .
    - docker push $DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA
    - docker tag $DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA $DOCKER_REGISTRY/$APP_NAME:latest
    - docker push $DOCKER_REGISTRY/$APP_NAME:latest

deploy-dev:
  stage: deploy-dev
  image: bitnami/kubectl:latest
  script:
    - kubectl create namespace apps-dev --dry-run=client -o yaml | kubectl apply -f -
    - sed -e "s|__IMAGE__|$DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA|g" deploy/deployment.yaml | kubectl -n apps-dev apply -f -
    - kubectl -n apps-dev apply -f deploy/service.yaml
    - kubectl -n apps-dev apply -f deploy/ingress.yaml
    - kubectl -n apps-dev rollout status deployment/$APP_NAME
  environment:
    name: development
    url: https://$APP_NAME-dev.yourdomain.com
  only:
    - develop
    - main

deploy-prod:
  stage: deploy-prod
  image: bitnami/kubectl:latest
  script:
    - kubectl create namespace apps-prod --dry-run=client -o yaml | kubectl apply -f -
    - sed -e "s|__IMAGE__|$DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA|g" deploy/deployment.yaml | kubectl -n apps-prod apply -f -
    - kubectl -n apps-prod apply -f deploy/service.yaml
    - kubectl -n apps-prod apply -f deploy/ingress.yaml
    - kubectl -n apps-prod rollout status deployment/$APP_NAME
  environment:
    name: production
    url: https://$APP_NAME.yourdomain.com
  only:
    - main
  when: manual
"""

    def _generate_java_pipeline(self, app_data):
        """Generate Java/Spring specific GitLab CI/CD pipeline"""
        return f"""# GitLab CI/CD Pipeline for {app_data['app_name']}
# Generated by DevOps Suite 1-Click Onboarding

stages:
  - validate
  - test
  - security-scan
  - build
  - deploy-dev
  - deploy-prod

variables:
  JAVA_VERSION: "{app_data.get('java_version', '17')}"
  APP_NAME: "{app_data['app_name']}"
  DOCKER_REGISTRY: "{app_data.get('registry_url', 'nexus.yourdomain.com:8082')}"

validate:
  stage: validate
  image: gradle:jdk$JAVA_VERSION
  script:
    - gradle checkstyleMain || echo "Checkstyle issues found"
    - gradle spotlessCheck || echo "Formatting issues found"

test:
  stage: test
  image: gradle:jdk$JAVA_VERSION
  script:
    - gradle test jacocoTestReport
  coverage: '/Total.*?([0-9]{1,3})%/'
  artifacts:
    reports:
      junit: build/test-results/test/**/TEST-*.xml
    paths:
      - build/reports/jacoco/

security-scan:
  stage: security-scan
  image: gradle:jdk$JAVA_VERSION
  script:
    - gradle dependencyCheckAnalyze || echo "Vulnerabilities found"

build:
  stage: build
  image: docker:24.0
  services:
    - docker:24.0-dind
  script:
    - echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin $DOCKER_REGISTRY
    - docker build -t $DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA .
    - docker push $DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA
    - docker tag $DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA $DOCKER_REGISTRY/$APP_NAME:latest
    - docker push $DOCKER_REGISTRY/$APP_NAME:latest

deploy-dev:
  stage: deploy-dev
  image: bitnami/kubectl:latest
  script:
    - kubectl create namespace apps-dev --dry-run=client -o yaml | kubectl apply -f -
    - sed -e "s|__IMAGE__|$DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA|g" deploy/deployment.yaml | kubectl -n apps-dev apply -f -
    - kubectl -n apps-dev apply -f deploy/service.yaml
    - kubectl -n apps-dev apply -f deploy/ingress.yaml
    - kubectl -n apps-dev rollout status deployment/$APP_NAME
  environment:
    name: development
    url: https://$APP_NAME-dev.yourdomain.com
  only:
    - develop
    - main

deploy-prod:
  stage: deploy-prod
  image: bitnami/kubectl:latest
  script:
    - kubectl create namespace apps-prod --dry-run=client -o yaml | kubectl apply -f -
    - sed -e "s|__IMAGE__|$DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA|g" deploy/deployment.yaml | kubectl -n apps-prod apply -f -
    - kubectl -n apps-prod apply -f deploy/service.yaml
    - kubectl -n apps-prod apply -f deploy/ingress.yaml
    - kubectl -n apps-prod rollout status deployment/$APP_NAME
  environment:
    name: production
    url: https://$APP_NAME.yourdomain.com
  only:
    - main
  when: manual
"""
    
    def _generate_generic_pipeline(self, app_data):
        """Generate a generic GitLab CI/CD pipeline"""
        return f"""# GitLab CI/CD Pipeline for {app_data['app_name']}
# Generated by DevOps Suite 1-Click Onboarding

stages:
  - validate
  - build
  - deploy-dev
  - deploy-prod

variables:
  APP_NAME: "{app_data['app_name']}"
  DOCKER_REGISTRY: "{app_data.get('registry_url', 'nexus.yourdomain.com:8082')}"

build:
  stage: build
  image: docker:24.0
  services:
    - docker:24.0-dind
  script:
    - echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin $DOCKER_REGISTRY
    - docker build -t $DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA .
    - docker push $DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA
    - docker tag $DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA $DOCKER_REGISTRY/$APP_NAME:latest
    - docker push $DOCKER_REGISTRY/$APP_NAME:latest

deploy-dev:
  stage: deploy-dev
  image: bitnami/kubectl:latest
  script:
    - kubectl create namespace apps-dev --dry-run=client -o yaml | kubectl apply -f -
    - sed -e "s|__IMAGE__|$DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA|g" deploy/deployment.yaml | kubectl -n apps-dev apply -f -
    - kubectl -n apps-dev apply -f deploy/service.yaml
    - kubectl -n apps-dev apply -f deploy/ingress.yaml
    - kubectl -n apps-dev rollout status deployment/$APP_NAME
  environment:
    name: development
    url: https://$APP_NAME-dev.yourdomain.com
  only:
    - develop
    - main

deploy-prod:
  stage: deploy-prod
  image: bitnami/kubectl:latest
  script:
    - kubectl create namespace apps-prod --dry-run=client -o yaml | kubectl apply -f -
    - sed -e "s|__IMAGE__|$DOCKER_REGISTRY/$APP_NAME:$CI_COMMIT_SHA|g" deploy/deployment.yaml | kubectl -n apps-prod apply -f -
    - kubectl -n apps-prod apply -f deploy/service.yaml
    - kubectl -n apps-prod apply -f deploy/ingress.yaml
    - kubectl -n apps-prod rollout status deployment/$APP_NAME
  environment:
    name: production
    url: https://$APP_NAME.yourdomain.com
  only:
    - main
  when: manual
"""
    
    def generate_kubernetes_manifests(self, app_data):
        """Generate Kubernetes deployment manifests"""
        logger.info(f"Generating Kubernetes manifests for {app_data['app_name']}")
        
        try:
            # Create deploy directory in project
            os.makedirs(f"templates/apps/{app_data['app_name']}/deploy", exist_ok=True)
            
            # Generate manifests
            manifests = {
                'deployment.yaml': self._generate_deployment_manifest(app_data),
                'service.yaml': self._generate_service_manifest(app_data),
                'ingress.yaml': self._generate_ingress_manifest(app_data),
                'configmap.yaml': self._generate_configmap(app_data),
            }
            
            # Save manifests to files
            for filename, content in manifests.items():
                with open(f"templates/apps/{app_data['app_name']}/deploy/{filename}", 'w') as f:
                    f.write(content)
                    
            return manifests
        except Exception as e:
            logger.error(f"Failed to generate Kubernetes manifests: {str(e)}")
            logger.debug(traceback.format_exc())
            raise OnboardingError(
                ERROR_K8S_MANIFEST_CREATION,
                status_code=500,
                details=f"Exception: {str(e)}"
            )
    
    def _generate_deployment_manifest(self, app_data):
        """Generate Kubernetes deployment manifest"""
        return f"""apiVersion: apps/v1
kind: Deployment
metadata:
  name: {app_data['app_name']}
  labels:
    app: {app_data['app_name']}
    environment: {{{{ .Release.Namespace }}}}
spec:
  replicas: {app_data.get('replicas', 3)}
  selector:
    matchLabels:
      app: {app_data['app_name']}
  template:
    metadata:
      labels:
        app: {app_data['app_name']}
    spec:
      imagePullSecrets:
      - name: regcred
      containers:
      - name: {app_data['app_name']}
        image: __IMAGE__
        ports:
        - containerPort: {app_data.get('port', 8080)}
        env:
        - name: APP_ENV
          value: {{{{ .Release.Namespace }}}}
        - name: APP_PORT
          value: "{app_data.get('port', 8080)}"
        resources:
          requests:
            memory: "{app_data.get('memory_request', '256Mi')}"
            cpu: "{app_data.get('cpu_request', '100m')}"
          limits:
            memory: "{app_data.get('memory_limit', '512Mi')}"
            cpu: "{app_data.get('cpu_limit', '500m')}"
        livenessProbe:
          httpGet:
            path: /health
            port: {app_data.get('port', 8080)}
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: {app_data.get('port', 8080)}
          initialDelaySeconds: 5
          periodSeconds: 5
"""
    
    def _generate_service_manifest(self, app_data):
        """Generate Kubernetes service manifest"""
        return f"""apiVersion: v1
kind: Service
metadata:
  name: {app_data['app_name']}
  labels:
    app: {app_data['app_name']}
spec:
  selector:
    app: {app_data['app_name']}
  ports:
  - port: 80
    targetPort: {app_data.get('port', 8080)}
    protocol: TCP
  type: ClusterIP
"""
    
    def _generate_ingress_manifest(self, app_data):
        """Generate Kubernetes ingress manifest"""
        return f"""apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {app_data['app_name']}
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - {app_data['app_name']}.{{{{ .Release.Namespace }}}}.yourdomain.com
    secretName: {app_data['app_name']}-tls
  rules:
  - host: {app_data['app_name']}.{{{{ .Release.Namespace }}}}.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: {app_data['app_name']}
            port:
              number: 80
"""
    
    def _generate_configmap(self, app_data):
        """Generate Kubernetes configmap for application"""
        return f"""apiVersion: v1
kind: ConfigMap
metadata:
  name: {app_data['app_name']}-config
data:
  app.env: |
    APP_NAME={app_data['app_name']}
    APP_ENVIRONMENT={{{{ .Release.Namespace }}}}
    APP_VERSION={{{{ .Values.image.tag }}}}
"""
    
    def _generate_dockerfile(self, app_data):
        """Generate Dockerfile based on application type"""
        template_function = getattr(
            self, 
            f"_generate_{app_data['framework']}_dockerfile", 
            self._generate_generic_dockerfile
        )
        
        return template_function(app_data)
    
    def _generate_nodejs_dockerfile(self, app_data):
        """Generate Node.js Dockerfile"""
        return f"""FROM node:{app_data.get('node_version', '18')}-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE {app_data.get('port', 8080)}
CMD ["npm", "start"]
"""
    
    def _generate_python_dockerfile(self, app_data):
        """Generate Python Dockerfile"""
        return f"""FROM python:{app_data.get('python_version', '3.11')}-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE {app_data.get('port', 8080)}
CMD ["python", "app.py"]
"""
    
    def _generate_java_dockerfile(self, app_data):
        """Generate Java Dockerfile"""
        return f"""FROM gradle:{app_data.get('java_version', '17')}-jdk AS build
WORKDIR /app
COPY . .
RUN gradle build --no-daemon

FROM openjdk:{app_data.get('java_version', '17')}-slim
WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar
EXPOSE {app_data.get('port', 8080)}
CMD ["java", "-jar", "app.jar"]
"""

    def _generate_generic_dockerfile(self, app_data):
        """Generate a generic Dockerfile"""
        return f"""FROM alpine:latest

WORKDIR /app
COPY . .

EXPOSE {app_data.get('port', 8080)}
CMD ["echo", "Replace with your application start command"]
"""

    def add_file_to_project(self, project_id, file_path, content):
        """Add a file to a GitLab project"""
        try:
            file_path_encoded = file_path.replace('/', '%2F')
            
            cmd = [
                'curl', '-s', '-X', 'POST',
                f"{self.gitlab_url}/api/v4/projects/{project_id}/repository/files/{file_path_encoded}",
                '-H', f"PRIVATE-TOKEN: {self.gitlab_token}",
                '-H', 'Content-Type: application/json',
                '-d', json.dumps({
                    'branch': 'main',
                    'content': content,
                    'commit_message': f"Add {file_path} via 1-click onboarding"
                })
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                logger.error(f"Failed to add file {file_path}: {result.stderr}")
                raise OnboardingError(
                    ERROR_FILE_CREATION,
                    status_code=500,
                    details=f"GitLab API error: {result.stderr}"
                )
                
            return True
        except Exception as e:
            logger.error(f"Failed to add file {file_path}: {str(e)}")
            logger.debug(traceback.format_exc())
            raise OnboardingError(
                ERROR_FILE_CREATION,
                status_code=500,
                details=f"Exception: {str(e)}"
            )
    
    def setup_project_webhooks(self, project_id, app_data):
        """Set up webhooks for the project"""
        try:
            webhook_url = f"{app_data.get('webhook_url', 'https://cicd-webhook.yourdomain.com/gitlab-webhook')}"
            
            cmd = [
                'curl', '-s', '-X', 'POST',
                f"{self.gitlab_url}/api/v4/projects/{project_id}/hooks",
                '-H', f"PRIVATE-TOKEN: {self.gitlab_token}",
                '-H', 'Content-Type: application/json',
                '-d', json.dumps({
                    'url': webhook_url,
                    'push_events': True,
                    'merge_requests_events': True,
                    'tag_push_events': True,
                    'enable_ssl_verification': True
                })
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                logger.error(f"Failed to set up webhook: {result.stderr}")
                raise OnboardingError(
                    ERROR_UNKNOWN,
                    status_code=500,
                    details=f"GitLab API error: {result.stderr}"
                )
                
            return True
        except Exception as e:
            logger.error(f"Failed to set up webhook: {str(e)}")
            logger.debug(traceback.format_exc())
            raise OnboardingError(
                ERROR_UNKNOWN,
                status_code=500,
                details=f"Exception: {str(e)}"
            )
    
    def _get_project_by_name(self, app_name):
        """Get a GitLab project by name"""
        try:
            cmd = [
                'curl', '-s',
                f"{self.gitlab_url}/api/v4/projects?search={app_name}",
                '-H', f"PRIVATE-TOKEN: {self.gitlab_token}"
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                logger.error(f"Failed to search for project: {result.stderr}")
                return None
            
            projects = json.loads(result.stdout)
            
            # Find exact match
            for project in projects:
                if project['name'].lower() == app_name.lower():
                    return project
            
            return None
        except Exception as e:
            logger.error(f"Failed to get project by name: {str(e)}")
            return None
    
    def _update_project_description(self, project_id, description):
        """Update a GitLab project description"""
        try:
            cmd = [
                'curl', '-s', '-X', 'PUT',
                f"{self.gitlab_url}/api/v4/projects/{project_id}",
                '-H', f"PRIVATE-TOKEN: {self.gitlab_token}",
                '-H', 'Content-Type: application/json',
                '-d', json.dumps({'description': description})
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                logger.error(f"Failed to update project description: {result.stderr}")
                raise OnboardingError(
                    "Failed to update project description",
                    status_code=500,
                    details=f"GitLab API error: {result.stderr}"
                )
            
            return True
        except Exception as e:
            logger.error(f"Failed to update project description: {str(e)}")
            raise OnboardingError(
                "Failed to update project description",
                status_code=500,
                details=f"Exception: {str(e)}"
            )
    
    def onboard_application(self, app_data):
        """Complete application onboarding process"""
        try:
            # Create GitLab project
            project = self.create_project(app_data)
            if not project:
                return {"status": "error", "message": "Failed to create GitLab project"}
                
            project_id = project['id']
            project_url = project['web_url']
            
            # Generate CI/CD pipeline
            pipeline_content = self.generate_ci_cd_pipeline(app_data)
            if not self.add_file_to_project(project_id, '.gitlab-ci.yml', pipeline_content):
                return {"status": "error", "message": "Failed to add CI/CD pipeline"}
                
            # Generate Dockerfile
            dockerfile_content = self._generate_dockerfile(app_data)
            if not self.add_file_to_project(project_id, 'Dockerfile', dockerfile_content):
                return {"status": "error", "message": "Failed to add Dockerfile"}
                
            # Generate K8s manifests
            manifests = self.generate_kubernetes_manifests(app_data)
            
            # Add K8s manifests to project
            for filename, content in manifests.items():
                self.add_file_to_project(project_id, f"deploy/{filename}", content)
                
            # Set up webhooks
            self.setup_project_webhooks(project_id, app_data)
            
            # Return success response
            return {
                "status": "success",
                "project_id": project_id,
                "project_url": project_url,
                "dev_url": f"https://{app_data['app_name']}-dev.yourdomain.com",
                "prod_url": f"https://{app_data['app_name']}.yourdomain.com"
            }
            
        except Exception as e:
            logger.error(f"Failed to onboard application: {str(e)}")
            logger.debug(traceback.format_exc())
            raise OnboardingError(
                ERROR_UNKNOWN,
                status_code=500,
                details=f"Exception: {str(e)}"
            )

# REST API endpoints
@app.route('/api/templates', methods=['GET'])
@limiter.limit("30 per minute")
def get_templates():
    """Get available application templates"""
    templates = [
        {
            "id": "nodejs",
            "name": "Node.js Application",
            "description": "JavaScript runtime for server-side applications",
            "icon": "fab fa-node-js",
            "color": "green",
            "default_port": 3000,
            "languages": ["JavaScript", "TypeScript"],
            "frameworks": ["Express", "Koa", "NestJS", "React (SSR)"]
        },
        {
            "id": "python",
            "name": "Python Application",
            "description": "Python-based backend service or API",
            "icon": "fab fa-python",
            "color": "blue",
            "default_port": 8000,
            "languages": ["Python"],
            "frameworks": ["FastAPI", "Flask", "Django"]
        },
        {
            "id": "java",
            "name": "Java Application",
            "description": "Enterprise Java service with Spring Boot",
            "icon": "fab fa-java",
            "color": "orange",
            "default_port": 8080,
            "languages": ["Java"],
            "frameworks": ["Spring Boot", "Quarkus", "Micronaut"]
        },
        {
            "id": "react",
            "name": "React Frontend",
            "description": "React single page application",
            "icon": "fab fa-react",
            "color": "blue",
            "default_port": 3000,
            "languages": ["JavaScript", "TypeScript"],
            "frameworks": ["React", "Next.js"]
        }
    ]
    
    return jsonify(templates)

@app.route('/api/onboard', methods=['POST'])
@limiter.limit("10 per minute")
def onboard_application():
    """Onboard a new application"""
    app_data = request.json
    
    # Validate required fields
    required_fields = ['app_name', 'framework', 'description', 'team_email']
    for field in required_fields:
        if field not in app_data or not app_data[field]:
            return jsonify({"status": "error", "message": f"Missing required field: {field}"}), 400
    
    # Sanitize app name (lowercase, alphanumeric with dashes)
    app_name = app_data['app_name'].lower()
    sanitized_name = ''.join(c if c.isalnum() or c == '-' else '-' for c in app_name)
    app_data['app_name'] = sanitized_name
    
    # Initialize onboarding service
    service = OnboardingService()
    
    # Start onboarding process
    result = service.onboard_application(app_data)
    
    if result["status"] == "error":
        return jsonify(result), 500
    
    return jsonify(result)

@app.route('/api/status/<app_name>', methods=['GET'])
@limiter.limit("30 per minute")
def get_application_status(app_name):
    """Get the status of an application"""
    try:
        # Check if app exists in GitLab
        cmd = [
            'curl', '-s',
            f"{GITLAB_URL}/api/v4/projects?search={app_name}",
            '-H', f"PRIVATE-TOKEN: {GITLAB_TOKEN}"
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        projects = json.loads(result.stdout)
        
        app_exists = False
        for project in projects:
            if project['name'].lower() == app_name.lower():
                app_exists = True
                project_id = project['id']
                break
                
        if not app_exists:
            return jsonify({"status": "error", "message": f"Application {app_name} not found"}), 404
            
        # Get deployment status
        cmd = [
            'curl', '-s',
            f"{GITLAB_URL}/api/v4/projects/{project_id}/environments",
            '-H', f"PRIVATE-TOKEN: {GITLAB_TOKEN}"
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        environments = json.loads(result.stdout)
        
        env_status = {}
        for env in environments:
            env_status[env['name']] = {
                "status": env['state'],
                "last_deployment": env.get('last_deployment', {}).get('created_at', 'Never'),
                "url": env.get('external_url', '')
            }
            
        return jsonify({
            "status": "success", 
            "app_name": app_name,
            "project_id": project_id,
            "environments": env_status
        })
        
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/api/applications/<app_name>', methods=['PUT'])
@limiter.limit("5 per minute")
@requires_auth
def update_application(app_name):
    """Update an existing application configuration"""
    try:
        app_data = request.json
        service = OnboardingService()
        
        # Get existing project
        project = service._get_project_by_name(app_name)
        if not project:
            return jsonify({
                "status": "error", 
                "message": f"Application {app_name} not found"
            }), 404
        
        project_id = project['id']
        
        # Update CI/CD pipeline if framework changed
        if 'framework' in app_data:
            pipeline_content = service.generate_ci_cd_pipeline(app_data)
            service.add_file_to_project(project_id, '.gitlab-ci.yml', pipeline_content)
        
        # Update Kubernetes manifests if configuration changed
        if any(key in app_data for key in ['replicas', 'memory_request', 'memory_limit', 'cpu_request', 'cpu_limit']):
            manifests = service.generate_kubernetes_manifests(app_data)
            for filename, content in manifests.items():
                service.add_file_to_project(project_id, f"deploy/{filename}", content)
        
        # Update project description if provided
        if 'description' in app_data:
            service._update_project_description(project_id, app_data['description'])
        
        logger.info(f"Application {app_name} updated successfully")
        return jsonify({
            "status": "success",
            "message": f"Application {app_name} updated successfully",
            "project_url": project['web_url']
        })
        
    except OnboardingError as e:
        return jsonify({
            "status": "error",
            "message": e.message,
            "details": e.details
        }), e.status_code
    except Exception as e:
        logger.error(f"Failed to update application {app_name}: {str(e)}")
        logger.debug(traceback.format_exc())
        return jsonify({
            "status": "error",
            "message": "Failed to update application",
            "details": str(e)
        }), 500

@app.route('/api/applications/<app_name>', methods=['DELETE'])
@limiter.limit("3 per minute")
@requires_auth
def delete_application(app_name):
    """Delete an application and its GitLab project"""
    try:
        service = OnboardingService()
        
        # Get project details
        project = service._get_project_by_name(app_name)
        if not project:
            return jsonify({
                "status": "error", 
                "message": f"Application {app_name} not found"
            }), 404
        
        project_id = project['id']
        
        # Confirm deletion with additional parameter
        confirm = request.args.get('confirm', '').lower()
        if confirm != 'true':
            return jsonify({
                "status": "error",
                "message": "Deletion requires confirmation. Add ?confirm=true to the request"
            }), 400
        
        # Delete the GitLab project
        cmd = [
            'curl', '-s', '-X', 'DELETE',
            f"{GITLAB_URL}/api/v4/projects/{project_id}",
            '-H', f"PRIVATE-TOKEN: {GITLAB_TOKEN}"
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            logger.error(f"Failed to delete GitLab project: {result.stderr}")
            raise OnboardingError(
                "Failed to delete GitLab project",
                status_code=500,
                details=f"GitLab API error: {result.stderr}"
            )
        
        logger.info(f"Application {app_name} deleted successfully")
        return jsonify({
            "status": "success",
            "message": f"Application {app_name} deleted successfully"
        })
        
    except OnboardingError as e:
        return jsonify({
            "status": "error",
            "message": e.message,
            "details": e.details
        }), e.status_code
    except Exception as e:
        logger.error(f"Failed to delete application {app_name}: {str(e)}")
        logger.debug(traceback.format_exc())
        return jsonify({
            "status": "error",
            "message": "Failed to delete application",
            "details": str(e)
        }), 500

@app.route('/api/applications', methods=['GET'])
@limiter.limit("30 per minute")
@requires_auth
def list_applications():
    """List all applications created through the onboarding portal"""
    try:
        # Get all projects from GitLab with onboarding tag
        cmd = [
            'curl', '-s',
            f"{GITLAB_URL}/api/v4/projects?tag_list=onboarded&per_page=100",
            '-H', f"PRIVATE-TOKEN: {GITLAB_TOKEN}"
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            logger.error(f"Failed to list projects: {result.stderr}")
            raise OnboardingError(
                "Failed to list applications",
                status_code=500,
                details=f"GitLab API error: {result.stderr}"
            )
        
        projects = json.loads(result.stdout)
        
        applications = []
        for project in projects:
            applications.append({
                "id": project['id'],
                "name": project['name'],
                "description": project['description'],
                "web_url": project['web_url'],
                "created_at": project['created_at'],
                "last_activity_at": project['last_activity_at'],
                "visibility": project['visibility']
            })
        
        return jsonify({
            "status": "success",
            "applications": applications,
            "total": len(applications)
        })
        
    except OnboardingError as e:
        return jsonify({
            "status": "error",
            "message": e.message,
            "details": e.details
        }), e.status_code
    except Exception as e:
        logger.error(f"Failed to list applications: {str(e)}")
        logger.debug(traceback.format_exc())
        return jsonify({
            "status": "error",
            "message": "Failed to list applications",
            "details": str(e)
        }), 500

@app.errorhandler(429)
def rate_limit_handler(e):
    """Handle rate limit exceeded errors"""
    logger.warning(f"Rate limit exceeded: {get_remote_address()}")
    return jsonify({
        "status": "error",
        "message": "Rate limit exceeded. Please try again later.",
        "retry_after": getattr(e, 'retry_after', 60)
    }), 429

@app.errorhandler(400)
def bad_request(error):
    """Handle 400 errors"""
    return jsonify({
        "status": "error",
        "message": "Bad request. Please check your input and try again."
    }), 400

@app.errorhandler(401)
def unauthorized(error):
    """Handle 401 errors"""
    return jsonify({
        "status": "error",
        "message": "Unauthorized. Please log in and try again."
    }), 401

@app.errorhandler(403)
def forbidden(error):
    """Handle 403 errors"""
    return jsonify({
        "status": "error",
        "message": "Forbidden. You don't have permission to perform this action."
    }), 403

@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    if request.path.startswith('/api/'):
        return jsonify({"status": "error", "message": "Resource not found"}), 404
    else:
        return render_template('error.html', 
                             error_code=404, 
                             error_message="Page not found"), 404

@app.errorhandler(500)
def server_error(error):
    """Handle 500 errors"""
    error_id = f"ERR-{int(time.time())}"
    logger.error(f"Server error {error_id}: {str(error)}")
    logger.debug(traceback.format_exc())
    
    if request.path.startswith('/api/'):
        return jsonify({
            "status": "error",
            "message": "Internal server error",
            "error_id": error_id
        }), 500
    else:
        return render_template('error.html', 
                             error_code=500, 
                             error_message="Internal server error",
                             error_id=error_id), 500

@app.errorhandler(Exception)
def handle_unexpected_error(error):
    """Handle any unexpected errors"""
    error_id = f"ERR-{int(time.time())}"
    logger.error(f"Unexpected error {error_id}: {str(error)}")
    logger.debug(traceback.format_exc())
    
    if request.path.startswith('/api/'):
        return jsonify({
            "status": "error",
            "message": "An unexpected error occurred",
            "error_id": error_id
        }), 500
    else:
        return render_template('error.html', 
                             error_code=500, 
                             error_message="An unexpected error occurred",
                             error_id=error_id), 500

# CSRF token generation endpoints
@app.route('/api/csrf-token', methods=['GET'])
def get_csrf_token():
    """Get CSRF token for forms"""
    # For now, generate a simple token (in production, use proper CSRF protection)
    csrf_token = secrets.token_hex(16)
    session['csrf_token'] = csrf_token
    return jsonify({"csrf_token": csrf_token})

# Web Routes (User Interface)
@app.route('/')
def index():
    """Main onboarding interface"""
    return render_template('index.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    """Login page"""
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        # Basic authentication check (replace with your authentication system)
        if username and password:
            # In production, validate against LDAP/AD/SSO
            # For demo purposes, accept any non-empty credentials
            session['authenticated'] = True
            session['username'] = username
            
            next_page = request.args.get('next')
            if next_page:
                return redirect(next_page)
            return redirect(url_for('dashboard'))
        else:
            flash('Please enter both username and password', 'error')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    """Logout and clear session"""
    session.clear()
    flash('You have been logged out successfully', 'info')
    return redirect(url_for('index'))

@app.route('/dashboard')
@requires_auth
def dashboard():
    """User dashboard showing onboarded applications"""
    try:
        # Get user's applications
        service = OnboardingService()
        
        # Get all projects from GitLab with onboarding tag
        cmd = [
            'curl', '-s',
            f"{GITLAB_URL}/api/v4/projects?tag_list=onboarded&per_page=100",
            '-H', f"PRIVATE-TOKEN: {GITLAB_TOKEN}"
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        projects = json.loads(result.stdout) if result.returncode == 0 else []
        
        # Get environment status for each project
        applications = []
        for project in projects:
            app_info = {
                "id": project['id'],
                "name": project['name'],
                "description": project['description'],
                "web_url": project['web_url'],
                "created_at": project['created_at'],
                "environments": {}
            }
            
            # Get environments for this project
            env_cmd = [
                'curl', '-s',
                f"{GITLAB_URL}/api/v4/projects/{project['id']}/environments",
                '-H', f"PRIVATE-TOKEN: {GITLAB_TOKEN}"
            ]
            
            env_result = subprocess.run(env_cmd, capture_output=True, text=True)
            if env_result.returncode == 0:
                environments = json.loads(env_result.stdout)
                for env in environments:
                    app_info["environments"][env['name']] = {
                        "status": env['state'],
                        "url": env.get('external_url', '')
                    }
            
            applications.append(app_info)
        
        return render_template('dashboard.html', 
                             applications=applications,
                             username=session.get('username', 'User'))
        
    except Exception as e:
        logger.error(f"Failed to load dashboard: {str(e)}")
        flash('Error loading dashboard', 'error')
        return render_template('dashboard.html', applications=[], username=session.get('username', 'User'))

if __name__ == '__main__':
    # Create templates directory if it doesn't exist
    os.makedirs('templates', exist_ok=True)
    os.makedirs('static', exist_ok=True)
    
    # Check for required environment variables
    if not GITLAB_TOKEN:
        logger.error("GITLAB_TOKEN environment variable is required")
        sys.exit(1)
    
    # Run the application
    logger.info("Starting 1-Click Application Onboarding Portal...")
    app.run(
        host='0.0.0.0',
        port=int(os.getenv('PORT', 5000)),
        debug=os.getenv('DEBUG', 'False').lower() == 'true'
    )
