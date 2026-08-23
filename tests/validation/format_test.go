package validation

import (
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

// TestTerraformFormat checks that all Terraform files are properly formatted
func TestTerraformFormat(t *testing.T) {
	// Find all .tf files in the project
	tfFiles, err := filepath.Glob("../../src/terraform/**/*.tf")
	require.NoError(t, err)

	if len(tfFiles) == 0 {
		t.Skip("No Terraform files found")
	}

	// Run terraform fmt check
	cmd := exec.Command("terraform", "fmt", "-check", "-recursive", "../../src/terraform")
	output, err := cmd.CombinedOutput()

	if err != nil {
		t.Errorf("Terraform files are not properly formatted:\n%s", string(output))
	}
}

// TestTerraformValidate checks that all Terraform configurations are valid
func TestTerraformValidate(t *testing.T) {
	environments := []string{"dev", "prod"}

	for _, env := range environments {
		t.Run(env, func(t *testing.T) {
			// Initialize Terraform
			initCmd := exec.Command("terraform", "init", "-input=false", "-backend=false")
			initCmd.Dir = "../../src/terraform/environments/" + env
			output, err := initCmd.CombinedOutput()
			if err != nil {
				t.Errorf("Failed to initialize %s environment: %s", env, string(output))
			}

			// Validate configuration
			validateCmd := exec.Command("terraform", "validate", "-no-color")
			validateCmd.Dir = "../../src/terraform/environments/" + env
			output, err = validateCmd.CombinedOutput()

			if err != nil {
				t.Errorf("Terraform validation failed for %s environment:\n%s", env, string(output))
			}
		})
	}
}