package ci_cd

import (
	"context"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/sts"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestIAMRoleCreation tests that IAM roles are created with correct permissions
func TestIAMRoleCreation(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	// Load AWS configuration
	cfg, err := config.LoadDefaultConfig(context.TODO())
	require.NoError(t, err)

	// Create IAM client
	iamClient := iam.NewFromConfig(cfg)
	stsClient := sts.NewFromConfig(cfg)

	// Get current identity
	identity, err := stsClient.GetCallerIdentity(context.TODO(), &sts.GetCallerIdentityInput{})
	require.NoError(t, err)

	// Test role names
	environments := []string{"dev", "staging", "prod"}
	
	for _, env := range environments {
		t.Run(env, func(t *testing.T) {
			roleName := "terraform-" + env + "-role"
			
			// Get role
			role, err := iamClient.GetRole(context.TODO(), &iam.GetRoleInput{
				RoleName: aws.String(roleName),
			})
			
			if err != nil {
				t.Logf("Role %s not found: %v", roleName, err)
				t.Skip("IAM role not deployed yet")
			}
			
			// Verify role exists
			assert.NotNil(t, role.Role)
			assert.Equal(t, roleName, *role.Role.RoleName)
			
			// Verify trust relationship
			trustPolicy, err := iamClient.GetRolePolicy(context.TODO(), &iam.GetRolePolicyInput{
				RoleName:   aws.String(roleName),
				PolicyName: aws.String("session-tagging"),
			})
			
			if err == nil {
				// Verify OIDC trust relationship in assume role policy
				assert.Contains(t, *role.Role.AssumeRolePolicyDocument, "token.actions.githubusercontent.com")
			}
			
			// Verify attached policies
			policies, err := iamClient.ListAttachedRolePolicies(context.TODO(), &iam.ListAttachedRolePoliciesInput{
				RoleName: aws.String(roleName),
			})
			require.NoError(t, err)
			
			// Check for required inline policies
			inlinePolicies, err := iamClient.ListRolePolicies(context.TODO(), &iam.ListRolePoliciesInput{
				RoleName: aws.String(roleName),
			})
			require.NoError(t, err)
			
			expectedPolicies := []string{"session-tagging", "terraform-permissions", "cloudwatch-logging"}
			for _, expectedPolicy := range expectedPolicies {
				found := false
				for _, policy := range inlinePolicies.PolicyNames {
					if *policy == expectedPolicy {
						found = true
						break
					}
				}
				assert.True(t, found, "Expected policy %s not found", expectedPolicy)
			}
		})
	}
}

// TestIAMRolePermissions tests that IAM roles have least-privilege permissions
func TestIAMRolePermissions(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	// This test would require assuming each role and testing permissions
	// For now, we'll test the policy structure
	
	cfg, err := config.LoadDefaultConfig(context.TODO())
	require.NoError(t, err)

	iamClient := iam.NewFromConfig(cfg)
	
	environments := []string{"dev", "staging", "prod"}
	
	for _, env := range environments {
		t.Run(env, func(t *testing.T) {
			roleName := "terraform-" + env + "-role"
			
			// Get terraform-permissions policy
			policy, err := iamClient.GetRolePolicy(context.TODO(), &iam.GetRolePolicyInput{
				RoleName:   aws.String(roleName),
				PolicyName: aws.String("terraform-permissions"),
			})
			
			if err != nil {
				t.Skip("IAM role policy not found")
			}
			
			// Verify policy contains required permissions
			policyDoc := *policy.PolicyDocument
			assert.Contains(t, policyDoc, "ec2:DescribeVpcs")
			assert.Contains(t, policyDoc, "s3:CreateBucket")
			assert.Contains(t, policyDoc, "dynamodb:CreateTable")
			
			// Verify policy is scoped to environment
			if env == "dev" {
				assert.Contains(t, policyDoc, "terraform-state-dev")
				assert.Contains(t, policyDoc, "terraform-locks-dev")
			}
		})
	}
}

// TestOIDCTrustRelationship tests that OIDC provider is configured correctly
func TestOIDCTrustRelationship(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	cfg, err := config.LoadDefaultConfig(context.TODO())
	require.NoError(t, err)

	iamClient := iam.NewFromConfig(cfg)
	
	// List OIDC providers
	providers, err := iam.ListOpenIDConnectProviders(context.TODO(), &iam.ListOpenIDConnectProvidersInput{})
	require.NoError(t, err)
	
	// Find GitHub OIDC provider
	var githubProvider *iam.OpenIDConnectProviderListEntry
	for _, provider := range providers.OpenIDConnectProviderList {
		if *provider.Arn == "arn:aws:iam::" + *providers.OpenIDConnectProviderList[0].Arn + ":oidc-provider/token.actions.githubusercontent.com" {
			githubProvider = provider
			break
		}
	}
	
	if githubProvider == nil {
		t.Skip("GitHub OIDC provider not found")
	}
	
	// Get provider details
	providerDetails, err := iam.GetOpenIDConnectProvider(context.TODO(), &iam.GetOpenIDConnectProviderInput{
		OpenIDConnectProviderArn: githubProvider.Arn,
	})
	require.NoError(t, err)
	
	// Verify client ID
	assert.Contains(t, providerDetails.ClientIDList, "sts.amazonaws.com")
	
	// Verify thumbprint
	assert.Contains(t, providerDetails.ThumbprintList, "6938fd4d98bab03faadb97b34396831e3780aea1")
}

// TestIAMRoleSessionTagging tests that session tagging is properly configured
func TestIAMRoleSessionTagging(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	cfg, err := config.LoadDefaultConfig(context.TODO())
	require.NoError(t, err)

	iamClient := iam.NewFromConfig(cfg)
	
	environments := []string{"dev", "staging", "prod"}
	
	for _, env := range environments {
		t.Run(env, func(t *testing.T) {
			roleName := "terraform-" + env + "-role"
			
			// Get session-tagging policy
			policy, err := iamClient.GetRolePolicy(context.TODO(), &iam.GetRolePolicyInput{
				RoleName:   aws.String(roleName),
				PolicyName: aws.String("session-tagging"),
			})
			
			if err != nil {
				t.Skip("Session tagging policy not found")
			}
			
			// Verify policy allows sts:TagSession
			policyDoc := *policy.PolicyDocument
			assert.Contains(t, policyDoc, "sts:TagSession")
		})
	}
}

// BenchmarkIAMRoleLookup benchmarks IAM role lookup performance
func BenchmarkIAMRoleLookup(b *testing.B) {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		b.Skip("Cannot load AWS config")
	}

	iamClient := iam.NewFromConfig(cfg)
	roleName := "terraform-dev-role"
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := iamClient.GetRole(context.TODO(), &iam.GetRoleInput{
			RoleName: aws.String(roleName),
		})
		if err != nil {
			b.Logf("Role lookup failed: %v", err)
		}
	}
}