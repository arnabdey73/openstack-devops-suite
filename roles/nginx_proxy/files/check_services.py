#!/usr/bin/env python3
# Script to check status of services for dashboard

import json
import sys
import socket
import requests
from urllib.parse import urlparse
import argparse

def check_port(host, port):
    """Check if a remote port is open"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(2)
    result = sock.connect_ex((host, port))
    sock.close()
    return result == 0

def check_http(url, timeout=5):
    """Check if an HTTP service responds"""
    try:
        response = requests.get(url, timeout=timeout, verify=False)
        return response.status_code < 500
    except:
        return False

def main():
    parser = argparse.ArgumentParser(description='Check service status')
    parser.add_argument('--services', required=True, help='JSON string of services to check')
    parser.add_argument('--output', required=True, help='Output file path')
    
    args = parser.parse_args()
    services = json.loads(args.services)
    results = {}
    
    for name, url in services.items():
        parsed = urlparse(url)
        host = parsed.hostname
        port = parsed.port or (443 if parsed.scheme == 'https' else 80)
        
        port_open = check_port(host, port)
        
        if port_open:
            http_works = check_http(url)
            if http_works:
                results[name] = "online"
            else:
                results[name] = "maintenance"
        else:
            results[name] = "offline"
    
    # Write results to output file
    with open(args.output, 'w') as f:
        json.dump(results, f)

if __name__ == "__main__":
    main()
