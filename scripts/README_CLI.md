# 1-Click Onboarding CLI Tool

The CLI tool provides a command-line interface for the 1-Click Application Onboarding process, allowing for scripted or interactive onboarding without the web interface.

## Dependencies

This tool requires the following Python packages:

```
requests>=2.25.0
tqdm>=4.60.0
pyfiglet>=0.8.0
```

Install dependencies with:

```bash
pip install requests tqdm pyfiglet
```

## Configuration

Set the following environment variables to customize the behavior:

```bash
# Set the portal URL (default: http://localhost:5000)
export PORTAL_URL="https://onboarding.yourdomain.com"

# Set the GitLab URL (default: https://gitlab.yourdomain.com)
export GITLAB_URL="https://gitlab.yourdomain.com"
```

## Usage

```bash
# Deploy a new application (interactive)
./onboarding_cli.py --deploy

# Check status of an existing application
./onboarding_cli.py --status my-application

# Display help
./onboarding_cli.py --help
```

## Interactive Deployment Walkthrough

When running with the `--deploy` flag, you'll be guided through these steps:

1. **Template Selection**: Choose from Node.js, Python, Java, or React templates
2. **Application Configuration**: Enter app name, description, team email, etc.
3. **Resource Configuration**: Set CPU and memory limits for Kubernetes
4. **Deployment**: The application will be deployed to GitLab and Kubernetes

## Environment Variables

- `PORTAL_URL`: URL to the onboarding portal API (default: http://localhost:5000)
- `GITLAB_URL`: URL to the GitLab instance (default: https://gitlab.yourdomain.com)

## Examples

```bash
# Set portal URL and deploy
export PORTAL_URL=https://onboarding.yourdomain.com
./onboarding_cli.py --deploy

# Check application status with custom portal URL
export PORTAL_URL=https://onboarding.yourdomain.com
./onboarding_cli.py --status my-nodejs-app
```

## Automation

For automation in scripts, you can use the portal's REST API:

```bash
# Create config file
cat > config.json << EOF
{
  "app_name": "my-automated-app",
  "description": "Automated deployment example",
  "team_email": "devops@example.com",
  "framework": "nodejs",
  "port": 3000,
  "replicas": 2,
  "memory_request": "256Mi", 
  "memory_limit": "512Mi",
  "cpu_request": "100m",
  "cpu_limit": "500m"
}
EOF

# Deploy using curl
curl -X POST "https://onboarding.yourdomain.com/api/onboard" \
  -H "Content-Type: application/json" \
  -d @config.json
  "cpu_request": "100m",
  "cpu_limit": "200m"
}
EOF

# Use config with curl
curl -X POST https://onboarding.yourdomain.com/api/onboard \
  -H "Content-Type: application/json" \
  -d @config.json
```
