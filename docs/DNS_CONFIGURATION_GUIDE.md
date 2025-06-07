# DNS Configuration Guide for Kubernetes Ingress

## Overview

When deploying the OpenStack DevOps Suite to Kubernetes, proper DNS configuration is required for external access to services via Ingress controllers. This guide covers the DNS setup for both cloud providers and on-premises deployments.

## Prerequisites

- Kubernetes cluster with Ingress controller deployed
- Domain name ownership and DNS management access
- LoadBalancer service support (cloud provider or MetalLB)

## DNS Record Types

### A Records (Recommended)
Point subdomains directly to the LoadBalancer IP:

```dns
gitlab.yourdomain.com      A    <loadbalancer-ip>
dashboard.yourdomain.com   A    <loadbalancer-ip>
rancher.yourdomain.com     A    <loadbalancer-ip>
keycloak.yourdomain.com    A    <loadbalancer-ip>
nexus.yourdomain.com       A    <loadbalancer-ip>
docker.yourdomain.com      A    <loadbalancer-ip>
```

### CNAME Records (Alternative)
Use a wildcard approach:

```dns
*.devops.yourdomain.com    CNAME    devops.yourdomain.com
devops.yourdomain.com      A        <loadbalancer-ip>
```

## Getting the LoadBalancer IP

### Method 1: kubectl Command
```bash
# Get the external IP of the ingress controller
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller

# Alternative for different ingress installations
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

### Method 2: Ingress Resource
```bash
# Check ingress status
kubectl get ingress -n devops-suite

# Describe ingress for detailed information
kubectl describe ingress devops-suite-ingress -n devops-suite
```

### Method 3: Provider-Specific Commands

#### AWS EKS
```bash
# Get ELB hostname
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Resolve to IP (if needed)
nslookup <elb-hostname>
```

#### Google GKE
```bash
# Get external IP
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

#### Azure AKS
```bash
# Get public IP
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

#### OpenStack
```bash
# Get floating IP
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Check OpenStack load balancer
openstack loadbalancer list
```

## DNS Provider Configuration

### Cloudflare

1. **Login to Cloudflare Dashboard**
2. **Select your domain**
3. **Go to DNS management**
4. **Add A records**:

```
Type: A
Name: gitlab
Content: <loadbalancer-ip>
TTL: Auto
Proxy status: DNS only (grey cloud)

Type: A
Name: dashboard
Content: <loadbalancer-ip>
TTL: Auto
Proxy status: DNS only (grey cloud)

# Repeat for all services...
```

### AWS Route 53

```bash
# Create hosted zone (if not exists)
aws route53 create-hosted-zone --name yourdomain.com --caller-reference $(date +%s)

# Get hosted zone ID
ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='yourdomain.com.'].Id" --output text | cut -d'/' -f3)

# Create A records
cat > change-batch.json << EOF
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "gitlab.yourdomain.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "<loadbalancer-ip>"}]
      }
    },
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "dashboard.yourdomain.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "<loadbalancer-ip>"}]
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch file://change-batch.json
```

### Google Cloud DNS

```bash
# Create DNS zone (if not exists)
gcloud dns managed-zones create devops-zone --dns-name=yourdomain.com. --description="DevOps Suite DNS"

# Add A records
gcloud dns record-sets transaction start --zone=devops-zone

gcloud dns record-sets transaction add <loadbalancer-ip> \
  --name=gitlab.yourdomain.com. \
  --ttl=300 \
  --type=A \
  --zone=devops-zone

gcloud dns record-sets transaction add <loadbalancer-ip> \
  --name=dashboard.yourdomain.com. \
  --ttl=300 \
  --type=A \
  --zone=devops-zone

gcloud dns record-sets transaction execute --zone=devops-zone
```

### Azure DNS

```bash
# Create DNS zone (if not exists)
az network dns zone create -g myResourceGroup -n yourdomain.com

# Add A records
az network dns record-set a add-record \
  -g myResourceGroup \
  -z yourdomain.com \
  -n gitlab \
  -a <loadbalancer-ip>

az network dns record-set a add-record \
  -g myResourceGroup \
  -z yourdomain.com \
  -n dashboard \
  -a <loadbalancer-ip>
```

### DigitalOcean DNS

```bash
# Using doctl CLI
doctl compute domain records create yourdomain.com \
  --record-type A \
  --record-name gitlab \
  --record-data <loadbalancer-ip>

doctl compute domain records create yourdomain.com \
  --record-type A \
  --record-name dashboard \
  --record-data <loadbalancer-ip>
```

## On-Premises DNS Configuration

### BIND9 Configuration

Add to your zone file:

```bind
; DevOps Suite services
gitlab      IN  A   <loadbalancer-ip>
dashboard   IN  A   <loadbalancer-ip>
rancher     IN  A   <loadbalancer-ip>
keycloak    IN  A   <loadbalancer-ip>
nexus       IN  A   <loadbalancer-ip>
docker      IN  A   <loadbalancer-ip>
```

### dnsmasq Configuration

Add to `/etc/dnsmasq.conf`:

```
# DevOps Suite services
address=/gitlab.yourdomain.com/<loadbalancer-ip>
address=/dashboard.yourdomain.com/<loadbalancer-ip>
address=/rancher.yourdomain.com/<loadbalancer-ip>
address=/keycloak.yourdomain.com/<loadbalancer-ip>
address=/nexus.yourdomain.com/<loadbalancer-ip>
address=/docker.yourdomain.com/<loadbalancer-ip>
```

### Windows DNS Server

```powershell
# Add A records using PowerShell
Add-DnsServerResourceRecordA -ZoneName "yourdomain.com" -Name "gitlab" -IPv4Address "<loadbalancer-ip>"
Add-DnsServerResourceRecordA -ZoneName "yourdomain.com" -Name "dashboard" -IPv4Address "<loadbalancer-ip>"
Add-DnsServerResourceRecordA -ZoneName "yourdomain.com" -Name "rancher" -IPv4Address "<loadbalancer-ip>"
Add-DnsServerResourceRecordA -ZoneName "yourdomain.com" -Name "keycloak" -IPv4Address "<loadbalancer-ip>"
Add-DnsServerResourceRecordA -ZoneName "yourdomain.com" -Name "nexus" -IPv4Address "<loadbalancer-ip>"
Add-DnsServerResourceRecordA -ZoneName "yourdomain.com" -Name "docker" -IPv4Address "<loadbalancer-ip>"
```

## Wildcard DNS (Advanced)

### Cloudflare Wildcard
```
Type: A
Name: *.devops
Content: <loadbalancer-ip>
TTL: Auto
Proxy status: DNS only
```

### BIND9 Wildcard
```bind
*.devops    IN  A   <loadbalancer-ip>
```

### Ingress Configuration for Wildcard
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: devops-suite-wildcard-ingress
  namespace: devops-suite
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - "*.devops.yourdomain.com"
    secretName: wildcard-tls-secret
  rules:
  - host: gitlab.devops.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: gitlab
            port:
              number: 80
  # Add more rules for other services...
```

## Verification and Testing

### DNS Resolution Testing

```bash
# Test DNS resolution
nslookup gitlab.yourdomain.com
dig gitlab.yourdomain.com

# Test all services
for service in gitlab dashboard rancher keycloak nexus docker; do
  echo "Testing $service.yourdomain.com:"
  nslookup $service.yourdomain.com
  echo "---"
done
```

### HTTP/HTTPS Testing

```bash
# Test HTTP connectivity
curl -I http://gitlab.yourdomain.com

# Test HTTPS (if SSL is configured)
curl -I https://gitlab.yourdomain.com

# Test all services
for service in gitlab dashboard rancher keycloak nexus docker; do
  echo "Testing https://$service.yourdomain.com:"
  curl -I -k https://$service.yourdomain.com
  echo "---"
done
```

### Certificate Verification

```bash
# Check SSL certificate
openssl s_client -connect gitlab.yourdomain.com:443 -servername gitlab.yourdomain.com

# Check certificate expiry
echo | openssl s_client -connect gitlab.yourdomain.com:443 -servername gitlab.yourdomain.com 2>/dev/null | openssl x509 -noout -dates
```

## Troubleshooting DNS Issues

### Common Problems

#### 1. DNS Propagation Delay
```bash
# Check different DNS servers
dig @8.8.8.8 gitlab.yourdomain.com
dig @1.1.1.1 gitlab.yourdomain.com
dig @208.67.222.222 gitlab.yourdomain.com

# Check local DNS cache
sudo systemctl flush-dns  # macOS
sudo systemctl restart systemd-resolved  # Linux
ipconfig /flushdns  # Windows
```

#### 2. Wrong LoadBalancer IP
```bash
# Verify ingress controller service
kubectl get svc -n ingress-nginx -o wide

# Check service endpoints
kubectl get endpoints -n ingress-nginx

# Describe service for events
kubectl describe svc -n ingress-nginx nginx-ingress-ingress-nginx-controller
```

#### 3. Ingress Not Working
```bash
# Check ingress status
kubectl get ingress -n devops-suite

# Verify ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Check ingress events
kubectl describe ingress devops-suite-ingress -n devops-suite
```

#### 4. SSL Certificate Issues
```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate status
kubectl get certificates -n devops-suite

# Check certificate request status
kubectl get certificaterequest -n devops-suite

# Describe certificate for details
kubectl describe certificate -n devops-suite
```

### Debug Commands

```bash
# Complete DNS and connectivity test
./scripts/test-dns.sh

# Manual connectivity test
for service in gitlab dashboard rancher keycloak nexus docker; do
  echo "=== Testing $service.yourdomain.com ==="
  echo "DNS Resolution:"
  nslookup $service.yourdomain.com
  echo "HTTP Response:"
  curl -I -k https://$service.yourdomain.com || curl -I http://$service.yourdomain.com
  echo ""
done

# Kubernetes-specific debugging
kubectl get all -n devops-suite
kubectl get ingress -n devops-suite
kubectl get certificates -n devops-suite
kubectl describe ingress -n devops-suite
```

## DNS Automation Scripts

### Create DNS Test Script

```bash
#!/bin/bash
# scripts/test-dns.sh

DOMAIN="${DOMAIN_NAME:-yourdomain.com}"
SERVICES=("gitlab" "dashboard" "rancher" "keycloak" "nexus" "docker")

echo "Testing DNS configuration for $DOMAIN"
echo "====================================="

# Get LoadBalancer IP
LB_IP=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [[ -z "$LB_IP" || "$LB_IP" == "null" ]]; then
    echo "❌ LoadBalancer IP not found"
    echo "Check: kubectl get svc -n ingress-nginx"
    exit 1
fi

echo "✅ LoadBalancer IP: $LB_IP"
echo ""

# Test each service
for service in "${SERVICES[@]}"; do
    echo "Testing $service.$DOMAIN:"
    
    # DNS resolution
    RESOLVED_IP=$(dig +short $service.$DOMAIN | grep -E '^[0-9.]+$' | head -1)
    
    if [[ "$RESOLVED_IP" == "$LB_IP" ]]; then
        echo "  ✅ DNS: $RESOLVED_IP (correct)"
    else
        echo "  ❌ DNS: $RESOLVED_IP (expected: $LB_IP)"
    fi
    
    # HTTP test
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://$service.$DOMAIN/ 2>/dev/null || echo "000")
    if [[ "$HTTP_STATUS" =~ ^[23] ]]; then
        echo "  ✅ HTTP: $HTTP_STATUS"
    else
        echo "  ❌ HTTP: $HTTP_STATUS"
    fi
    
    # HTTPS test
    HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 -k https://$service.$DOMAIN/ 2>/dev/null || echo "000")
    if [[ "$HTTPS_STATUS" =~ ^[23] ]]; then
        echo "  ✅ HTTPS: $HTTPS_STATUS"
    else
        echo "  ❌ HTTPS: $HTTPS_STATUS"
    fi
    
    echo ""
done

echo "DNS testing completed."
```

### Create DNS Setup Script

```bash
#!/bin/bash
# scripts/setup-dns.sh

DOMAIN="${DOMAIN_NAME:-yourdomain.com}"
PROVIDER="${DNS_PROVIDER:-manual}"

# Get LoadBalancer IP
LB_IP=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [[ -z "$LB_IP" || "$LB_IP" == "null" ]]; then
    echo "❌ LoadBalancer IP not found"
    exit 1
fi

echo "LoadBalancer IP: $LB_IP"
echo "Domain: $DOMAIN"
echo "Provider: $PROVIDER"
echo ""

case "$PROVIDER" in
    "cloudflare")
        echo "Configure these A records in Cloudflare:"
        ;;
    "route53")
        echo "Configure these A records in Route 53:"
        ;;
    "manual")
        echo "Configure these DNS A records:"
        ;;
esac

echo ""
for service in gitlab dashboard rancher keycloak nexus docker; do
    echo "$service.$DOMAIN    A    $LB_IP"
done

echo ""
echo "After configuring DNS, test with:"
echo "./scripts/test-dns.sh"
```

Make the scripts executable:

```bash
chmod +x scripts/test-dns.sh
chmod +x scripts/setup-dns.sh
```

## Integration with Hybrid Deployment

The hybrid deployment script automatically provides DNS configuration information:

```bash
# Deploy with Kubernetes support
export DOMAIN_NAME="yourdomain.com"
./scripts/deploy-hybrid.sh k8s-only

# The script will show required DNS configuration
# Follow the displayed instructions to configure your DNS provider
```

## Conclusion

Proper DNS configuration is essential for Kubernetes-based deployments. This guide provides comprehensive instructions for various DNS providers and includes automation scripts to simplify the process.

Key points:
- Always use A records pointing to the LoadBalancer IP
- Test DNS resolution before configuring SSL certificates
- Use the provided scripts for automation and testing
- Monitor certificate renewals for Let's Encrypt integration

For additional support, refer to your DNS provider's documentation or the Kubernetes Ingress controller documentation.
