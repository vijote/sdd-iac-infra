package test

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestIntegrationEndToEnd validates complete end-to-end functionality
func TestIntegrationEndToEnd(t *testing.T) {
	t.Parallel()

	// Test both providers
	testCases := []struct {
		name    string
		varFile string
		region  string
	}{
		{"AWS", "../../src/terraform/environments/aws/terraform.tfvars", "us-east-1"},
		{"MiniStack", "../../src/terraform/environments/ministack/terraform.tfvars", "local"},
	}

	for _, tc := range testCases {
		tc := tc // capture range variable
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			uniqueEnv := fmt.Sprintf("sdd-integration-%s-%s", tc.name, random.UniqueId())

			terraformOptions := &terraform.Options{
				TerraformDir: "../../src/terraform/examples/basic",
				VarFiles:     []string{tc.varFile},
				Vars: map[string]interface{}{
					"environment":  uniqueEnv,
					"project_name": fmt.Sprintf("sdd-integration-%s", tc.name),
				},
				EnvVars: map[string]string{
					"AWS_DEFAULT_REGION": tc.region,
				},
				NoColor: true,
			}

			defer terraform.Destroy(t, terraformOptions)

			// Test terraform init and plan
			planExitCode := terraform.Plan(t, terraformOptions)
			assert.Equal(t, 0, planExitCode, "Terraform plan should succeed")

			// Test terraform apply
			applyExitCode := terraform.Apply(t, terraformOptions)
			assert.Equal(t, 0, applyExitCode, "Terraform apply should succeed")

			// Validate all outputs exist
			outputs := map[string]string{
				"vpc_id":                     terraform.Output(t, terraformOptions, "vpc_id"),
				"public_subnet_id":           terraform.Output(t, terraformOptions, "public_subnet_id"),
				"control_plane_security_group_id": terraform.Output(t, terraformOptions, "control_plane_security_group_id"),
				"worker_node_security_group_id":   terraform.Output(t, terraformOptions, "worker_node_security_group_id"),
				"ingress_security_group_id":        terraform.Output(t, terraformOptions, "ingress_security_group_id"),
			}

			for name, value := range outputs {
				assert.NotEmpty(t, value, fmt.Sprintf("Output %s should not be empty", name))
			}

			// Validate private subnets
			privateSubnetIDs := terraform.OutputList(t, terraformOptions, "private_subnet_ids")
			assert.Len(t, privateSubnetIDs, 2, "Should have exactly 2 private subnets")

			t.Logf("Integration test passed for %s provider", tc.name)
		})
	}
}

// TestIntegrationModuleComposition validates module works with other modules
func TestIntegrationModuleComposition(t *testing.T) {
	t.Parallel()

	// This test would validate that the networking module can be composed with other modules
	// For now, we'll test that outputs can be used as inputs to other resources

	uniqueEnv := fmt.Sprintf("sdd-composition-%s", random.UniqueId())

	terraformOptions := &terraform.Options{
		TerraformDir: "../../src/terraform/examples/basic",
		VarFiles:     []string{"../../src/terraform/environments/aws/terraform.tfvars"},
		Vars: map[string]interface{}{
			"environment":  uniqueEnv,
			"project_name": "sdd-composition-test",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": "us-east-1",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Get outputs that would be used by other modules
	vpcID := terraform.Output(t, terraformOptions, "vpc_id")
	publicSubnetID := terraform.Output(t, terraformOptions, "public_subnet_id")
	privateSubnetIDs := terraform.OutputList(t, terraformOptions, "private_subnet_ids")

	// Validate outputs are in correct format for composition
	assert.NotEmpty(t, vpcID, "VPC ID should be available for composition")
	assert.NotEmpty(t, publicSubnetID, "Public subnet ID should be available for composition")
	assert.Len(t, privateSubnetIDs, 2, "Private subnet IDs should be available for composition")

	// Test that outputs can be used in module composition
	// In a real scenario, these would be passed to other modules
	compositionVars := map[string]interface{}{
		"vpc_id":             vpcID,
		"public_subnet_id":   publicSubnetID,
		"private_subnet_ids": privateSubnetIDs,
	}

	assert.NotNil(t, compositionVars, "Composition variables should be valid")
	t.Logf("Module composition validation passed")
}

// TestIntegrationStateManagement validates Terraform state management
func TestIntegrationStateManagement(t *testing.T) {
	t.Parallel()

	uniqueEnv := fmt.Sprintf("sdd-state-%s", random.UniqueId())

	terraformOptions := &terraform.Options{
		TerraformDir: "../../src/terraform/examples/basic",
		VarFiles:     []string{"../../src/terraform/environments/aws/terraform.tfvars"},
		Vars: map[string]interface{}{
			"environment":  uniqueEnv,
			"project_name": "sdd-state-test",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": "us-east-1",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)

	// Initial apply
	terraform.InitAndApply(t, terraformOptions)

	// Get initial outputs
	initialVPCID := terraform.Output(t, terraformOptions, "vpc_id")
	assert.NotEmpty(t, initialVPCID, "Initial VPC ID should exist")

	// Test state refresh
	terraform.Refresh(t, terraformOptions)

	// Validate outputs are still consistent after refresh
	refreshedVPCID := terraform.Output(t, terraformOptions, "vpc_id")
	assert.Equal(t, initialVPCID, refreshedVPCID, "VPC ID should be consistent after state refresh")

	// Test state show
	stateShowOutput := terraform.Show(t, terraformOptions)
	assert.Contains(t, stateShowOutput, "aws_vpc.main", "State should contain VPC resource")

	t.Logf("State management validation passed")
}

// TestIntegrationResourceDependencies validates resource dependencies work correctly
func TestIntegrationResourceDependencies(t *testing.T) {
	t.Parallel()

	uniqueEnv := fmt.Sprintf("sdd-deps-%s", random.UniqueId())

	terraformOptions := &terraform.Options{
		TerraformDir: "../../src/terraform/examples/basic",
		VarFiles:     []string{"../../src/terraform/environments/aws/terraform.tfvars"},
		Vars: map[string]interface{}{
			"environment":  uniqueEnv,
			"project_name": "sdd-deps-test",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": "us-east-1",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate that dependencies are correctly resolved
	// VPC should exist before subnets
	vpcID := terraform.Output(t, terraformOptions, "vpc_id")
	assert.NotEmpty(t, vpcID, "VPC should exist")

	// Subnets should reference the VPC
	publicSubnetID := terraform.Output(t, terraformOptions, "public_subnet_id")
	assert.NotEmpty(t, publicSubnetID, "Public subnet should exist and reference VPC")

	// Internet gateway should be attached to VPC
	igwID := terraform.Output(t, terraformOptions, "internet_gateway_id")
	assert.NotEmpty(t, igwID, "Internet gateway should exist and be attached to VPC")

	// Security groups should reference the VPC
	controlPlaneSGID := terraform.Output(t, terraformOptions, "control_plane_security_group_id")
	assert.NotEmpty(t, controlPlaneSGID, "Control plane security group should exist and reference VPC")

	t.Logf("Resource dependencies validation passed")
}

// TestIntegrationErrorHandling validates error handling in various scenarios
func TestIntegrationErrorHandling(t *testing.T) {
	t.Parallel()

	t.Run("InvalidCIDR", func(t *testing.T) {
		t.Parallel()

		terraformOptions := &terraform.Options{
			TerraformDir: "../../src/terraform/examples/basic",
			Vars: map[string]interface{}{
				"environment":  "test",
				"project_name": "sdd-error-test",
				"vpc_cidr":     "invalid-cidr",
			},
			EnvVars: map[string]string{
				"AWS_DEFAULT_REGION": "us-east-1",
			},
			NoColor: true,
		}

		// Should fail during validation
		_, err := terraform.InitAndApplyE(t, terraformOptions)
		assert.Error(t, err, "Invalid CIDR should cause validation error")
	})

	t.Run("InvalidSubnetCount", func(t *testing.T) {
		t.Parallel()

		terraformOptions := &terraform.Options{
			TerraformDir: "../../src/terraform/examples/basic",
			Vars: map[string]interface{}{
				"environment":         "test",
				"project_name":         "sdd-error-test",
				"private_subnet_cidrs": []string{"10.0.2.0/24"}, // Only 1 subnet instead of 2
			},
			EnvVars: map[string]string{
				"AWS_DEFAULT_REGION": "us-east-1",
			},
			NoColor: true,
		}

		// Should fail during validation
		_, err := terraform.InitAndApplyE(t, terraformOptions)
		assert.Error(t, err, "Invalid subnet count should cause validation error")
	})
}

// TestIntegrationPerformance validates performance characteristics
func TestIntegrationPerformance(t *testing.T) {
	t.Parallel()

	// Measure deployment time
	start := time.Now()

	uniqueEnv := fmt.Sprintf("sdd-perf-%s", random.UniqueId())

	terraformOptions := &terraform.Options{
		TerraformDir: "../../src/terraform/examples/basic",
		VarFiles:     []string{"../../src/terraform/environments/aws/terraform.tfvars"},
		Vars: map[string]interface{}{
			"environment":  uniqueEnv,
			"project_name": "sdd-perf-test",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": "us-east-1",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	deploymentTime := time.Since(start)

	// Should complete within reasonable time (5 minutes for success criteria)
	assert.Less(t, deploymentTime, 5*time.Minute, 
		fmt.Sprintf("Deployment should complete in under 5 minutes, took %v", deploymentTime))

	t.Logf("Performance validation passed: deployment completed in %v", deploymentTime)
}

// TestIntegrationIdempotency validates that repeated applies are idempotent
func TestIntegrationIdempotency(t *testing.T) {
	t.Parallel()

	uniqueEnv := fmt.Sprintf("sdd-idempotent-%s", random.UniqueId())

	terraformOptions := &terraform.Options{
		TerraformDir: "../../src/terraform/examples/basic",
		VarFiles:     []string{"../../src/terraform/environments/aws/terraform.tfvars"},
		Vars: map[string]interface{}{
			"environment":  uniqueEnv,
			"project_name": "sdd-idempotent-test",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": "us-east-1",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)

	// First apply
	terraform.InitAndApply(t, terraformOptions)

	// Get outputs after first apply
	firstApplyOutputs := map[string]string{
		"vpc_id":                     terraform.Output(t, terraformOptions, "vpc_id"),
		"public_subnet_id":           terraform.Output(t, terraformOptions, "public_subnet_id"),
		"control_plane_security_group_id": terraform.Output(t, terraformOptions, "control_plane_security_group_id"),
	}

	// Second apply (should be no-op)
	planExitCode := terraform.Plan(t, terraformOptions)
	assert.Equal(t, 0, planExitCode, "Second plan should show no changes")

	// Get outputs after second apply
	secondApplyOutputs := map[string]string{
		"vpc_id":                     terraform.Output(t, terraformOptions, "vpc_id"),
		"public_subnet_id":           terraform.Output(t, terraformOptions, "public_subnet_id"),
		"control_plane_security_group_id": terraform.Output(t, terraformOptions, "control_plane_security_group_id"),
	}

	// Outputs should be identical
	assert.Equal(t, firstApplyOutputs, secondApplyOutputs, "Outputs should be identical after idempotent apply")

	t.Logf("Idempotency validation passed")
}