package validation

import (
	"encoding/json"
	"os/exec"
	"testing"

	"github.com/stretchr/testify/require"
)

// TestCostGuardrails checks for potentially expensive resources before apply
func TestCostGuardrails(t *testing.T) {
	environments := []string{"dev", "prod"}

	for _, env := range environments {
		t.Run(env, func(t *testing.T) {
			// Generate plan JSON
			cmd := exec.Command("terraform", "plan", "-json", "-out=tfplan")
			cmd.Dir = "../../src/terraform/environments/" + env
			output, err := cmd.CombinedOutput()
			if err != nil {
				t.Skipf("Cannot generate plan for %s: %s", env, string(output))
			}

			// Convert plan to JSON
			showCmd := exec.Command("terraform", "show", "-json", "tfplan")
			showCmd.Dir = "../../src/terraform/environments/" + env
			planOutput, err := showCmd.Output()
			if err != nil {
				t.Skipf("Cannot read plan for %s: %v", env, err)
			}

			var plan map[string]interface{}
			err = json.Unmarshal(planOutput, &plan)
			require.NoError(t, err)

			// Check for expensive resources
			if resourceChanges, ok := plan["resource_changes"].([]interface{}); ok {
				for _, rc := range resourceChanges {
					if resource, ok := rc.(map[string]interface{}); ok {
						if change, ok := resource["change"].(map[string]interface{}); ok {
							if actions, ok := change["actions"].([]interface{}); ok {
								// Only check for create actions
								if len(actions) == 1 && actions[0] == "create" {
									resourceType := resource["type"].(string)
									checkExpensiveResource(t, resourceType, change)
								}
							}
						}
					}
				}
			}
		})
	}
}

func checkExpensiveResource(t *testing.T, resourceType string, change map[string]interface{}) {
	switch resourceType {
	case "aws_instance":
		checkInstanceCost(t, change)
	case "aws_rds_instance":
		checkRDSInstanceCost(t, change)
	case "aws_ebs_volume":
		checkEBSVolumeCost(t, change)
	}
}

func checkInstanceCost(t *testing.T, change map[string]interface{}) {
	if values, ok := change["after"].(map[string]interface{}); ok {
		if instanceType, ok := values["instance_type"].(string); ok {
			// Flag expensive instance types
			expensiveTypes := []string{
				"x2iezn", "x2iedn", "x2iezn", // High memory
				"p4d", "p3dn", "inf1",        // GPU/ML
				"z1d", "u-6tb1", "u-12tb1",  // High memory/bandwidth
			}

			for _, expensive := range expensiveTypes {
				if len(instanceType) >= len(expensive) && instanceType[:len(expensive)] == expensive {
					t.Errorf("Expensive instance type detected: %s", instanceType)
				}
			}
		}
	}
}

func checkRDSInstanceCost(t *testing.T, change map[string]interface{}) {
	if values, ok := change["after"].(map[string]interface{}); ok {
		if instanceClass, ok := values["instance_class"].(string); ok {
			// Flag expensive RDS classes
			expensiveClasses := []string{
				"db.r6g.16xlarge", "db.r6g.12xlarge", "db.r5.24xlarge",
				"db.x2g.16xlarge", "db.x2.2xlarge",
			}

			for _, expensive := range expensiveClasses {
				if instanceClass == expensive {
					t.Errorf("Expensive RDS instance class detected: %s", instanceClass)
				}
			}

			// Check for multi-AZ in production (good) but warn in dev
			if multiAZ, ok := values["multi_az"].(bool); ok && multiAZ {
				t.Logf("Multi-AZ RDS instance detected (additional cost): %s", instanceClass)
			}
		}
	}
}

func checkEBSVolumeCost(t *testing.T, change map[string]interface{}) {
	if values, ok := change["after"].(map[string]interface{}); ok {
		if size, ok := values["size"].(int); ok && size > 1000 { // > 1TB
			t.Errorf("Large EBS volume detected: %d GB", size)
		}

		if volumeType, ok := values["type"].(string); ok {
			if volumeType == "io1" || volumeType == "io2" {
				if iops, ok := values["iops"].(int); ok && iops > 10000 {
					t.Errorf("High IOPS EBS volume detected: %d IOPS (type: %s)", iops, volumeType)
				}
			}
		}
	}
}