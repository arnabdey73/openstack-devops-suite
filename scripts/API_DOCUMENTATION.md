# 1-Click Application Onboarding System - API Documentation

## Overview

The 1-Click Application Onboarding System provides a streamlined way to onboard applications into your DevOps pipeline. It automatically creates GitLab projects, generates CI/CD pipelines, Kubernetes manifests, and Dockerfiles based on your application framework.

## Features

### ✅ Completed Features

- **Security Headers**: Comprehensive HTTP security headers for all responses
- **API Rate Limiting**: Configurable rate limits to prevent abuse
- **Application Management**: Full CRUD operations for onboarded applications
- **Enhanced Error Handling**: Proper error responses with detailed logging
- **CSRF Protection Setup**: Ready for flask-wtf integration
- **Integration Testing**: Comprehensive test suite for validation
- **Authentication System**: Basic authentication with session management
- **Web Interface**: Complete dashboard and onboarding interface
- **End-to-End Testing**: Deployment flow validation script

### 🔧 Framework Support

- **Node.js**: Express, Koa, NestJS, React SSR
- **Python**: FastAPI, Flask, Django
- **Java**: Spring Boot, Quarkus, Micronaut
- **React**: Single Page Applications, Next.js

## API Endpoints

### Public Endpoints

#### GET `/api/templates`
Get available application templates.

**Rate Limit**: 30 requests per minute

**Response**:
```json
{
  "templates": [
    {
      "id": "nodejs",
      "name": "Node.js Application",
      "description": "JavaScript runtime for server-side applications",
      "icon": "fab fa-node-js",
      "color": "green",
      "default_port": 3000,
      "languages": ["JavaScript", "TypeScript"],
      "frameworks": ["Express", "Koa", "NestJS", "React (SSR)"]
    }
  ]
}
```

#### POST `/api/onboard`
Onboard a new application.

**Rate Limit**: 10 requests per minute

**Request Body**:
```json
{
  "app_name": "my-awesome-app",
  "framework": "nodejs",
  "description": "My awesome Node.js application",
  "team_email": "team@example.com",
  "port": 3000,
  "replicas": 3,
  "memory_request": "256Mi",
  "memory_limit": "512Mi",
  "cpu_request": "100m",
  "cpu_limit": "500m"
}
```

**Response**:
```json
{
  "status": "success",
  "project_id": 123,
  "project_url": "https://gitlab.yourdomain.com/my-awesome-app",
  "dev_url": "https://my-awesome-app-dev.yourdomain.com",
  "prod_url": "https://my-awesome-app.yourdomain.com"
}
```

#### GET `/api/status/{app_name}`
Get the deployment status of an application.

**Rate Limit**: 30 requests per minute

**Response**:
```json
{
  "status": "success",
  "app_name": "my-awesome-app",
  "project_id": 123,
  "environments": {
    "development": {
      "status": "available",
      "last_deployment": "2025-06-08T10:30:00Z",
      "url": "https://my-awesome-app-dev.yourdomain.com"
    },
    "production": {
      "status": "available",
      "last_deployment": "2025-06-08T09:15:00Z",
      "url": "https://my-awesome-app.yourdomain.com"
    }
  }
}
```

### Authenticated Endpoints

#### GET `/api/applications`
List all onboarded applications.

**Rate Limit**: 30 requests per minute
**Authentication**: Required

**Response**:
```json
{
  "status": "success",
  "applications": [
    {
      "id": 123,
      "name": "my-awesome-app",
      "description": "My awesome application",
      "web_url": "https://gitlab.yourdomain.com/my-awesome-app",
      "created_at": "2025-06-08T08:00:00Z",
      "last_activity_at": "2025-06-08T10:30:00Z",
      "visibility": "private"
    }
  ],
  "total": 1
}
```

#### PUT `/api/applications/{app_name}`
Update an existing application configuration.

**Rate Limit**: 5 requests per minute
**Authentication**: Required

**Request Body**:
```json
{
  "framework": "python",
  "description": "Updated description",
  "replicas": 5
}
```

#### DELETE `/api/applications/{app_name}`
Delete an application and its resources.

**Rate Limit**: 3 requests per minute
**Authentication**: Required

**Response**:
```json
{
  "status": "success",
  "message": "Application deleted successfully"
}
```

### Utility Endpoints

#### GET `/api/csrf-token`
Get CSRF token for form submissions.

**Response**:
```json
{
  "csrf_token": "abc123def456..."
}
```

## Web Interface Routes

### Public Routes

- `GET /` - Main onboarding interface
- `GET /login` - Login page
- `POST /login` - Process login
- `GET /logout` - Logout and clear session

### Authenticated Routes

- `GET /dashboard` - User dashboard with application overview

## Security Features

### Rate Limiting

Different endpoints have different rate limits:

- **Template/Status endpoints**: 30 requests per minute
- **Onboarding**: 10 requests per minute
- **Updates**: 5 requests per minute
- **Deletes**: 3 requests per minute
- **Global limits**: 200 requests per day, 50 per hour

### Security Headers

All responses include comprehensive security headers:

- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- `Content-Security-Policy: ...`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy: ...`

### Authentication

Basic session-based authentication is implemented. In production environments, integrate with your organization's SSO/LDAP system.

### CSRF Protection

CSRF protection infrastructure is in place and ready for activation when flask-wtf is installed.

## Error Handling

### HTTP Status Codes

- `200` - Success
- `400` - Bad Request (missing required fields)
- `401` - Unauthorized (authentication required)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found (resource doesn't exist)
- `429` - Too Many Requests (rate limit exceeded)
- `500` - Internal Server Error

### Error Response Format

```json
{
  "status": "error",
  "message": "Human-readable error message",
  "details": "Technical details (optional)",
  "error_id": "ERR-1686225600 (optional)"
}
```

## Generated Files

### CI/CD Pipeline (`.gitlab-ci.yml`)

Automatically generated GitLab CI/CD pipeline with:

- **Build stage**: Docker image building and registry push
- **Deploy-dev stage**: Automatic deployment to development environment
- **Deploy-prod stage**: Manual deployment to production environment

### Kubernetes Manifests

Generated in `deploy/` directory:

- `deployment.yaml` - Application deployment with resource limits
- `service.yaml` - Kubernetes service for internal communication
- `ingress.yaml` - Ingress for external access with TLS
- `configmap.yaml` - Application configuration

### Dockerfile

Framework-specific Dockerfiles with best practices:

- Multi-stage builds for Java applications
- Optimized layer caching
- Security best practices
- Health check endpoints

## Environment Configuration

### Required Environment Variables

```bash
GITLAB_URL=https://gitlab.yourdomain.com
GITLAB_TOKEN=your_gitlab_personal_access_token
SECRET_KEY=your_secret_key_for_sessions
```

### Optional Environment Variables

```bash
# Portal Configuration
PORT=5000
DEBUG=false
SECURE_COOKIES=true

# External Services
NEXUS_URL=https://nexus.yourdomain.com

# Authentication (for production)
ADMIN_USERNAME=admin
ADMIN_PASSWORD=secure_password
```

## Installation and Setup

### 1. Install Dependencies

```bash
cd /Users/arnabd73/Documents/openstack-devops-suite/scripts
pip install -r requirements.txt
```

### 2. Configure Environment

```bash
export GITLAB_URL="https://your-gitlab.com"
export GITLAB_TOKEN="your-token-here"
export SECRET_KEY="your-secret-key"
```

### 3. Run the Application

```bash
python onboarding_portal.py
```

### 4. Access the Interface

- Web Interface: http://localhost:5000
- API Documentation: This document
- Health Check: http://localhost:5000/api/templates

## Testing

### Unit Tests

```bash
python test_runner.py
```

### Integration Tests

```bash
python test_onboarding.py
```

### End-to-End Deployment Flow

```bash
python test_deployment_flow.py
```

## Production Deployment

### Using Gunicorn

```bash
gunicorn --bind 0.0.0.0:5000 --workers 4 onboarding_portal:app
```

### Docker Deployment

Use the provided `Dockerfile` in the scripts directory:

```bash
docker build -t onboarding-portal .
docker run -p 5000:5000 -e GITLAB_TOKEN=$GITLAB_TOKEN onboarding-portal
```

### Kubernetes Deployment

Use the manifest in `k8s/onboarding-portal.yaml`:

```bash
kubectl apply -f ../k8s/onboarding-portal.yaml
```

## Troubleshooting

### Common Issues

1. **GitLab API Connection Failed**
   - Verify `GITLAB_URL` and `GITLAB_TOKEN`
   - Check network connectivity to GitLab instance
   - Ensure token has appropriate permissions

2. **Rate Limiting Issues**
   - Check if Redis is available for distributed rate limiting
   - Adjust rate limits in application configuration
   - Monitor application logs for rate limit violations

3. **Template Loading Errors**
   - Ensure `templates/` directory exists
   - Check file permissions
   - Verify template syntax

4. **Authentication Issues**
   - Check session configuration
   - Verify `SECRET_KEY` is set
   - Ensure cookies are enabled in browser

### Logging

Application logs are written to:
- Console output (stdout)
- `onboarding.log` file
- Test logs: `*test*.log` files

### Health Checks

Monitor these endpoints for system health:

- `/api/templates` - API functionality
- `/` - Web interface
- GitLab API connectivity (check logs)

## Contributing

1. Follow the existing code structure
2. Add tests for new features
3. Update documentation
4. Follow security best practices
5. Test rate limiting and error handling

## License

This project is part of the OpenStack DevOps Suite. Please refer to the main project license.
