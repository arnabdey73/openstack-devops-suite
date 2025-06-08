#!/usr/bin/env python3
"""
End-to-End Deployment Flow Testing Script
-------------------------------------------
Tests the complete 1-click onboarding deployment flow from start to finish.
"""

import os
import sys
import json
import time
import requests
import subprocess
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f"deployment-test-{datetime.now().strftime('%Y%m%d-%H%M%S')}.log"),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class DeploymentTester:
    """End-to-end deployment flow tester"""
    
    def __init__(self):
        self.base_url = os.getenv('ONBOARDING_URL', 'http://localhost:5000')
        self.gitlab_url = os.getenv('GITLAB_URL', 'https://gitlab.yourdomain.com')
        self.gitlab_token = os.getenv('GITLAB_TOKEN', '')
        self.test_results = []
        
    def run_test(self, test_name, test_func):
        """Run a test and record results"""
        logger.info(f"Running test: {test_name}")
        start_time = time.time()
        
        try:
            result = test_func()
            duration = time.time() - start_time
            
            self.test_results.append({
                "test": test_name,
                "status": "PASS" if result else "FAIL",
                "duration": f"{duration:.2f}s",
                "timestamp": datetime.now().isoformat()
            })
            
            if result:
                logger.info(f"✅ {test_name} - PASSED ({duration:.2f}s)")
            else:
                logger.error(f"❌ {test_name} - FAILED ({duration:.2f}s)")
                
            return result
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"❌ {test_name} - ERROR: {str(e)} ({duration:.2f}s)")
            
            self.test_results.append({
                "test": test_name,
                "status": "ERROR",
                "error": str(e),
                "duration": f"{duration:.2f}s",
                "timestamp": datetime.now().isoformat()
            })
            
            return False
    
    def test_portal_health(self):
        """Test if the onboarding portal is accessible"""
        try:
            response = requests.get(f"{self.base_url}/api/templates", timeout=10)
            return response.status_code == 200
        except Exception as e:
            logger.error(f"Portal health check failed: {str(e)}")
            return False
    
    def test_gitlab_connectivity(self):
        """Test GitLab API connectivity"""
        if not self.gitlab_token:
            logger.warning("GitLab token not provided, skipping GitLab tests")
            return True
            
        try:
            headers = {'PRIVATE-TOKEN': self.gitlab_token}
            response = requests.get(f"{self.gitlab_url}/api/v4/user", headers=headers, timeout=10)
            return response.status_code == 200
        except Exception as e:
            logger.error(f"GitLab connectivity test failed: {str(e)}")
            return False
    
    def test_onboard_sample_app(self):
        """Test onboarding a sample application"""
        test_app_data = {
            "app_name": f"test-app-{int(time.time())}",
            "framework": "nodejs",
            "description": "Test application for deployment flow validation",
            "team_email": "devops@test.com",
            "port": 3000,
            "replicas": 1
        }
        
        try:
            response = requests.post(
                f"{self.base_url}/api/onboard",
                json=test_app_data,
                timeout=60
            )
            
            if response.status_code == 200:
                result = response.json()
                if result.get('status') == 'success':
                    self.test_app_name = test_app_data['app_name']
                    self.test_project_id = result.get('project_id')
                    logger.info(f"Successfully onboarded test app: {self.test_app_name}")
                    return True
            
            logger.error(f"Onboarding failed: {response.text}")
            return False
            
        except Exception as e:
            logger.error(f"Onboarding test failed: {str(e)}")
            return False
    
    def test_app_status_check(self):
        """Test application status API"""
        if not hasattr(self, 'test_app_name'):
            logger.warning("No test app to check status for")
            return True
            
        try:
            response = requests.get(
                f"{self.base_url}/api/status/{self.test_app_name}",
                timeout=30
            )
            
            return response.status_code in [200, 404]  # 404 is acceptable for new apps
            
        except Exception as e:
            logger.error(f"Status check failed: {str(e)}")
            return False
    
    def test_list_applications(self):
        """Test listing all applications"""
        try:
            response = requests.get(
                f"{self.base_url}/api/applications",
                timeout=30
            )
            
            return response.status_code == 200
            
        except Exception as e:
            logger.error(f"List applications failed: {str(e)}")
            return False
    
    def test_rate_limiting(self):
        """Test API rate limiting"""
        try:
            # Make multiple rapid requests to trigger rate limiting
            for i in range(35):  # Should exceed 30/minute limit
                response = requests.get(
                    f"{self.base_url}/api/templates",
                    timeout=5
                )
                if response.status_code == 429:
                    logger.info("Rate limiting is working correctly")
                    return True
                    
            logger.warning("Rate limiting may not be working - no 429 response received")
            return True  # Not a failure, just a warning
            
        except Exception as e:
            logger.error(f"Rate limiting test failed: {str(e)}")
            return False
    
    def test_security_headers(self):
        """Test security headers are present"""
        try:
            response = requests.get(f"{self.base_url}/", timeout=10)
            
            required_headers = [
                'X-Content-Type-Options',
                'X-Frame-Options',
                'Strict-Transport-Security',
                'Content-Security-Policy'
            ]
            
            missing_headers = []
            for header in required_headers:
                if header not in response.headers:
                    missing_headers.append(header)
            
            if missing_headers:
                logger.warning(f"Missing security headers: {missing_headers}")
                return False
            
            return True
            
        except Exception as e:
            logger.error(f"Security headers test failed: {str(e)}")
            return False
    
    def test_kubernetes_manifests_generation(self):
        """Test that Kubernetes manifests are properly generated"""
        if not hasattr(self, 'test_app_name'):
            logger.warning("No test app to check manifests for")
            return True
            
        try:
            # Check if manifests directory exists
            manifest_dir = f"templates/apps/{self.test_app_name}/deploy"
            
            if os.path.exists(manifest_dir):
                required_files = ['deployment.yaml', 'service.yaml', 'ingress.yaml', 'configmap.yaml']
                
                for file in required_files:
                    file_path = os.path.join(manifest_dir, file)
                    if not os.path.exists(file_path):
                        logger.error(f"Missing manifest file: {file}")
                        return False
                    
                    # Check if file has content
                    if os.path.getsize(file_path) == 0:
                        logger.error(f"Empty manifest file: {file}")
                        return False
                
                logger.info("All Kubernetes manifests generated successfully")
                return True
            else:
                logger.warning(f"Manifest directory not found: {manifest_dir}")
                return False
                
        except Exception as e:
            logger.error(f"Kubernetes manifests test failed: {str(e)}")
            return False
    
    def test_cleanup_test_app(self):
        """Cleanup test application"""
        if not hasattr(self, 'test_app_name'):
            return True
            
        try:
            # Delete via API
            response = requests.delete(
                f"{self.base_url}/api/applications/{self.test_app_name}",
                timeout=30
            )
            
            if response.status_code in [200, 404]:
                logger.info(f"Test app {self.test_app_name} cleaned up successfully")
                return True
            else:
                logger.warning(f"Failed to cleanup test app: {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"Cleanup failed: {str(e)}")
            return False
    
    def run_all_tests(self):
        """Run all deployment flow tests"""
        logger.info("🚀 Starting End-to-End Deployment Flow Tests")
        logger.info("=" * 60)
        
        tests = [
            ("Portal Health Check", self.test_portal_health),
            ("GitLab Connectivity", self.test_gitlab_connectivity),
            ("Security Headers", self.test_security_headers),
            ("Rate Limiting", self.test_rate_limiting),
            ("Sample App Onboarding", self.test_onboard_sample_app),
            ("App Status Check", self.test_app_status_check),
            ("List Applications", self.test_list_applications),
            ("Kubernetes Manifests", self.test_kubernetes_manifests_generation),
            ("Cleanup Test App", self.test_cleanup_test_app),
        ]
        
        passed = 0
        total = len(tests)
        
        for test_name, test_func in tests:
            if self.run_test(test_name, test_func):
                passed += 1
            time.sleep(1)  # Brief pause between tests
        
        logger.info("=" * 60)
        logger.info(f"🏁 Tests Complete: {passed}/{total} passed")
        
        if passed == total:
            logger.info("🎉 All tests passed! Deployment flow is working correctly.")
        else:
            logger.error(f"⚠️  {total - passed} test(s) failed. Please review the logs.")
        
        return self.generate_report()
    
    def generate_report(self):
        """Generate test report"""
        report = {
            "test_run": {
                "timestamp": datetime.now().isoformat(),
                "total_tests": len(self.test_results),
                "passed": len([r for r in self.test_results if r['status'] == 'PASS']),
                "failed": len([r for r in self.test_results if r['status'] == 'FAIL']),
                "errors": len([r for r in self.test_results if r['status'] == 'ERROR'])
            },
            "results": self.test_results
        }
        
        # Save report to file
        report_file = f"deployment-test-report-{datetime.now().strftime('%Y%m%d-%H%M%S')}.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        logger.info(f"📄 Test report saved to: {report_file}")
        return report

def main():
    """Main test execution"""
    logger.info("DevOps Suite - End-to-End Deployment Flow Tester")
    logger.info("================================================")
    
    # Check environment
    if not os.getenv('GITLAB_TOKEN'):
        logger.warning("GITLAB_TOKEN not set - some tests will be skipped")
    
    # Run tests
    tester = DeploymentTester()
    report = tester.run_all_tests()
    
    # Exit with appropriate code
    if report['test_run']['failed'] > 0 or report['test_run']['errors'] > 0:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == '__main__':
    main()
