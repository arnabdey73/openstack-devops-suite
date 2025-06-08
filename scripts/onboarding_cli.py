#!/usr/bin/env python3
"""
GitLab-Centered DevOps Suite - CLI App Onboarding Tool
------------------------------------------------------
Command-line interface for 1-Click Application Onboarding
"""

import os
import sys
import json
import argparse
import requests
from tqdm import tqdm
import time
import textwrap
import subprocess
import logging
from pyfiglet import Figlet

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("onboarding-cli")

# Constants
PORTAL_URL = os.getenv('PORTAL_URL', 'http://localhost:5000')
GITLAB_URL = os.getenv('GITLAB_URL', 'https://gitlab.yourdomain.com')

# Terminal colors
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    WARNING = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def print_banner():
    """Print application banner"""
    f = Figlet(font='slant')
    banner = f.renderText('1-Click Onboarding')
    print(Colors.CYAN + banner + Colors.ENDC)
    print(Colors.BOLD + "GitLab-Centered DevOps Suite - CLI App Onboarding Tool" + Colors.ENDC)
    print("-" * 60)
    print()

def get_templates():
    """Fetch available application templates"""
    try:
        response = requests.get(f"{PORTAL_URL}/api/templates")
        response.raise_for_status()
        return response.json()
    except Exception as e:
        logger.error(f"Error fetching templates: {str(e)}")
        sys.exit(1)

def show_templates(templates):
    """Display available templates"""
    print(Colors.HEADER + "Available Application Templates:" + Colors.ENDC)
    print()
    
    for i, template in enumerate(templates, 1):
        print(f"{Colors.BOLD}{i}. {template['name']}{Colors.ENDC}")
        print(f"   ID: {Colors.BLUE}{template['id']}{Colors.ENDC}")
        print(f"   Description: {template['description']}")
        print(f"   Default Port: {template['default_port']}")
        print(f"   Frameworks: {', '.join(template['frameworks'])}")
        print()

def select_template(templates):
    """Let user select a template"""
    while True:
        try:
            choice = int(input("Select a template (number): "))
            if 1 <= choice <= len(templates):
                return templates[choice - 1]
            else:
                print(f"{Colors.RED}Invalid choice. Please select a number between 1 and {len(templates)}.{Colors.ENDC}")
        except ValueError:
            print(f"{Colors.RED}Please enter a number.{Colors.ENDC}")

def collect_app_info(template):
    """Collect application information from user"""
    print(Colors.HEADER + "\nApplication Configuration:" + Colors.ENDC)
    
    app_name = input("Application name (lowercase, alphanumeric with dashes): ")
    app_name = ''.join(c if c.isalnum() or c == '-' else '-' for c in app_name.lower())
    
    description = input("Description: ")
    team_email = input("Team email: ")
    
    # Framework selection
    print("\nAvailable frameworks:")
    frameworks = [template['id']] + template['frameworks']
    for i, framework in enumerate(frameworks, 1):
        print(f"{i}. {framework}")
    
    while True:
        try:
            framework_choice = int(input("Select a framework (number): "))
            if 1 <= framework_choice <= len(frameworks):
                framework = frameworks[framework_choice - 1].lower().replace(' ', '-')
                break
            else:
                print(f"{Colors.RED}Invalid choice.{Colors.ENDC}")
        except ValueError:
            print(f"{Colors.RED}Please enter a number.{Colors.ENDC}")
    
    port = input(f"Application port [{template['default_port']}]: ")
    port = int(port) if port else template['default_port']
    
    replicas = input("Initial replicas [3]: ")
    replicas = int(replicas) if replicas else 3
    
    # Resource configuration
    print(Colors.HEADER + "\nResource Configuration:" + Colors.ENDC)
    memory_choices = ["128Mi", "256Mi", "512Mi", "1Gi", "2Gi"]
    cpu_choices = ["50m", "100m", "200m", "500m", "1000m"]
    
    print("Memory request options:")
    for i, mem in enumerate(memory_choices, 1):
        print(f"{i}. {mem}")
    
    while True:
        try:
            mem_req_choice = int(input("Select memory request (number) [2 - 256Mi]: "))
            if 1 <= mem_req_choice <= len(memory_choices):
                memory_request = memory_choices[mem_req_choice - 1]
                break
            else:
                print(f"{Colors.RED}Invalid choice.{Colors.ENDC}")
        except ValueError:
            memory_request = "256Mi"
            break
    
    while True:
        try:
            mem_limit_choice = int(input("Select memory limit (number) [3 - 512Mi]: "))
            if 1 <= mem_limit_choice <= len(memory_choices):
                memory_limit = memory_choices[mem_limit_choice - 1]
                break
            else:
                print(f"{Colors.RED}Invalid choice.{Colors.ENDC}")
        except ValueError:
            memory_limit = "512Mi"
            break
    
    print("CPU request options:")
    for i, cpu in enumerate(cpu_choices, 1):
        print(f"{i}. {cpu}")
    
    while True:
        try:
            cpu_req_choice = int(input("Select CPU request (number) [2 - 100m]: "))
            if 1 <= cpu_req_choice <= len(cpu_choices):
                cpu_request = cpu_choices[cpu_req_choice - 1]
                break
            else:
                print(f"{Colors.RED}Invalid choice.{Colors.ENDC}")
        except ValueError:
            cpu_request = "100m"
            break
    
    while True:
        try:
            cpu_limit_choice = int(input("Select CPU limit (number) [4 - 500m]: "))
            if 1 <= cpu_limit_choice <= len(cpu_choices):
                cpu_limit = cpu_choices[cpu_limit_choice - 1]
                break
            else:
                print(f"{Colors.RED}Invalid choice.{Colors.ENDC}")
        except ValueError:
            cpu_limit = "500m"
            break
    
    app_data = {
        "app_name": app_name,
        "description": description,
        "team_email": team_email,
        "framework": framework,
        "port": port,
        "replicas": replicas,
        "memory_request": memory_request,
        "memory_limit": memory_limit,
        "cpu_request": cpu_request,
        "cpu_limit": cpu_limit
    }
    
    return app_data

def display_summary(app_data):
    """Display a summary of the application configuration"""
    print(Colors.HEADER + "\nApplication Summary:" + Colors.ENDC)
    print(f"{Colors.BOLD}Name:{Colors.ENDC} {app_data['app_name']}")
    print(f"{Colors.BOLD}Description:{Colors.ENDC} {app_data['description']}")
    print(f"{Colors.BOLD}Framework:{Colors.ENDC} {app_data['framework']}")
    print(f"{Colors.BOLD}Port:{Colors.ENDC} {app_data['port']}")
    print(f"{Colors.BOLD}Replicas:{Colors.ENDC} {app_data['replicas']}")
    print(f"{Colors.BOLD}Memory:{Colors.ENDC} {app_data['memory_request']} (request) / {app_data['memory_limit']} (limit)")
    print(f"{Colors.BOLD}CPU:{Colors.ENDC} {app_data['cpu_request']} (request) / {app_data['cpu_limit']} (limit)")
    
    confirm = input("\nDeploy this application? [Y/n]: ").lower()
    return confirm != 'n'

def deploy_application(app_data):
    """Deploy the application"""
    print(Colors.HEADER + "\nDeploying Application..." + Colors.ENDC)
    
    try:
        # Show progress with tqdm
        with tqdm(total=100) as pbar:
            pbar.set_description("Creating GitLab project")
            pbar.update(10)
            time.sleep(0.5)
            
            # Call the API
            response = requests.post(
                f"{PORTAL_URL}/api/onboard",
                json=app_data
            )
            
            pbar.set_description("Generating CI/CD pipeline")
            pbar.update(20)
            time.sleep(0.5)
            
            pbar.set_description("Creating Kubernetes manifests")
            pbar.update(30)
            time.sleep(0.5)
            
            pbar.set_description("Setting up GitLab webhooks")
            pbar.update(20)
            time.sleep(0.5)
            
            pbar.set_description("Finalizing deployment")
            pbar.update(20)
            
            if response.status_code == 200:
                data = response.json()
                
                if data["status"] == "success":
                    pbar.update(20)  # Complete the progress bar
                    return data
                else:
                    print(f"\n{Colors.RED}Error: {data.get('message', 'Unknown error')}{Colors.ENDC}")
                    sys.exit(1)
            else:
                print(f"\n{Colors.RED}Error: HTTP {response.status_code}{Colors.ENDC}")
                print(response.text)
                sys.exit(1)
    except Exception as e:
        print(f"\n{Colors.RED}Error deploying application: {str(e)}{Colors.ENDC}")
        sys.exit(1)

def check_application_status(app_name):
    """Check the status of an existing application"""
    print(f"Checking status for application: {app_name}")
    
    try:
        response = requests.get(f"{PORTAL_URL}/api/status/{app_name}")
        
        if response.status_code == 200:
            data = response.json()
            
            if data["status"] == "success":
                print(Colors.HEADER + f"\nStatus for {data['app_name']}:" + Colors.ENDC)
                print(f"Project ID: {data['project_id']}")
                
                print("\nEnvironments:")
                for env_name, env_data in data.get("environments", {}).items():
                    status_color = Colors.GREEN if env_data["status"] == "available" else Colors.WARNING
                    print(f"  {env_name}: {status_color}{env_data['status']}{Colors.ENDC}")
                    print(f"    Last deployment: {env_data['last_deployment']}")
                    print(f"    URL: {env_data['url']}")
            else:
                print(f"{Colors.RED}Error: {data.get('message', 'Unknown error')}{Colors.ENDC}")
        else:
            print(f"{Colors.RED}Error: HTTP {response.status_code}{Colors.ENDC}")
            print(response.text)
    except Exception as e:
        print(f"{Colors.RED}Error checking application status: {str(e)}{Colors.ENDC}")

def display_success(data):
    """Display success message and next steps"""
    print("\n" + Colors.GREEN + "✓ " + Colors.BOLD + "Application successfully deployed!" + Colors.ENDC)
    print("\nImportant Links:")
    print(f"{Colors.BOLD}GitLab Repository:{Colors.ENDC} {data['project_url']}")
    print(f"{Colors.BOLD}Development URL:{Colors.ENDC} {data['dev_url']}")
    print(f"{Colors.BOLD}Production URL:{Colors.ENDC} {data['prod_url']}")
    
    print(Colors.HEADER + "\nNext Steps:" + Colors.ENDC)
    steps = [
        "Clone the repository: " + Colors.BLUE + f"git clone {data['project_url']}" + Colors.ENDC,
        "Make code changes and push to trigger the pipeline",
        "Monitor deployment in GitLab CI/CD pipelines",
        "Access development environment at " + Colors.BLUE + data['dev_url'] + Colors.ENDC,
        "Promote to production through GitLab pipeline when ready"
    ]
    
    for i, step in enumerate(steps, 1):
        print(f"{i}. {step}")

def main():
    """Main CLI function"""
    parser = argparse.ArgumentParser(description="1-Click Application Onboarding for GitLab-Centered DevOps Suite")
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--deploy', action='store_true', help='Deploy a new application')
    group.add_argument('--status', type=str, metavar='APP_NAME', help='Check status of an existing application')
    
    args = parser.parse_args()
    
    print_banner()
    
    if args.status:
        check_application_status(args.status)
    else:
        # Default to deploy flow
        templates = get_templates()
        show_templates(templates)
        
        selected_template = select_template(templates)
        app_data = collect_app_info(selected_template)
        
        if display_summary(app_data):
            deployment_data = deploy_application(app_data)
            display_success(deployment_data)

if __name__ == "__main__":
    main()
