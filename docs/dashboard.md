# DevOps Suite Dashboard

The DevOps Suite Dashboard provides a centralized web portal to access all the services deployed in your OpenStack DevOps Suite. This document explains how to use and customize the dashboard.

## Features

- **Service Access**: Quick access to all deployed services through a unified interface
- **Service Status**: Real-time status indicators for each service
- **Responsive Design**: Works on desktop and mobile devices
- **Dark Mode Support**: Automatically adapts to user's system preferences

## Accessing the Dashboard

The dashboard is accessible through your Nginx proxy server:

```
https://<your-nginx-domain>/
```

## Customization

You can customize the dashboard by modifying the following variables in your inventory file or group_vars:

| Variable | Description | Default |
|----------|-------------|---------|
| `dashboard_title` | Title displayed on the dashboard | "OpenStack DevOps Suite" |
| `dashboard_description` | Description text below title | "A comprehensive suite of DevOps tools..." |
| `dashboard_logo_enabled` | Whether to display the logo | true |
| `dashboard_logo_path` | Path to the logo file | "/var/www/html/assets/logo.svg" |

## Service Status Indicators

The dashboard includes automatic service status indicators that show:

- **Online** (green): Service is up and responding normally
- **Maintenance** (amber): Service is accessible but may be experiencing issues
- **Offline** (red): Service is not accessible

Service status is checked every 5 minutes via a cron job and displayed in real-time on the dashboard.

## Adding Custom Services

To add custom services to the dashboard, extend the `service_urls` variable in your inventory:

```yaml
service_urls:
  gitlab: "http://gitlab-server:8090"
  # Add your custom service
  grafana: "http://grafana-server:3000"
```

Then update the dashboard HTML template to include your new service.

## Troubleshooting

If service statuses are not updating:

1. Check that the cron job is running: `sudo crontab -u nginx -l`
2. Verify the status file is being created: `cat /var/www/html/assets/status.json`
3. Ensure the Python script can access the services: `sudo -u nginx python3 /usr/local/bin/check_services.py --services '{"gitlab": "http://gitlab-server:8090"}' --output /tmp/test-status.json`

## Security Notes

The dashboard uses HTTPS with modern cipher suites and includes several security headers:
- Strict Transport Security (HSTS)
- Content Security Policy
- X-XSS-Protection
- X-Frame-Options

These security features can be adjusted in the `nginx_proxy` role's defaults.
