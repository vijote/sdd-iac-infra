# `tests/validation/` — Go Validation Tests

This directory contains **Go test files** (`_test.go`) that provide fast, local validation of Terraform code. They complement (but do not replace) the full integration testing done via GitHub Actions workflows.

## Test Files

| File | Purpose | AWS Credentials Needed? |
|------|---------|------------------------|
| [`format_test.go`](format_test.go) | Validates Terraform formatting (`terraform fmt`) and configuration syntax (`terraform validate`) | ❌ No |
| [`security_test.go`](security_test.go) | Checks security group rules and IAM least-privilege configurations against real AWS resources | ✅ Yes |
| [`cost_test.go`](cost_test.go) | Detects expensive resource types and oversized instances/volumes using Terraform plan output | ❌ No (uses plan output) |

## Running Tests

```bash
# Format check only (no AWS needed)
cd tests
go test -v ./validation -run TestTerraformFormat

# Full test suite (requires AWS credentials)
cd tests
AWS_PROFILE=your-profile go test -v ./validation

# Skip AWS-dependent tests
cd tests
go test -short -v ./validation
```

## Philosophy

- **Fast feedback**: All tests should complete in under 30 seconds.
- **No duplication**: These tests do NOT replicate what GitHub Actions already validates (full `terraform apply`, OIDC auth, state locking, end-to-end provisioning).
- **Prevention over detection**: Catch formatting issues and security misconfigurations *before* they reach CI/CD.

## When to Run

1. **Before committing**: Run format tests
2. **Before opening a PR**: Run the full test suite
3. **In CI**: GitHub workflows handle comprehensive integration testing
