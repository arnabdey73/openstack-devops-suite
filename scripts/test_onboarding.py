#!/usr/bin/env python3
"""
Integration Tests for 1-Click Application Onboarding Portal
----------------------------------------------------------
Comprehensive test suite for the onboarding system
"""

import os
import sys
import json
import time
import requests
import unittest
from unittest.mock import patch, MagicMock
import tempfile
import shutil

# Add the scripts directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from onboarding_portal import app, OnboardingService, OnboardingError

class TestOnboardingPortal(unittest.TestCase):
    """Test cases for the onboarding portal"""
    
    def setUp(self):
        """Set up test environment"""
        self.app = app.test_client()
        self.app.testing = True
        
        # Set environment variables for testing
        os.environ['GITLAB_URL'] = 'https://test-gitlab.com'
        os.environ['GITLAB_TOKEN'] = 'test-token'
        os.environ['SECRET_KEY'] = 'test-secret-key'
        os.environ['ADMIN_USERNAME'] = 'test-admin'
        os.environ['ADMIN_PASSWORD'] = 'test-password'
        
        # Create temporary directory for test files
        self.test_dir = tempfile.mkdtemp()
        
    def tearDown(self):
        """Clean up test environment"""
        # Remove temporary directory
        shutil.rmtree(self.test_dir, ignore_errors=True)
        
    def login(self):
        """Helper method to log in for authenticated tests"""
        return self.app.post('/login', data={
            'username': 'test-admin',
            'password': 'test-password'
        }, follow_redirects=True)
        
    def test_login_page_loads(self):
        """Test that login page loads correctly"""
        response = self.app.get('/login')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'1-Click Onboarding Portal', response.data)
        
    def test_valid_login(self):
        """Test valid login credentials"""
        response = self.login()
        self.assertEqual(response.status_code, 200)
        
    def test_invalid_login(self):
        """Test invalid login credentials"""
        response = self.app.post('/login', data={
            'username': '',  # Empty credentials should fail
            'password': ''
        })
        self.assertEqual(response.status_code, 200)  # Stay on login page
        # Note: The actual flash message checking would need session support
        
    def test_unauthenticated_access(self):
        """Test that unauthenticated users can access public pages"""
        response = self.app.get('/')
        self.assertEqual(response.status_code, 200)  # Public onboarding page
        
        # But protected routes should redirect
        response = self.app.get('/dashboard')
        self.assertEqual(response.status_code, 302)
        self.assertIn('/login', response.location)
        
    def test_get_templates_endpoint(self):
        """Test the templates API endpoint"""
        response = self.app.get('/api/templates')
        self.assertEqual(response.status_code, 200)
        
        data = json.loads(response.data)
        self.assertIsInstance(data, list)
        self.assertGreater(len(data), 0)
        
        # Check template structure
        template = data[0]
        required_fields = ['id', 'name', 'description', 'default_port']
        for field in required_fields:
            self.assertIn(field, template)
            
    def test_onboard_application_missing_fields(self):
        """Test onboarding with missing required fields"""
        self.login()
        
        response = self.app.post('/api/onboard', 
                               json={'app_name': 'test-app'},
                               content_type='application/json')
        self.assertEqual(response.status_code, 400)
        
        data = json.loads(response.data)
        self.assertEqual(data['status'], 'error')
        self.assertIn('Missing required field', data['message'])
        
    @patch('onboarding_portal.subprocess.run')
    def test_onboard_application_success(self, mock_subprocess):
        """Test successful application onboarding"""
        self.login()
        
        # Mock GitLab API responses
        mock_subprocess.side_effect = [
            # Credential verification
            MagicMock(returncode=0, stdout='{"username": "test"}'),
            # Project creation
            MagicMock(returncode=0, stdout='{"id": 123, "web_url": "https://test.com/project"}'),
            # File additions (CI/CD, Dockerfile, manifests)
            MagicMock(returncode=0, stdout='{"file_path": ".gitlab-ci.yml"}'),
            MagicMock(returncode=0, stdout='{"file_path": "Dockerfile"}'),
            MagicMock(returncode=0, stdout='{"file_path": "deploy/deployment.yaml"}'),
            MagicMock(returncode=0, stdout='{"file_path": "deploy/service.yaml"}'),
            MagicMock(returncode=0, stdout='{"file_path": "deploy/ingress.yaml"}'),
            MagicMock(returncode=0, stdout='{"file_path": "deploy/configmap.yaml"}'),
            # Webhook setup
            MagicMock(returncode=0, stdout='{"id": 1}'),
        ]
        
        app_data = {
            'app_name': 'test-app',
            'framework': 'nodejs',
            'description': 'Test application',
            'team_email': 'test@example.com'
        }
        
        response = self.app.post('/api/onboard', 
                               json=app_data,
                               content_type='application/json')
        self.assertEqual(response.status_code, 200)
        
        data = json.loads(response.data)
        self.assertEqual(data['status'], 'success')
        self.assertIn('project_url', data)
        
    def test_rate_limiting(self):
        """Test API rate limiting"""
        # Make multiple rapid requests to trigger rate limiting
        for i in range(35):  # Exceed the 30 per minute limit
            response = self.app.get('/api/templates')
            if response.status_code == 429:
                break
        else:
            self.fail("Rate limiting not triggered")
            
        self.assertEqual(response.status_code, 429)
        data = json.loads(response.data)
        self.assertEqual(data['status'], 'error')
        self.assertIn('Rate limit exceeded', data['message'])
        
    def test_security_headers(self):
        """Test that security headers are present"""
        response = self.app.get('/api/templates')
        
        # Check for security headers
        security_headers = [
            'X-Content-Type-Options',
            'X-Frame-Options',
            'X-XSS-Protection',
            'Content-Security-Policy',
            'Referrer-Policy'
        ]
        
        for header in security_headers:
            self.assertIn(header, response.headers)
            
    def test_error_handling(self):
        """Test error handling for non-existent endpoints"""
        response = self.app.get('/api/nonexistent')
        self.assertEqual(response.status_code, 404)
        
        data = json.loads(response.data)
        self.assertEqual(data['status'], 'error')


class TestOnboardingService(unittest.TestCase):
    """Test cases for the OnboardingService class"""
    
    def setUp(self):
        """Set up test environment"""
        os.environ['GITLAB_URL'] = 'https://test-gitlab.com'
        os.environ['GITLAB_TOKEN'] = 'test-token'
        
    @patch('onboarding_portal.subprocess.run')
    def test_verify_credentials_success(self, mock_subprocess):
        """Test successful credential verification"""
        mock_subprocess.return_value = MagicMock(
            returncode=0, 
            stdout='{"username": "test"}'
        )
        
        service = OnboardingService()
        # If no exception is raised, credentials are valid
        self.assertIsInstance(service, OnboardingService)
        
    @patch('onboarding_portal.subprocess.run')
    def test_verify_credentials_failure(self, mock_subprocess):
        """Test failed credential verification"""
        mock_subprocess.return_value = MagicMock(
            returncode=1, 
            stderr='Unauthorized'
        )
        
        with self.assertRaises(OnboardingError):
            OnboardingService()
            
    def test_generate_ci_cd_pipeline_nodejs(self):
        """Test Node.js CI/CD pipeline generation"""
        with patch('onboarding_portal.subprocess.run') as mock_subprocess:
            mock_subprocess.return_value = MagicMock(
                returncode=0, 
                stdout='{"username": "test"}'
            )
            
            service = OnboardingService()
            app_data = {
                'app_name': 'test-app',
                'framework': 'nodejs',
                'node_version': '18'
            }
            
            pipeline = service.generate_ci_cd_pipeline(app_data)
            
            # The pipeline uses variables, so check for the variable definition and usage
            self.assertIn('NODE_VERSION: "18"', pipeline)
            self.assertIn('image: node:$NODE_VERSION', pipeline)
            self.assertIn('npm ci', pipeline)
            self.assertIn('npm test', pipeline)
            
    def test_generate_ci_cd_pipeline_python(self):
        """Test Python CI/CD pipeline generation"""
        with patch('onboarding_portal.subprocess.run') as mock_subprocess:
            mock_subprocess.return_value = MagicMock(
                returncode=0, 
                stdout='{"username": "test"}'
            )
            
            service = OnboardingService()
            app_data = {
                'app_name': 'test-app',
                'framework': 'python',
                'python_version': '3.11'
            }
            
            pipeline = service.generate_ci_cd_pipeline(app_data)
            
            # The pipeline uses variables, so check for the variable definition and usage
            self.assertIn('PYTHON_VERSION: "3.11"', pipeline)
            self.assertIn('image: python:$PYTHON_VERSION', pipeline)
            self.assertIn('pip install', pipeline)
            self.assertIn('pytest', pipeline)
            
    def test_generate_kubernetes_manifests(self):
        """Test Kubernetes manifest generation"""
        with patch('onboarding_portal.subprocess.run') as mock_subprocess:
            mock_subprocess.return_value = MagicMock(
                returncode=0, 
                stdout='{"username": "test"}'
            )
            
            service = OnboardingService()
            app_data = {
                'app_name': 'test-app',
                'framework': 'nodejs',
                'port': 3000,
                'replicas': 2
            }
            
            with patch('os.makedirs'):
                manifests = service.generate_kubernetes_manifests(app_data)
                
            self.assertIn('deployment.yaml', manifests)
            self.assertIn('service.yaml', manifests)
            self.assertIn('ingress.yaml', manifests)
            self.assertIn('configmap.yaml', manifests)
            
            # Check deployment manifest content
            deployment = manifests['deployment.yaml']
            self.assertIn('replicas: 2', deployment)
            self.assertIn('containerPort: 3000', deployment)


class TestCLITool(unittest.TestCase):
    """Test cases for the CLI tool"""
    
    def setUp(self):
        """Set up test environment"""
        # Add CLI script to path
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        
    def test_cli_import(self):
        """Test that CLI module can be imported"""
        try:
            import onboarding_cli
            self.assertTrue(True)
        except ImportError:
            self.fail("Failed to import onboarding_cli module")


if __name__ == '__main__':
    # Run the tests
    unittest.main(verbosity=2)
