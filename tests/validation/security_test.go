package validation

import (
	"context"
	"encoding/json"
	"os/exec"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/stretchr/testify/require"
)

// TestSecurityGroupRules validates security group configurations
func TestSecurityGroupRules(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping security test in short mode")
	}

	cfg, err := config.LoadDefaultConfig(context.TODO())
	require.NoError(t, err)

	ec2Client := ec2.NewFromConfig(cfg)

	// Get all security groups with the project tag
	sgs, err := ec2Client.DescribeSecurityGroups(context.TODO(), &ec2.DescribeSecurityGroupsInput{
		Filters: []ec2.Filter{
			{
				Name:   aws.String("tag:Project"),
				Values: []string{"sdd-infra"},
			},
		},
	})
	require.NoError(t, err)

	for _, sg := range sgs.SecurityGroups {
		t.Run(*sg.GroupName, func(t *testing.T) {
			// Check for overly permissive inbound rules
			for _, rule := range sg.IpPermissions {
				// Disallow 0.0.0.0/0 for all ports
				if rule.IpRanges != nil {
					for _, ipRange := range rule.IpRanges {
						if *ipRange.CidrIp == "0.0.0.0/0" && rule.FromPort != nil && *rule.FromPort == 22 {
							t.Errorf("Security group %s allows SSH from 0.0.0.0/0", *sg.GroupName)
						}
					}
				}
			}
		})
	}
}

// TestIAMLeastPrivilege validates IAM roles follow least privilege
func TestIAMLeastPrivilege(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping IAM test in short mode")
	}

	cfg, err := config.LoadDefaultConfig(context.TODO())
	require.NoError(t, err)

	iamClient := iam.NewFromConfig(cfg)

	// Get Terraform roles
	roles, err := iamClient.ListRoles(context.TODO(), &iam.ListRolesInput{
		PathPrefix: aws.String("/"),
	})
	require.NoError(t, err)

	for _, role := range roles.Roles {
		if *role.RoleName == "terraform-dev-role" || *role.RoleName == "terraform-prod-role" {
			t.Run(*role.RoleName, func(t *testing.T) {
				// Get attached policies
				policies, err := iamClient.ListAttachedRolePolicies(context.TODO(), &iam.ListAttachedRolePoliciesInput{
					RoleName: role.RoleName,
				})
				require.NoError(t, err)

				// Check for overly permissive policies
				for _, policy := range policies.AttachedPolicies {
					if *policy.PolicyName == "AdministratorAccess" {
						t.Errorf("Role %s has AdministratorAccess policy - violates least privilege", *role.RoleName)
					}
				}

				// Get inline policies
				inlinePolicies, err := iamClient.ListRolePolicies(context.TODO(), &iam.ListRolePoliciesInput{
					RoleName: role.RoleName,
				})
				require.NoError(t, err)

				for _, policyName := range inlinePolicies.PolicyNames {
					policyVersion, err := iamClient.GetRolePolicy(context.TODO(), &iam.GetRolePolicyInput{
						RoleName:   role.RoleName,
						PolicyName: policyName,
					})
					require.NoError(t, err)

					var policyDoc map[string]interface{}
					err = json.Unmarshal([]byte(*policyVersion.PolicyDocument), &policyDoc)
					require.NoError(t, err)

					// Check for wildcard actions in statements
					if statements, ok := policyDoc["Statement"].([]interface{}); ok {
						for _, stmt := range statements {
							if statement, ok := stmt.(map[string]interface{}); ok {
								if effect, ok := statement["Effect"].(string); ok && effect == "Allow" {
									if action, ok := statement["Action"].([]interface{}); ok {
										for _, a := range action {
											if actionStr, ok := a.(string); ok && actionStr == "*" {
												t.Errorf("Role %s has wildcard action in policy %s", *role.RoleName, *policyName)
											}
										}
									}
								}
							}
						}
					}
				}
			})
		}
	}
}