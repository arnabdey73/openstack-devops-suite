# 1-Click Application Onboarding

The 1-Click Application Onboarding portal provides a Vercel-like experience for deploying applications to the GitLab-Centered DevOps Suite. This document explains how to use both the web interface and CLI tool for onboarding new applications.

## Overview

The onboarding process automates:

- GitLab project creation with proper settings
- CI/CD pipeline configuration
- Kubernetes manifest generation
- Dockerfile creation
- Project webhook setup

## Security Features

The onboarding portal includes the following security features:

- **Authentication**: Secure login system to control access
- **Session Management**: Encrypted session cookies
- **HTTPS Support**: Secure communication when deployed to production
- **Error Handling**: Robust error handling with detailed logging
- **Container Security**: Non-root user execution and reduced privileges
- **Least Privilege**: Minimized container capabilities

## Prerequisites

Before using the onboarding portal, ensure:

1. The GitLab-Centered DevOps Suite is deployed
2. GitLab API token with appropriate permissions is configured
3. Domain name is properly configured
4. Kubernetes cluster is accessible
5. Admin credentials are configured (see below)

## Using the Web Interface

### Authentication

The portal requires authentication. Default credentials:

- **Username**: admin
- **Password**: changeme

**Important**: Change the default password in production by updating the environment variables or Kubernetes secrets.

### Accessing the Portal

The onboarding portal is available at:

- **Development**: http://localhost:5000
- **Production**: https://onboarding.yourdomain.com

### Step 1: Select Template

Choose from available application templates:

- **Node.js Application**: Server-side JavaScript applications
- **Python Application**: Python-based services and APIs
- **Java Application**: Enterprise Java services with Spring Boot
- **React Frontend**: Frontend applications using React

### Step 2: Configure Application

Fill in basic information:

- **Application Name**: Lowercase with dashes, e.g., `my-app`
- **Description**: Brief description of your application
- **Team Email**: Contact email for the application team
- **Framework**: Specific framework within the selected template
- **Port**: Application port (defaults based on template)
- **Replicas**: Number of pod replicas for Kubernetes deployment

### Step 3: Resource Configuration

Configure Kubernetes resource allocation:

- **Memory Request/Limit**: Memory allocation for containers
- **CPU Request/Limit**: CPU allocation for containers

### Step 4: Deployment

After clicking "Deploy Application", the system will:

1. Create a GitLab project
2. Generate CI/CD pipeline configuration
3. Create Kubernetes deployment manifests
4. Add Dockerfile and other necessary files
5. Set up project webhooks

Upon completion, you'll receive links to:
- GitLab repository
- Development environment URL
- Production environment URL

## Using the CLI Tool

For automation or command-line preference, use the CLI tool:

```bash
# Deploy a new application (interactive)
./scripts/onboarding_cli.py --deploy

# Check status of an existing application
./scripts/onboarding_cli.py --status my-application
```

## Post-Deployment Steps

After onboarding, you should:

1. **Clone the repository**:
   ```bash
   git clone https://<gitlab-url>/<your-project>.git
   cd <your-project>
   ```

2. **Implement your application code**

3. **Push to trigger CI/CD pipeline**:
   ```bash
   git add .
   git commit -m "Initial implementation"
   git push
   ```

4. **Monitor pipeline** in GitLab CI/CD interface

5. **Access development environment** at https://<app-name>-dev.yourdomain.com

6. **Promote to production** through the GitLab CI/CD pipeline (manual trigger)

## Application Structure

The onboarded application will include:

- **/.gitlab-ci.yml**: CI/CD pipeline configuration
- **/Dockerfile**: Container build instructions
- **/deploy/**: Kubernetes manifests
  - deployment.yaml
  - service.yaml
  - ingress.yaml
  - configmap.yaml

## Troubleshooting

If you encounter issues:

1. **Check GitLab pipeline logs** for build or deploy errors
2. **Verify Kubernetes resources**:
   ```bash
   kubectl get all -n apps-dev -l app=<app-name>
   ```
3. **Review pod logs**:
   ```bash
   kubectl logs -n apps-dev deployment/<app-name>
   ```
4. **Verify ingress configuration**:
   ```bash
   kubectl get ingress -n apps-dev
   ```

## Best Practices

1. **Use meaningful application names** that identify the purpose
2. **Set appropriate resource requests/limits** based on application needs
3. **Add proper health checks** to your application code
4. **Use GitLab environments** for managing different deployment stages
5. **Add application-specific environment variables** through the CI/CD interface
