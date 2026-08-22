package ci_cd

import (
	"context"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestS3StateBucket tests that S3 bucket for state storage is properly configured
func TestS3StateBucket(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	cfg, err := config.LoadDefaultConfig(context.TODO())
	require.NoError(t, err)

	s3Client := s3.NewFromConfig(cfg)
	
	// Test bucket names for each environment
	environments := []string{"dev", "staging", "prod"}
	
	for _, env := range environments {
		t.Run(env, func(t *testing.T) {
			// List buckets to find the state bucket
			buckets, err := s3Client.ListBuckets(context.TODO(), &s3.ListBucketsInput{})
			require.NoError(t, err)
			
			var stateBucket string
			for _, bucket := range buckets.Buckets {
				bucketName := *bucket.Name
				if len(bucketName) > len("terraform-state-"+env) && 
				   bucketName[:len("terraform-state-"+env)] == "terraform-state-"+env {
					stateBucket = bucketName
					break
				}
			}
			
			if stateBucket == "" {
				t.Skip("State bucket not found for environment: " + env)
			}
			
			// Test bucket versioning
			versioning, err := s3Client.GetBucketVersioning(context.TODO(), &s3.GetBucketVersioningInput{
				Bucket: aws.String(stateBucket),
			})
			require.NoError(t, err)
			assert.Equal(t, "Enabled", versioning.Status)
			
			// Test bucket encryption
			encryption, err := s3Client.GetBucketEncryption(context.TODO(), &s3.GetBucketEncryptionInput{
				Bucket: aws.String(stateBucket),
			})
			require.NoError(t, err)
			assert.NotNil(t, encryption.ServerSideEncryptionConfiguration)
			
			// Test public access block
			publicAccess, err := s3Client.GetPublicAccessBlock(context.TODO(), &s3.GetPublicAccessBlockInput{
				Bucket: aws.String(stateBucket),
			})
			require.NoError(t, err)
			
			assert.True(t, publicAccess.BlockPublicAcls)
			assert.True(t, publicAccess.BlockPublicPolicy)
			assert.True(t, publicAccess.IgnorePublicAcls)
			assert.True(t, publicAccess.RestrictPublicBuckets)
		})
	}
}

// TestDynamoDBLockTable tests that DynamoDB table for state locking is properly configured
func TestDynamoDBLockTable(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	cfg, err := config.LoadDefaultConfig(context.TODO())
	require.NoError(t, err)

	dynamoClient := dynamodb.NewFromConfig(cfg)
	
	// Test table names for each environment
	environments := []string{"dev", "staging", "prod"}
	
	for _, env := range environments {
		t.Run(env, func(t *testing.T) {
			tableName := "terraform-locks-" + env
			
			// Get table description
			table, err := dynamoClient.DescribeTable(context.TODO(), &dynamodb.DescribeTableInput{
				TableName: aws.String(tableName),
			})
			
			if err != nil {
				t.Skip("Lock table not found for environment: " + env)
			}
			
			// Verify table attributes
			assert.Equal(t, tableName, *table.Table.TableName)
			assert.Equal(t, "PAY_PER_REQUEST", table.Table.BillingModeSummary.BillingMode)
			
			// Verify hash key
			var hashKey *dynamodb.AttributeDefinition
			for _, attr := range table.Table.AttributeDefinitions {
				if *attr.AttributeName == "LockID" {
					hashKey = attr
					break
				}
			}
			require.NotNil(t, hashKey)
			assert.Equal(t, "S", hashKey.AttributeType)
			
			// Verify key schema
			var keySchema *dynamodb.KeySchemaElement
			for _, key := range table.Table.KeySchema {
				if *key.KeyType == "HASH" {
					keySchema = key
					break
				}
			}
			require.NotNil(t, keySchema)
			assert.Equal(t, "LockID", *keySchema.AttributeName)
		})
	}
}

// TestStateLocking tests that state locking mechanism works
func TestStateLocking(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	// This test would require running actual Terraform commands
	// For now, we'll test the DynamoDB table accessibility
	
	cfg, err := config.LoadDefaultConfig(context.TODO())
	require.NoError(t, err)

	dynamoClient := dynamodb.NewFromConfig(cfg)
	
	tableName := "terraform-locks-dev"
	
	// Test writing a lock item
	lockID := "test-lock-" + string(time.Now().Unix())
	
	_, err = dynamoClient.PutItem(context.TODO(), &dynamodb.PutItemInput{
		TableName: aws.String(tableName),
		Item: map[string]dynamodb.AttributeValue{
			"LockID": &dynamodb.AttributeValueMemberS{Value: lockID},
			"Info":   &dynamodb.AttributeValueMemberS{Value: "test lock info"},
		},
	})
	
	if err != nil {
		t.Skip("Cannot write to lock table: " + err.Error())
	}
	
	// Test reading the lock item
	getItem, err := dynamoClient.GetItem(context.TODO(), &dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]dynamodb.AttributeValue{
			"LockID": &dynamodb.AttributeValueMemberS{Value: lockID},
		},
	})
	require.NoError(t, err)
	assert.Contains(t, getItem.Item, "LockID")
	
	// Test deleting the lock item
	_, err = dynamoClient.DeleteItem(context.TODO(), &dynamodb.DeleteItemInput{
		TableName: aws.String(tableName),
		Key: map[string]dynamodb.AttributeValue{
			"LockID": &dynamodb.AttributeValueMemberS{Value: lockID},
		},
	})
	require.NoError(t, err)
	
	// Verify item is deleted
	getItem, err = dynamoClient.GetItem(context.TODO(), &dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]dynamodb.AttributeValue{
			"LockID": &dynamodb.AttributeValueMemberS{Value: lockID},
		},
	})
	require.NoError(t, err)
	assert.Empty(t, getItem.Item)
}

// TestStateEncryption tests that state files are encrypted
func TestStateEncryption(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	cfg, err := config.LoadDefaultConfig(context.TODO())
	require.NoError(t, err)

	s3Client := s3.NewFromConfig(cfg)
	
	// Find state bucket
	buckets, err := s3Client.ListBuckets(context.TODO(), &s3.ListBucketsInput{})
	require.NoError(t, err)
	
	var stateBucket string
	for _, bucket := range buckets.Buckets {
		bucketName := *bucket.Name
		if len(bucketName) > len("terraform-state-dev") && 
		   bucketName[:len("terraform-state-dev")] == "terraform-state-dev" {
			stateBucket = bucketName
			break
		}
	}
	
	if stateBucket == "" {
		t.Skip("State bucket not found")
	}
	
	// Test bucket encryption
	encryption, err := s3Client.GetBucketEncryption(context.TODO(), &s3.GetBucketEncryptionInput{
		Bucket: aws.String(stateBucket),
	})
	require.NoError(t, err)
	
	// Verify AES256 encryption
	assert.Len(t, encryption.ServerSideEncryptionConfiguration.Rules, 1)
	rule := encryption.ServerSideEncryptionConfiguration.Rules[0]
	assert.NotNil(t, rule.ApplyServerSideEncryptionByDefault)
	assert.Equal(t, "AES256", *rule.ApplyServerSideEncryptionByDefault.SSEAlgorithm)
}

// TestStateVersioning tests that state versioning is enabled
func TestStateVersioning(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	cfg, err := config.LoadDefaultConfig(context.TODO())
	require.NoError(t, err)

	s3Client := s3.NewFromConfig(cfg)
	
	// Find state bucket
	buckets, err := s3Client.ListBuckets(context.TODO(), &s3.ListBucketsInput{})
	require.NoError(t, err)
	
	var stateBucket string
	for _, bucket := range buckets.Buckets {
		bucketName := *bucket.Name
		if len(bucketName) > len("terraform-state-dev") && 
		   bucketName[:len("terraform-state-dev")] == "terraform-state-dev" {
			stateBucket = bucketName
			break
		}
	}
	
	if stateBucket == "" {
		t.Skip("State bucket not found")
	}
	
	// Test versioning configuration
	versioning, err := s3Client.GetBucketVersioning(context.TODO(), &s3.GetBucketVersioningInput{
		Bucket: aws.String(stateBucket),
	})
	require.NoError(t, err)
	assert.Equal(t, "Enabled", versioning.Status)
	assert.Equal(t, true, versioning.MfaDelete)
}

// BenchmarkDynamoDBLock benchmarks DynamoDB lock operations
func BenchmarkDynamoDBLock(b *testing.B) {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		b.Skip("Cannot load AWS config")
	}

	dynamoClient := dynamodb.NewFromConfig(cfg)
	tableName := "terraform-locks-dev"
	
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		lockID := "benchmark-lock-" + string(rune(i))
		
		// Put lock
		_, err := dynamoClient.PutItem(context.TODO(), &dynamodb.PutItemInput{
			TableName: aws.String(tableName),
			Item: map[string]dynamodb.AttributeValue{
				"LockID": &dynamodb.AttributeValueMemberS{Value: lockID},
				"Info":   &dynamodb.AttributeValueMemberS{Value: "benchmark"},
			},
		})
		if err != nil {
			b.Logf("PutItem failed: %v", err)
		}
		
		// Get lock
		_, err = dynamoClient.GetItem(context.TODO(), &dynamodb.GetItemInput{
			TableName: aws.String(tableName),
			Key: map[string]dynamodb.AttributeValue{
				"LockID": &dynamodb.AttributeValueMemberS{Value: lockID},
			},
		})
		if err != nil {
			b.Logf("GetItem failed: %v", err)
		}
		
		// Delete lock
		_, err = dynamoClient.DeleteItem(context.TODO(), &dynamodb.DeleteItemInput{
			TableName: aws.String(tableName),
			Key: map[string]dynamodb.AttributeValue{
				"LockID": &dynamodb.AttributeValueMemberS{Value: lockID},
			},
		})
		if err != nil {
			b.Logf("DeleteItem failed: %v", err)
		}
	}
}