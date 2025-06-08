#!/usr/bin/env python3
"""
Simple test runner for the onboarding system
"""

import os
import sys
import json

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_basic_imports():
    """Test that all modules can be imported"""
    try:
        import onboarding_portal
        print("✓ onboarding_portal imported successfully")
        return True
    except Exception as e:
        print(f"✗ Failed to import onboarding_portal: {e}")
        return False

def test_flask_app():
    """Test that Flask app can be created"""
    try:
        from onboarding_portal import app
        client = app.test_client()
        response = client.get('/login')
        if response.status_code == 200:
            print("✓ Flask app responds correctly")
            return True
        else:
            print(f"✗ Flask app returned status {response.status_code}")
            return False
    except Exception as e:
        print(f"✗ Flask app test failed: {e}")
        return False

def test_api_endpoints():
    """Test API endpoints without authentication"""
    try:
        from onboarding_portal import app
        client = app.test_client()
        
        # Test templates endpoint
        response = client.get('/api/templates')
        if response.status_code == 200:
            data = json.loads(response.data)
            if isinstance(data, list) and len(data) > 0:
                print("✓ Templates API endpoint works")
                return True
            else:
                print("✗ Templates API returned unexpected data")
                return False
        else:
            print(f"✗ Templates API returned status {response.status_code}")
            return False
    except Exception as e:
        print(f"✗ API endpoints test failed: {e}")
        return False

def test_onboarding_service():
    """Test OnboardingService class"""
    try:
        # Mock environment variables
        os.environ['GITLAB_URL'] = 'https://test-gitlab.com'
        os.environ['GITLAB_TOKEN'] = 'test-token'
        
        from onboarding_portal import OnboardingService
        
        # Test pipeline generation without creating service (to avoid credential check)
        app_data = {
            'app_name': 'test-app',
            'framework': 'nodejs',
            'node_version': '18'
        }
        
        # Create a temporary service instance for testing methods
        service = OnboardingService.__new__(OnboardingService)
        service.gitlab_url = 'https://test-gitlab.com'
        service.gitlab_token = 'test-token'
        
        pipeline = service.generate_ci_cd_pipeline(app_data)
        if 'node:' in pipeline and 'npm' in pipeline:
            print("✓ Pipeline generation works")
            return True
        else:
            print("✗ Pipeline generation failed")
            return False
    except Exception as e:
        print(f"✗ OnboardingService test failed: {e}")
        return False

def run_tests():
    """Run all tests"""
    print("Running 1-Click Onboarding System Tests")
    print("=" * 50)
    
    tests = [
        test_basic_imports,
        test_flask_app,
        test_api_endpoints,
        test_onboarding_service
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        if test():
            passed += 1
        print()
    
    print("=" * 50)
    print(f"Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed!")
        return True
    else:
        print("❌ Some tests failed")
        return False

if __name__ == '__main__':
    success = run_tests()
    sys.exit(0 if success else 1)
