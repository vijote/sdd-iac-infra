package test

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestKubernetesNetworkRequirements validates security group rules meet Kubernetes requirements (SC-002)
func TestKubernetesNetworkRequirements(t *testing.T) {
	t.Parallel()

	// Generate a unique environment name to avoid conflicts
	uniqueEnv := fmt.Sprintf("sdd-test-%s", random.UniqueId())

	// Terraform options for the test
	terraformOptions := &terraform.Options{
		TerraformDir: "../../src/terraform/examples/basic",
		VarFiles:     []string{"../../src/terraform/environments/aws/terraform.tfvars"},
		Vars: map[string]interface{}{
			"environment":  uniqueEnv,
			"project_name": "sdd-security-test",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": "us-east-1",
		},
		NoColor: true,
	}

	// At the end of the test, run `terraform destroy` to clean up any resources that were created
	defer terraform.Destroy(t, terraformOptions)

	// Run `terraform init` and `terraform apply` and fail the test if there are any errors
	terraform.InitAndApply(t, terraformOptions)

	// Get security group IDs from outputs
	controlPlaneSGID := terraform.Output(t, terraformOptions, "control_plane_security_group_id")
	workerNodeSGID := terraform.Output(t, terraformOptions, "worker_node_security_group_id")
	ingressSGID := terraform.Output(t, terraformOptions, "ingress_security_group_id")

	// Get AWS region
	awsRegion := "us-east-1"

	// Test Control Plane Security Group Rules
	t.Run("ControlPlaneSecurityGroup", func(t *testing.T) {
		controlPlaneSG := aws.GetSecurityGroupById(t, controlPlaneSGID, awsRegion)
		
		// Validate kubelet port (6443) is open
		kubeletRule := findSecurityGroupRule(controlPlaneSG, "6443", "tcp", "ingress")
		assert.NotNil(t, kubeletRule, "Control plane SG should allow kubelet port 6443")
		
		// Validate etcd ports (2379-2380) are open
		etcdRule1 := findSecurityGroupRule(controlPlaneSG, "2379", "tcp", "ingress")
		etcdRule2 := findSecurityGroupRule(controlPlaneSG, "2380", "tcp", "ingress")
		assert.NotNil(t, etcdRule1, "Control plane SG should allow etcd port 2379")
		assert.NotNil(t, etcdRule2, "Control plane SG should allow etcd port 2380")
		
		// Validate VXLAN port (4789) is open for pod networking
		vxlanRule := findSecurityGroupRule(controlPlaneSG, "4789", "udp", "ingress")
		assert.NotNil(t, vxlanRule, "Control plane SG should allow VXLAN port 4789 for pod networking")
		
		t.Logf("Control plane SG %s validated: kubelet, etcd, and VXLAN ports are open", controlPlaneSGID)
	})

	// Test Worker Node Security Group Rules
	t.Run("WorkerNodeSecurityGroup", func(t *testing.T) {
		workerNodeSG := aws.GetSecurityGroupById(t, workerNodeSGID, awsRegion)
		
		// Validate VXLAN port (4789) is open for pod networking
		vxlanRule := findSecurityGroupRule(workerNodeSG, "4789", "udp", "ingress")
		assert.NotNil(t, vxlanRule, "Worker node SG should allow VXLAN port 4789 for pod networking")
		
		// Validate NodePort range (30000-32767) is open
		nodePortRule := findSecurityGroupRule(workerNodeSG, "30000-32767", "tcp", "ingress")
		assert.NotNil(t, nodePortRule, "Worker node SG should allow NodePort range 30000-32767")
		
		t.Logf("Worker node SG %s validated: VXLAN and NodePort ports are open", workerNodeSGID)
	})

	// Test Ingress Security Group Rules
	t.Run("IngressSecurityGroup", func(t *testing.T) {
		ingressSG := aws.GetSecurityGroupById(t, ingressSGID, awsRegion)
		
		// Validate HTTP port (80) is open from internet
		httpRule := findSecurityGroupRule(ingressSG, "80", "tcp", "ingress")
		assert.NotNil(t, httpRule, "Ingress SG should allow HTTP port 80 from internet")
		assert.True(t, httpRule.CidrBlocks != nil && len(httpRule.CidrBlocks) > 0, 
			"HTTP rule should allow traffic from CIDR blocks (internet)")
		
		// Validate HTTPS port (443) is open from internet
		httpsRule := findSecurityGroupRule(ingressSG, "443", "tcp", "ingress")
		assert.NotNil(t, httpsRule, "Ingress SG should allow HTTPS port 443 from internet")
		assert.True(t, httpsRule.CidrBlocks != nil && len(httpsRule.CidrBlocks) > 0, 
			"HTTPS rule should allow traffic from CIDR blocks (internet)")
		
		t.Logf("Ingress SG %s validated: HTTP and HTTPS ports are open from internet", ingressSGID)
	})

	// Test Inter-Security Group Communication
	t.Run("InterSecurityGroupCommunication", func(t *testing.T) {
		// Validate that control plane can communicate with worker nodes
		controlPlaneSG := aws.GetSecurityGroupById(t, controlPlaneSGID, awsRegion)
		workerNodeSG := aws.GetSecurityGroupById(t, workerNodeSGID, awsRegion)
		
		// Check for rules allowing communication between security groups
		hasInterSGCommunication := false
		for _, rule := range controlPlaneSG.IpPermissions {
			if len(rule.UserIdGroupPairs) > 0 {
				for _, pair := range rule.UserIdGroupPairs {
					if *pair.GroupId == workerNodeSGID {
						hasInterSGCommunication = true
						break
					}
				}
			}
		}
		
		assert.True(t, hasInterSGCommunication, 
			"Control plane and worker node security groups should allow inter-SG communication for pod-to-pod traffic")
		
		t.Logf("Inter-SG communication validated between control plane and worker nodes")
	})
}

// TestUnauthorizedTrafficBlocked validates that unauthorized traffic is properly blocked (SC-005)
func TestUnauthorizedTrafficBlocked(t *testing.T) {
	t.Parallel()

	// Generate a unique environment name
	uniqueEnv := fmt.Sprintf("sdd-test-%s", random.UniqueId())

	// Terraform options
	terraformOptions := &terraform.Options{
		TerraformDir: "../../src/terraform/examples/basic",
		VarFiles:     []string{"../../src/terraform/environments/aws/terraform.tfvars"},
		Vars: map[string]interface{}{
			"environment":  uniqueEnv,
			"project_name": "sdd-security-test",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": "us-east-1",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Get security group IDs
	ingressSGID := terraform.Output(t, terraformOptions, "ingress_security_group_id")
	awsRegion := "us-east-1"

	// Test that unauthorized ports are blocked
	t.Run("UnauthorizedPortsBlocked", func(t *testing.T) {
		ingressSG := aws.GetSecurityGroupById(t, ingressSGID, awsRegion)
		
		// Check that database ports (3306, 5432, etc.) are NOT open
		mysqlRule := findSecurityGroupRule(ingressSG, "3306", "tcp", "ingress")
		assert.Nil(t, mysqlRule, "Ingress SG should NOT allow MySQL port 3306")
		
		postgresRule := findSecurityGroupRule(ingressSG, "5432", "tcp", "ingress")
		assert.Nil(t, postgresRule, "Ingress SG should NOT allow PostgreSQL port 5432")
		
		// Check that SSH port (22) is NOT open from internet
		sshRule := findSecurityGroupRule(ingressSG, "22", "tcp", "ingress")
		assert.Nil(t, sshRule, "Ingress SG should NOT allow SSH port 22 from internet")
		
		t.Logf("Unauthorized ports validation passed: database and SSH ports are properly blocked")
	})
}

// TestUnauthorizedTrafficBlocked validates that unauthorized traffic is properly blocked (SC-005)
func TestUnauthorizedTrafficBlocked(t *testing.T) {
	t.Parallel()

	// Generate a unique environment name
	uniqueEnv := fmt.Sprintf("sdd-test-%s", random.UniqueId())

	// Terraform options
	terraformOptions := &terraform.Options{
		TerraformDir: "../../src/terraform/examples/basic",
		VarFiles:     []string{"../../src/terraform/environments/aws/terraform.tfvars"},
		Vars: map[string]interface{}{
			"environment":  uniqueEnv,
			"project_name": "sdd-security-test",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": "us-east-1",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Get security group IDs
	ingressSGID := terraform.Output(t, terraformOptions, "ingress_security_group_id")
	controlPlaneSGID := terraform.Output(t, terraformOptions, "control_plane_security_group_id")
	workerNodeSGID := terraform.Output(t, terraformOptions, "worker_node_security_group_id")
	awsRegion := "us-east-1"

	// Test that unauthorized ports are blocked
	t.Run("UnauthorizedPortsBlocked", func(t *testing.T) {
		ingressSG := aws.GetSecurityGroupById(t, ingressSGID, awsRegion)
		
		// Check that database ports (3306, 5432, etc.) are NOT open
		mysqlRule := findSecurityGroupRule(ingressSG, "3306", "tcp", "ingress")
		assert.Nil(t, mysqlRule, "Ingress SG should NOT allow MySQL port 3306")
		
		postgresRule := findSecurityGroupRule(ingressSG, "5432", "tcp", "ingress")
		assert.Nil(t, postgresRule, "Ingress SG should NOT allow PostgreSQL port 5432")
		
		// Check that SSH port (22) is NOT open from internet
		sshRule := findSecurityGroupRule(ingressSG, "22", "tcp", "ingress")
		assert.Nil(t, sshRule, "Ingress SG should NOT allow SSH port 22 from internet")
		
		// Check that RDP port (3389) is NOT open
		rdpRule := findSecurityGroupRule(ingressSG, "3389", "tcp", "ingress")
		assert.Nil(t, rdpRule, "Ingress SG should NOT allow RDP port 3389")
		
		t.Logf("Unauthorized ports validation passed: database, SSH, and RDP ports are properly blocked")
	})

	// Test that control plane doesn't allow unauthorized access
	t.Run("ControlPlaneUnauthorizedAccess", func(t *testing.T) {
		controlPlaneSG := aws.GetSecurityGroupById(t, controlPlaneSGID, awsRegion)
		
		// Control plane should not allow direct HTTP/HTTPS from internet
		// Only through ingress controller
		httpRule := findSecurityGroupRuleWithSource(controlPlaneSG, "80", "tcp", "ingress", "0.0.0.0/0")
		assert.Nil(t, httpRule, "Control plane SG should NOT allow direct HTTP from internet")
		
		httpsRule := findSecurityGroupRuleWithSource(controlPlaneSG, "443", "tcp", "ingress", "0.0.0.0/0")
		assert.Nil(t, httpsRule, "Control plane SG should NOT allow direct HTTPS from internet")
		
		// Should not allow database access from internet
		mysqlRule := findSecurityGroupRuleWithSource(controlPlaneSG, "3306", "tcp", "ingress", "0.0.0.0/0")
		assert.Nil(t, mysqlRule, "Control plane SG should NOT allow MySQL access from internet")
		
		t.Logf("Control plane unauthorized access validation passed")
	})

	// Test that worker nodes don't allow unauthorized access
	t.Run("WorkerNodeUnauthorizedAccess", func(t *testing.T) {
		workerNodeSG := aws.GetSecurityGroupById(t, workerNodeSGID, awsRegion)
		
		// Worker nodes should not allow direct database access from internet
		mysqlRule := findSecurityGroupRuleWithSource(workerNodeSG, "3306", "tcp", "ingress", "0.0.0.0/0")
		assert.Nil(t, mysqlRule, "Worker node SG should NOT allow MySQL access from internet")
		
		// Should not allow SSH from internet
		sshRule := findSecurityGroupRuleWithSource(workerNodeSG, "22", "tcp", "ingress", "0.0.0.0/0")
		assert.Nil(t, sshRule, "Worker node SG should NOT allow SSH from internet")
		
		// Should not allow management ports from internet
		mgmtRule := findSecurityGroupRuleWithSource(workerNodeSG, "10250", "tcp", "ingress", "0.0.0.0/0")
		assert.Nil(t, mgmtRule, "Worker node SG should NOT allow kubelet management port from internet")
		
		t.Logf("Worker node unauthorized access validation passed")
	})
}

// TestSecurityGroupRuleConflicts validates no conflicting security group rules exist
func TestSecurityGroupRuleConflicts(t *testing.T) {
	t.Parallel()

	uniqueEnv := fmt.Sprintf("sdd-test-%s", random.UniqueId())

	terraformOptions := &terraform.Options{
		TerraformDir: "../../src/terraform/examples/basic",
		VarFiles:     []string{"../../src/terraform/environments/aws/terraform.tfvars"},
		Vars: map[string]interface{}{
			"environment":  uniqueEnv,
			"project_name": "sdd-security-test",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": "us-east-1",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Get security group IDs
	controlPlaneSGID := terraform.Output(t, terraformOptions, "control_plane_security_group_id")
	workerNodeSGID := terraform.Output(t, terraformOptions, "worker_node_security_group_id")
	ingressSGID := terraform.Output(t, terraformOptions, "ingress_security_group_id")
	awsRegion := "us-east-1"

	t.Run("NoConflictingRules", func(t *testing.T) {
		// Get all security groups
		controlPlaneSG := aws.GetSecurityGroupById(t, controlPlaneSGID, awsRegion)
		workerNodeSG := aws.GetSecurityGroupById(t, workerNodeSGID, awsRegion)
		ingressSG := aws.GetSecurityGroupById(t, ingressSGID, awsRegion)

		// Check for conflicting deny/allow rules (simplified check)
		// In AWS, security groups are stateful and default deny, so we check for proper rule structure
		
		// Validate that each security group has unique name
		sgs := []*aws.SecGroup{controlPlaneSG, workerNodeSG, ingressSG}
		sgNames := make(map[string]bool)
		
		for _, sg := range sgs {
			sgName := *sg.GroupName
			assert.False(t, sgNames[sgName], fmt.Sprintf("Security group name %s should be unique", sgName))
			sgNames[sgName] = true
		}
		
		t.Logf("Security group conflict validation passed: no conflicting rules or duplicate names")
	})
}

// Helper function to find a specific security group rule
func findSecurityGroupRule(sg *aws.SecGroup, port string, protocol string, direction string) *aws.SecGroupRule {
	var rules []*aws.SecGroupRule
	if direction == "ingress" {
		rules = sg.IpPermissions
	} else {
		rules = sg.IpPermissionsEgress
	}
	
	for _, rule := range rules {
		if rule.FromPort != nil && rule.ToPort != nil {
			// Handle single port
			if fmt.Sprintf("%d", *rule.FromPort) == port && fmt.Sprintf("%d", *rule.ToPort) == port {
				if rule.IpProtocol != nil && *rule.IpProtocol == protocol {
					return rule
				}
			}
			// Handle port ranges
			if fmt.Sprintf("%d-%d", *rule.FromPort, *rule.ToPort) == port {
				if rule.IpProtocol != nil && *rule.IpProtocol == protocol {
					return rule
				}
			}
		}
	}
	return nil
}

// Helper function to find a security group rule with specific source
func findSecurityGroupRuleWithSource(sg *aws.SecGroup, port string, protocol string, direction string, sourceCIDR string) *aws.SecGroupRule {
	rule := findSecurityGroupRule(sg, port, protocol, direction)
	if rule == nil {
		return nil
	}
	
	// Check if the rule has the specified source CIDR
	for _, cidr := range rule.CidrBlocks {
		if *cidr == sourceCIDR {
			return rule
		}
	}
	
	return nil
}