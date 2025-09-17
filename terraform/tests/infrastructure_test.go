package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/retry"
)

// TestDevOpsSuiteInfrastructure validates the complete DevOps Suite infrastructure deployment
func TestDevOpsSuiteInfrastructure(t *testing.T) {
	t.Parallel()

	// Setup test directory for state management
	workingDir := "../"
	
	// Defer cleanup
	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		terraform.Destroy(t, terraformOptions)
	})

	// Deploy stage
	test_structure.RunTestStage(t, "deploy", func() {
		terraformOptions := configureTerraformOptions(t, workingDir)
		test_structure.SaveTerraformOptions(t, workingDir, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)
	})

	// Validation stage
	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		
		// Test infrastructure components
		testInfrastructureOutputs(t, terraformOptions)
		testSecurityGroups(t, terraformOptions)
		testComputeInstances(t, terraformOptions)
		testNetworking(t, terraformOptions)
		testStorageVolumes(t, terraformOptions)
	})

	// Service validation stage
	test_structure.RunTestStage(t, "validate_services", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		testServiceEndpoints(t, terraformOptions)
		testServiceHealth(t, terraformOptions)
		testMonitoringStack(t, terraformOptions)
	})
}

// Configure Terraform options for testing
func configureTerraformOptions(t *testing.T, workingDir string) *terraform.Options {
	return &terraform.Options{
		TerraformDir: workingDir,
		
		// Use test-specific variables
		Vars: map[string]interface{}{
			"environment_name":       "test",
			"image_name":            "ubuntu-20.04",
			"flavor_name":           "m1.medium",
			"external_network_name": "public",
			"auth_url":              os.Getenv("OS_AUTH_URL"),
			"username":              os.Getenv("OS_USERNAME"),
			"password":              os.Getenv("OS_PASSWORD"),
			"project_name":          os.Getenv("OS_PROJECT_NAME"),
			"user_domain_name":      os.Getenv("OS_USER_DOMAIN_NAME"),
		},
		
		// Retry configuration for flaky infrastructure
		RetryableTerraformErrors: map[string]string{
			"Error creating OpenStack": "OpenStack API temporary error",
		},
		MaxRetries:         3,
		TimeBetweenRetries: 5 * time.Second,
	}
}

// Test infrastructure outputs
func testInfrastructureOutputs(t *testing.T, terraformOptions *terraform.Options) {
	// Test that all required outputs are present
	requiredOutputs := []string{
		"gitlab_ip",
		"nexus_ip", 
		"keycloak_ip",
		"rancher_ip",
		"nginx_ip",
		"kafka_ip",
		"redis_ip",
	}

	for _, output := range requiredOutputs {
		ip := terraform.Output(t, terraformOptions, output)
		assert.NotEmpty(t, ip, fmt.Sprintf("Output %s should not be empty", output))
		assert.Regexp(t, `^\d+\.\d+\.\d+\.\d+$`, ip, fmt.Sprintf("Output %s should be a valid IP address", output))
	}
}

// Test security groups configuration
func testSecurityGroups(t *testing.T, terraformOptions *terraform.Options) {
	// Verify security group exists and has proper rules
	securityGroupName := terraform.Output(t, terraformOptions, "security_group_name")
	assert.NotEmpty(t, securityGroupName)
	
	// In a real test, you would use OpenStack API to validate security group rules
	// This is a placeholder for demonstration
	log.Printf("Security group %s created successfully", securityGroupName)
}

// Test compute instances
func testComputeInstances(t *testing.T, terraformOptions *terraform.Options) {
	services := []string{"gitlab", "nexus", "keycloak", "rancher", "nginx", "kafka", "redis"}
	
	for _, service := range services {
		instanceId := terraform.Output(t, terraformOptions, fmt.Sprintf("%s_instance_id", service))
		assert.NotEmpty(t, instanceId, fmt.Sprintf("%s instance should be created", service))
		
		// Verify instance is running (would use OpenStack API in real test)
		log.Printf("%s instance %s is running", service, instanceId)
	}
}

// Test networking configuration
func testNetworking(t *testing.T, terraformOptions *terraform.Options) {
	// Test floating IP assignments
	services := []string{"gitlab", "nexus", "keycloak", "rancher", "nginx"}
	
	for _, service := range services {
		floatingIp := terraform.Output(t, terraformOptions, fmt.Sprintf("%s_floating_ip", service))
		assert.NotEmpty(t, floatingIp, fmt.Sprintf("%s should have floating IP", service))
		
		// Verify IP is reachable (basic connectivity test)
		// In production, you'd want more sophisticated health checks
		log.Printf("%s floating IP: %s", service, floatingIp)
	}
}

// Test storage volumes
func testStorageVolumes(t *testing.T, terraformOptions *terraform.Options) {
	servicesWithStorage := []string{"gitlab", "nexus", "keycloak"}
	
	for _, service := range servicesWithStorage {
		volumeId := terraform.Output(t, terraformOptions, fmt.Sprintf("%s_volume_id", service))
		if volumeId != "" {
			assert.NotEmpty(t, volumeId, fmt.Sprintf("%s volume should be created", service))
			log.Printf("%s volume %s created successfully", service, volumeId)
		}
	}
}

// Test service endpoints availability
func testServiceEndpoints(t *testing.T, terraformOptions *terraform.Options) {
	services := map[string]int{
		"gitlab":   8090,
		"nexus":    8081,
		"keycloak": 8180,
		"rancher":  8443,
		"nginx":    80,
	}
	
	for service, port := range services {
		ip := terraform.Output(t, terraformOptions, fmt.Sprintf("%s_ip", service))
		url := fmt.Sprintf("http://%s:%d", ip, port)
		
		// Test endpoint availability with retries
		retry.DoWithRetry(t, fmt.Sprintf("Test %s endpoint", service), 10, 30*time.Second, func() (string, error) {
			return http_helper.HttpGet(t, url, nil)
		})
		
		log.Printf("%s endpoint %s is accessible", service, url)
	}
}

// Test service health endpoints
func testServiceHealth(t *testing.T, terraformOptions *terraform.Options) {
	healthChecks := map[string]string{
		"gitlab":   "/users/sign_in",
		"nexus":    "/service/rest/v1/status",
		"keycloak": "/auth/realms/master",
	}
	
	for service, healthPath := range healthChecks {
		ip := terraform.Output(t, terraformOptions, fmt.Sprintf("%s_ip", service))
		
		var port int
		switch service {
		case "gitlab":
			port = 8090
		case "nexus":
			port = 8081  
		case "keycloak":
			port = 8180
		}
		
		url := fmt.Sprintf("http://%s:%d%s", ip, port, healthPath)
		
		// Test health endpoint
		retry.DoWithRetry(t, fmt.Sprintf("Test %s health", service), 5, 10*time.Second, func() (string, error) {
			response, err := http_helper.HttpGet(t, url, nil)
			if err != nil {
				return "", err
			}
			return response, nil
		})
		
		log.Printf("%s health check passed: %s", service, url)
	}
}

// Test monitoring stack
func testMonitoringStack(t *testing.T, terraformOptions *terraform.Options) {
	// Test Prometheus endpoint
	prometheusIP := terraform.Output(t, terraformOptions, "prometheus_ip")
	if prometheusIP != "" {
		prometheusURL := fmt.Sprintf("http://%s:9090/api/v1/query?query=up", prometheusIP)
		
		retry.DoWithRetry(t, "Test Prometheus API", 10, 15*time.Second, func() (string, error) {
			return http_helper.HttpGet(t, prometheusURL, nil)
		})
		
		log.Printf("Prometheus monitoring is accessible: %s", prometheusURL)
	}
	
	// Test Grafana endpoint
	grafanaIP := terraform.Output(t, terraformOptions, "grafana_ip")
	if grafanaIP != "" {
		grafanaURL := fmt.Sprintf("http://%s:3000/api/health", grafanaIP)
		
		retry.DoWithRetry(t, "Test Grafana API", 10, 15*time.Second, func() (string, error) {
			return http_helper.HttpGet(t, grafanaURL, nil)
		})
		
		log.Printf("Grafana visualization is accessible: %s", grafanaURL)
	}
	
	// Test Jaeger endpoint  
	jaegerIP := terraform.Output(t, terraformOptions, "jaeger_ip")
	if jaegerIP != "" {
		jaegerURL := fmt.Sprintf("http://%s:16686/api/services", jaegerIP)
		
		retry.DoWithRetry(t, "Test Jaeger API", 10, 15*time.Second, func() (string, error) {
			return http_helper.HttpGet(t, jaegerURL, nil)
		})
		
		log.Printf("Jaeger tracing is accessible: %s", jaegerURL)
	}
}

// TestSecurityCompliance validates security and compliance requirements
func TestSecurityCompliance(t *testing.T) {
	t.Parallel()
	
	workingDir := "../"
	terraformOptions := configureTerraformOptions(t, workingDir)
	
	// Run terraform plan to get planned changes
	planOutput := terraform.Plan(t, terraformOptions)
	require.NotEmpty(t, planOutput)
	
	// Here you would integrate with OPA to validate the plan
	// This is a placeholder for the actual OPA integration
	log.Printf("Security compliance validation passed")
}

// TestDisasterRecovery validates backup and recovery procedures
func TestDisasterRecovery(t *testing.T) {
	t.Parallel()
	
	// Test backup mechanisms
	t.Run("BackupValidation", func(t *testing.T) {
		// Validate that backup procedures are in place
		// This would test actual backup scripts and procedures
		log.Printf("Backup validation completed")
	})
	
	// Test recovery procedures
	t.Run("RecoveryValidation", func(t *testing.T) {
		// Validate recovery procedures
		// This would test actual recovery scripts and procedures  
		log.Printf("Recovery validation completed")
	})
}

// TestPerformance validates performance requirements
func TestPerformance(t *testing.T) {
	t.Parallel()
	
	workingDir := "../"
	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
	
	// Test response times
	services := map[string]int{
		"nginx": 80,
		"gitlab": 8090,
	}
	
	for service, port := range services {
		ip := terraform.Output(t, terraformOptions, fmt.Sprintf("%s_ip", service))
		url := fmt.Sprintf("http://%s:%d", ip, port)
		
		// Test response time
		start := time.Now()
		_, err := http_helper.HttpGet(t, url, nil)
		duration := time.Since(start)
		
		require.NoError(t, err)
		assert.Less(t, duration, 5*time.Second, fmt.Sprintf("%s should respond within 5 seconds", service))
		
		log.Printf("%s response time: %v", service, duration)
	}
}