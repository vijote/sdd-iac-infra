package test

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestVPCDeploymentPerformance validates that VPC deployment completes in under 5 minutes (SC-001)
func TestVPCDeploymentPerformance(t *testing.T) {
	t.Parallel()

	// Record start time
	startTime := time.Now()

	// Terraform options for the test
	terraformOptions := &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: "../../src/terraform/examples/basic",

		// Variables to pass to our Terraform code using -var-file options
		VarFiles: []string{"../../src/terraform/environments/aws/terraform.tfvars"},

		// Environment variables for AWS credentials
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": "us-east-1",
		},

		// Disable colors for cleaner output
		NoColor: true,
	}

	// At the end of the test, run `terraform destroy` to clean up any resources that were created
	defer terraform.Destroy(t, terraformOptions)

	// Run `terraform init` and `terraform apply` and fail the test if there are any errors
	_, applyErr := terraform.InitAndApply(t, terraformOptions)
	
	// Calculate deployment time
	deploymentTime := time.Since(startTime)
	deploymentMinutes := deploymentTime.Minutes()

	// Log deployment time
	t.Logf("VPC deployment completed in %.2f minutes", deploymentMinutes)

	// Assert deployment completed successfully
	assert.NoError(t, applyErr, "Terraform apply should succeed")

	// Assert deployment time is under 5 minutes (300 seconds)
	assert.Less(t, deploymentTime, 5*time.Minute, 
		fmt.Sprintf("VPC deployment should complete in under 5 minutes, but took %.2f minutes", deploymentMinutes))

	// Validate outputs exist
	vpcID := terraform.Output(t, terraformOptions, "vpc_id")
	assert.NotEmpty(t, vpcID, "VPC ID should be output")

	publicSubnetID := terraform.Output(t, terraformOptions, "public_subnet_id")
	assert.NotEmpty(t, publicSubnetID, "Public subnet ID should be output")

	privateSubnetIDs := terraform.OutputList(t, terraformOptions, "private_subnet_ids")
	assert.Len(t, privateSubnetIDs, 2, "Should have exactly 2 private subnets")
}

// TestMiniStackDeploymentPerformance validates MiniStack deployment performance
func TestMiniStackDeploymentPerformance(t *testing.T) {
	t.Parallel()

	// Record start time
	startTime := time.Now()

	// Terraform options for MiniStack test
	terraformOptions := &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: "../../src/terraform/examples/basic",

		// Variables to pass to our Terraform code using -var-file options
		VarFiles: []string{"../../src/terraform/environments/ministack/terraform.tfvars"},

		// Environment variables for MiniStack
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": "local",
		},

		// Disable colors for cleaner output
		NoColor: true,
	}

	// At the end of the test, run `terraform destroy` to clean up any resources that were created
	defer terraform.Destroy(t, terraformOptions)

	// Run `terraform init` and `terraform apply` and fail the test if there are any errors
	_, applyErr := terraform.InitAndApply(t, terraformOptions)
	
	// Calculate deployment time
	deploymentTime := time.Since(startTime)
	deploymentMinutes := deploymentTime.Minutes()

	// Log deployment time
	t.Logf("MiniStack VPC deployment completed in %.2f minutes", deploymentMinutes)

	// Assert deployment completed successfully
	assert.NoError(t, applyErr, "Terraform apply should succeed for MiniStack")

	// Assert deployment time is under 5 minutes (should be faster for local)
	assert.Less(t, deploymentTime, 5*time.Minute, 
		fmt.Sprintf("MiniStack VPC deployment should complete in under 5 minutes, but took %.2f minutes", deploymentMinutes))

	// Validate outputs exist
	vpcID := terraform.Output(t, terraformOptions, "vpc_id")
	assert.NotEmpty(t, vpcID, "VPC ID should be output for MiniStack")

	publicSubnetID := terraform.Output(t, terraformOptions, "public_subnet_id")
	assert.NotEmpty(t, publicSubnetID, "Public subnet ID should be output for MiniStack")

	privateSubnetIDs := terraform.OutputList(t, terraformOptions, "private_subnet_ids")
	assert.Len(t, privateSubnetIDs, 2, "Should have exactly 2 private subnets for MiniStack")
}

// BenchmarkTerraformApply provides performance benchmarking
func BenchmarkTerraformApply(b *testing.B) {
	for i := 0; i < b.N; i++ {
		// Terraform options for the benchmark
		terraformOptions := &terraform.Options{
			TerraformDir: "../../src/terraform/examples/basic",
			VarFiles:     []string{"../../src/terraform/environments/aws/terraform.tfvars"},
			EnvVars: map[string]string{
				"AWS_DEFAULT_REGION": "us-east-1",
			},
			NoColor: true,
		}

		// Clean up after each iteration
		defer terraform.Destroy(b, terraformOptions)

		// Run terraform apply and measure time
		start := time.Now()
		terraform.InitAndApply(b, terraformOptions)
		elapsed := time.Since(start)

		b.Logf("Iteration %d: %v", i, elapsed)
	}
}