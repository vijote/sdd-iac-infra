package test

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestNetworkConnectivity validates network connectivity patterns (SC-004)
func TestNetworkConnectivity(t *testing.T) {
	t.Parallel()

	// Generate a unique environment name
	uniqueEnv := fmt.Sprintf("sdd-test-%s", random.UniqueId())

	// Terraform options
	terraformOptions := &terraform.Options{
		TerraformDir: "../../src/terraform/examples/basic",
		VarFiles:     []string{"../../src/terraform/environments/aws/terraform.tfvars"},
		Vars: map[string]interface{}{
			"environment":  uniqueEnv,
			"project_name": "sdd-connectivity-test",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": "us-east-1",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Get resource IDs from outputs
	vpcID := terraform.Output(t, terraformOptions, "vpc_id")
	publicSubnetID := terraform.Output(t, terraformOptions, "public_subnet_id")
	privateSubnetIDs := terraform.OutputList(t, terraformOptions, "public_subnet_id")
	internetGatewayID := terraform.Output(t, terraformOptions, "internet_gateway_id")

	awsRegion := "us-east-1"

	// Test VPC Configuration
	t.Run("VPCChecks", func(t *testing.T) {
		vpc := aws.GetVpcById(t, vpcID, awsRegion)
		
		// Validate DNS settings are enabled
		assert.True(t, *vpc.EnableDnsHostnames, "DNS hostnames should be enabled in VPC")
		assert.True(t, *vpc.EnableDnsSupport, "DNS support should be enabled in VPC")
		
		// Validate CIDR block
		expectedCIDR := "10.0.0.0/16"
		assert.Equal(t, expectedCIDR, *vpc.CidrBlock, fmt.Sprintf("VPC should have CIDR %s", expectedCIDR))
		
		t.Logf("VPC %s validated: DNS enabled, CIDR %s", vpcID, *vpc.CidrBlock)
	})

	// Test Subnet Configuration
	t.Run("SubnetChecks", func(t *testing.T) {
		// Test public subnet
		publicSubnet := aws.GetSubnetById(t, publicSubnetID, awsRegion)
		assert.Equal(t, vpcID, *publicSubnet.VpcId, "Public subnet should belong to the VPC")
		assert.True(t, *publicSubnet.MapPublicIpOnLaunch, "Public subnet should auto-assign public IPs")
		
		// Test private subnets
		assert.Len(t, privateSubnetIDs, 2, "Should have exactly 2 private subnets")
		
		for i, subnetID := range privateSubnetIDs {
			privateSubnet := aws.GetSubnetById(t, subnetID, awsRegion)
			assert.Equal(t, vpcID, *privateSubnet.VpcId, fmt.Sprintf("Private subnet %d should belong to the VPC", i+1))
			assert.False(t, *privateSubnet.MapPublicIpOnLaunch, fmt.Sprintf("Private subnet %d should not auto-assign public IPs", i+1))
		}
		
		t.Logf("Subnets validated: 1 public, 2 private with correct configurations")
	})

	// Test Internet Gateway Configuration
	t.Run("InternetGatewayChecks", func(t *testing.T) {
		igw := aws.GetInternetGatewayById(t, internetGatewayID, awsRegion)
		
		// Validate IGW is attached to VPC
		assert.Len(t, igw.Attachments, 1, "Internet gateway should have exactly one attachment")
		assert.Equal(t, vpcID, *igw.Attachments[0].VpcId, "Internet gateway should be attached to the VPC")
		
		t.Logf("Internet gateway %s validated and attached to VPC", internetGatewayID)
	})

	// Test Route Tables
	t.Run("RouteTableChecks", func(t *testing.T) {
		// Get route tables for the VPC
		routeTables := aws.GetRouteTablesForVpc(t, vpcID, awsRegion)
		
		// Should have at least 2 route tables (1 public, 1+ private)
		assert.GreaterOrEqual(t, len(routeTables), 2, "Should have at least 2 route tables")
		
		var publicRouteTable *aws.RouteTable
		var privateRouteTables []*aws.RouteTable
		
		for _, rt := range routeTables {
			// Check if this is the public route table (has route to IGW)
			hasIGWRoute := false
			for _, route := range rt.Routes {
				if route.GatewayId != nil && *route.GatewayId == internetGatewayID {
					hasIGWRoute = true
					break
				}
			}
			
			if hasIGWRoute {
				publicRouteTable = rt
			} else {
				privateRouteTables = append(privateRouteTables, rt)
			}
		}
		
		// Validate public route table
		assert.NotNil(t, publicRouteTable, "Should have a public route table with IGW route")
		
		// Validate public route table has correct routes
		hasLocalRoute := false
		hasIGWRoute := false
		for _, route := range publicRouteTable.Routes {
			if route.DestinationCidrBlock != nil && *route.DestinationCidrBlock == "10.0.0.0/16" {
				hasLocalRoute = true
			}
			if route.GatewayId != nil && *route.GatewayId == internetGatewayID {
				hasIGWRoute = true
			}
		}
		assert.True(t, hasLocalRoute, "Public route table should have local route")
		assert.True(t, hasIGWRoute, "Public route table should have IGW route for 0.0.0.0/0")
		
		// Validate private route tables
		assert.GreaterOrEqual(t, len(privateRouteTables), 1, "Should have at least 1 private route table")
		for _, rt := range privateRouteTables {
			// Private route tables should only have local routes
			hasOnlyLocalRoutes := true
			for _, route := range rt.Routes {
				if route.DestinationCidrBlock != nil && *route.DestinationCidrBlock != "10.0.0.0/16" {
					hasOnlyLocalRoutes = false
					break
				}
			}
			assert.True(t, hasOnlyLocalRoutes, "Private route table should only have local routes")
		}
		
		t.Logf("Route tables validated: %d total, 1 public with IGW route, %d private with local only", 
			len(routeTables), len(privateRouteTables))
	})

	// Test Subnet-Route Table Associations
	t.Run("SubnetAssociations", func(t *testing.T) {
		// Get public subnet and verify it's associated with public route table
		publicSubnet := aws.GetSubnetById(t, publicSubnetID, awsRegion)
		publicRTAssocs := aws.GetRouteTablesForSubnet(t, publicSubnetID, awsRegion)
		
		// Public subnet should be associated with a route table that has IGW route
		publicHasIGWRoute := false
		for _, rt := range publicRTAssocs {
			for _, route := range rt.Routes {
				if route.GatewayId != nil && *route.GatewayId == internetGatewayID {
					publicHasIGWRoute = true
					break
				}
			}
		}
		assert.True(t, publicHasIGWRoute, "Public subnet should be associated with route table having IGW route")
		
		// Private subnets should be associated with route tables without IGW routes
		for _, subnetID := range privateSubnetIDs {
			privateRTAssocs := aws.GetRouteTablesForSubnet(t, subnetID, awsRegion)
			privateHasIGWRoute := false
			for _, rt := range privateRTAssocs {
				for _, route := range rt.Routes {
					if route.GatewayId != nil && *route.GatewayId == internetGatewayID {
						privateHasIGWRoute = true
						break
					}
				}
			}
			assert.False(t, privateHasIGWRoute, fmt.Sprintf("Private subnet %s should not be associated with route table having IGW route", subnetID))
		}
		
		t.Logf("Subnet-route table associations validated correctly")
	})
}

// TestCrossProviderConnectivity validates connectivity patterns work across providers
func TestCrossProviderConnectivity(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name       string
		varFile    string
		region     string
		expectedVpcCIDR string
	}{
		{
			name:       "AWS",
			varFile:    "../../src/terraform/environments/aws/terraform.tfvars",
			region:     "us-east-1",
			expectedVpcCIDR: "10.0.0.0/16",
		},
		{
			name:       "MiniStack",
			varFile:    "../../src/terraform/environments/ministack/terraform.tfvars",
			region:     "local",
			expectedVpcCIDR: "172.18.0.0/16",
		},
	}

	for _, tc := range testCases {
		tc := tc // capture range variable
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			uniqueEnv := fmt.Sprintf("sdd-test-%s-%s", tc.name, random.UniqueId())

			terraformOptions := &terraform.Options{
				TerraformDir: "../../src/terraform/examples/basic",
				VarFiles:     []string{tc.varFile},
				Vars: map[string]interface{}{
					"environment":  uniqueEnv,
					"project_name": fmt.Sprintf("sdd-connectivity-test-%s", tc.name),
				},
				EnvVars: map[string]string{
					"AWS_DEFAULT_REGION": tc.region,
				},
				NoColor: true,
			}

			defer terraform.Destroy(t, terraformOptions)
			terraform.InitAndApply(t, terraformOptions)

			// Get VPC ID and validate
			vpcID := terraform.Output(t, terraformOptions, "vpc_id")
			assert.NotEmpty(t, vpcID, "VPC ID should be output")

			// For AWS, we can validate the actual VPC
			if tc.region != "local" {
				vpc := aws.GetVpcById(t, vpcID, tc.region)
				assert.Equal(t, tc.expectedVpcCIDR, *vpc.CidrBlock, 
					fmt.Sprintf("%s VPC should have CIDR %s", tc.name, tc.expectedVpcCIDR))
			}

			// Validate subnet outputs exist
			publicSubnetID := terraform.Output(t, terraformOptions, "public_subnet_id")
			assert.NotEmpty(t, publicSubnetID, "Public subnet ID should be output")

			privateSubnetIDs := terraform.OutputList(t, terraformOptions, "private_subnet_ids")
			assert.Len(t, privateSubnetIDs, 2, "Should have exactly 2 private subnets")

			t.Logf("%s connectivity validated: VPC and subnets created successfully", tc.name)
		})
	}
}

// TestNetworkLatency validates network performance characteristics
func TestNetworkLatency(t *testing.T) {
	t.Parallel()

	// This test would typically launch test instances and measure latency
	// For now, we'll validate the network configuration that supports low latency
	
	uniqueEnv := fmt.Sprintf("sdd-test-%s", random.UniqueId())

	terraformOptions := &terraform.Options{
		TerraformDir: "../../src/terraform/examples/basic",
		VarFiles:     []string{"../../src/terraform/environments/aws/terraform.tfvars"},
		Vars: map[string]interface{}{
			"environment":  uniqueEnv,
			"project_name": "sdd-latency-test",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": "us-east-1",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Get subnet IDs
	publicSubnetID := terraform.Output(t, terraformOptions, "public_subnet_id")
	privateSubnetIDs := terraform.OutputList(t, terraformOptions, "private_subnet_ids")
	awsRegion := "us-east-1"

	// Validate subnets are in the same AZ (for low latency)
	publicSubnet := aws.GetSubnetById(t, publicSubnetID, awsRegion)
	publicAZ := *publicSubnet.AvailabilityZone

	for i, subnetID := range privateSubnetIDs {
		privateSubnet := aws.GetSubnetById(t, subnetID, awsRegion)
		privateAZ := *privateSubnet.AvailabilityZone
		
		// In a single AZ deployment, all subnets should be in the same AZ
		// This minimizes inter-subnet latency
		assert.Equal(t, publicAZ, privateAZ, 
			fmt.Sprintf("Private subnet %d should be in same AZ as public subnet for minimal latency", i+1))
	}

	t.Logf("Network latency configuration validated: all subnets in AZ %s for minimal latency", publicAZ)
}