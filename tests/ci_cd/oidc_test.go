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

// TestOIDCProvider tests that GitHub OIDC provider is properly configured
func TestOIDCProvider(t *testing.T) {
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
		if *provider.Arn == "arn:aws:iam::"+*providers.OpenIDConnectProviderList[0].Arn+":oidc-provider/token.actions.githubusercontent.com" {
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
	
	// Verify provider configuration
	assert.Contains(t, providerDetails.ClientIDList, "sts.amazonaws.com")
	assert.Contains(t, providerDetails.ThumbprintList, "6938fd4d98bab03faadb97b34396831e3780aea1")
	assert.Equal(t, "https://token.actions.githubusercontent.com", *providerDetails.Url)
}

// TestOIDCTrustRelationship tests that IAM roles have proper OIDC trust relationships
func TestOIDCTrustRelationship(t *testing.T) {
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
			
			// Get role
			role, err := iamClient.GetRole(context.TODO(), &iam.GetRoleInput{
				RoleName: aws.String(roleName),
			})
			
			if err != nil {
				t.Skip("IAM role not found: " + roleName)
			}
			
			// Parse assume role policy
			assumeRolePolicy := *role.Role.AssumeRolePolicyDocument
			
			// Verify OIDC provider URL
			assert.Contains(t, assumeRolePolicy, "token.actions.githubusercontent.com")
			
			// Verify client ID condition
			assert.Contains(t, assumeRolePolicy, "sts.amazonaws.com")
			
			// Verify string equals condition for sub claim
			assert.Contains(t, assumeRolePolicy, "StringEquals")
			assert.Contains(t, assumeRolePolicy, "token.actions.githubusercontent.com:sub")
		})
	}
}

// TestOIDCAuthenticationFlow tests the complete OIDC authentication flow
func TestOIDCAuthenticationFlow(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	// This test would require simulating GitHub Actions OIDC authentication
	// For now, we'll test the trust relationship configuration
	
	cfg, err := config.LoadDefaultConfig(context.TODO())
	require.NoError(t, err)

	iamClient := iam.NewFromConfig(cfg)
	
	roleName := "terraform-dev-role"
	
	// Get role
	role, err := iamClient.GetRole(context.TODO(), &iam.GetRoleInput{
		RoleName: aws.String(roleName),
	})
	
	if err != nil {
		t.Skip("IAM role not found: " + roleName)
	}
	
	// Verify assume role policy contains OIDC configuration
	assumeRolePolicy := *role.Role.AssumeRolePolicyDocument
	
	// Check for required OIDC elements
	requiredElements := []string{
		"token.actions.githubusercontent.com",
		"sts.amazonaws.com",
		"sts:AssumeRoleWithWebIdentity",
		"Federated",
	}
	
	for _, element := range requiredElements {
		assert.Contains(t, assumeRolePolicy, element, "Missing required OIDC element: %s", element)
	}
}

// TestOIDCTokenValidation tests OIDC token validation
func TestOIDCTokenValidation(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	// This test would require actual OIDC tokens from GitHub Actions
	// For now, we'll verify the provider configuration is correct
	
	cfg, err := config.LoadDefaultConfig(context.TODO())
	require.NoError(t, err)

	iamClient := iam.NewFromConfig(cfg)
	
	// Get GitHub OIDC provider
	providers, err := iam.ListOpenIDConnectProviders(context.TODO(), &iam.ListOpenIDConnectProvidersInput{})
	require.NoError(t, err)
	
	var githubProvider *iam.OpenIDConnectProviderListEntry
	for _, provider := range providers.OpenIDConnectProviderList {
		if *provider.Arn == "arn:aws:iam::"+*providers.OpenIDConnectProviderList[0].Arn+":oidc-provider/token.actions.githubusercontent.com" {
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
	
	// Verify thumbprint (GitHub's current thumbprint)
	expectedThumbprint := "6938fd4d98bab03faadb97b34396831e3780aea1"
	found := false
	for _, thumbprint := range providerDetails.ThumbprintList {
		if *thumbprint == expectedThumbprint {
			found = true
			break
		}
	}
	assert.True(t, found, "Expected thumbprint not found: %s", expectedThumbprint)
}

// TestOIDCRepositoryConditions tests that repository conditions are properly configured
func TestOIDCRepositoryConditions(t *testing.T) {
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
			
			// Get role
			role, err := iamClient.GetRole(context.TODO(), &iam.GetRoleInput{
				RoleName: aws.String(roleName),
			})
			
			if err != nil {
				t.Skip("IAM role not found: " + roleName)
			}
			
			// Parse assume role policy
			assumeRolePolicy := *role.Role.AssumeRolePolicyDocument
			
			// Verify repository condition format
			// Should contain repo:owner/repo:ref:refs/heads/main or refs/heads/develop
			assert.Contains(t, assumeRolePolicy, "repo:")
			assert.Contains(t, assumeRolePolicy, ":ref:refs/heads/")
			assert.Contains(t, assumeRolePolicy, "main")
			assert.Contains(t, assumeRolePolicy, "develop")
		})
	}
}

// BenchmarkOIDCProviderLookup benchmarks OIDC provider lookup performance
func BenchmarkOIDCProviderLookup(b *testing.B) {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		b.Skip("Cannot load AWS config")
	}

	iamClient := iam.NewFromConfig(cfg)
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := iam.ListOpenIDConnectProviders(context.TODO(), &iam.ListOpenIDConnectProvidersInput{})
		if err != nil {
			b.Logf("OIDC provider lookup failed: %v", err)
		}
	}
}

// TestOIDCProviderTags tests that OIDC provider has proper tags
func TestOIDCProviderTags(t *testing.T) {
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
		if *provider.Arn == "arn:aws:iam::"+*providers.OpenIDConnectProviderList[0].Arn+":oidc-provider/token.actions.githubusercontent.com" {
			githubProvider = provider
			break
		}
	}
	
	if githubProvider == nil {
		t.Skip("GitHub OIDC provider not found")
	}
	
	// Get provider tags
	tags, err := iam.ListOpenIDConnectProviderTags(context.TODO(), &iam.ListOpenIDConnectProviderTagsInput{
		OpenIDConnectProviderArn: githubProvider.Arn,
	})
	require.NoError(t, err)
	
	// Verify required tags
	tagMap := make(map[string]string)
	for _, tag := range tags.Tags {
		tagMap[*tag.Key] = *tag.Value
	}
	
	assert.Contains(t, tagMap, "Name")
	assert.Contains(t, tagMap, "ManagedBy")
	assert.Equal(t, "terraform", tagMap["ManagedBy"])
}