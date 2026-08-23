# SDD-Infra Test Suite

This test suite provides **fast, focused validation** that complements the comprehensive integration testing done in GitHub Actions workflows.

## Philosophy

- **Fast feedback**: Run locally during development
- **No duplication**: Don't test what GitHub workflows already validate
- **Prevention over detection**: Catch issues before they reach CI/CD

## Test Categories

### 1. Format & Validation (`format_test.go`)
- Terraform formatting compliance
- Configuration syntax validation
- Runs in seconds, no AWS credentials needed

### 2. Security & Compliance (`security_test.go`)
- Security group rule validation
- IAM least-privilege checks
- Requires AWS credentials (uses real resources)

### 3. Cost Guardrails (`cost_test.go`)
- Detects expensive resource types
- Flags oversized volumes/instances
- Uses Terraform plan output (no AWS calls)

## Running Tests

### Quick Format Check (No AWS needed)
```bash
cd tests
go test -v ./validation -run TestTerraformFormat
```

### Full Security & Cost Validation (AWS credentials needed)
```bash
cd tests
AWS_PROFILE=your-profile go test -v ./validation
```

### Skip AWS-Dependent Tests
```bash
cd tests
go test -short -v ./validation
```

## What's NOT Tested Here

These are intentionally left to GitHub Actions workflows:
- ✅ Full Terraform apply/destroy
- ✅ OIDC authentication
- ✅ State locking
- ✅ Cross-environment deployments
- ✅ End-to-end infrastructure provisioning

## Integration with Development Workflow

1. **Before commit**: Run format tests
2. **Before PR**: Run full test suite
3. **CI/CD**: GitHub workflows provide comprehensive testing

## Adding New Tests

Follow these principles:
- Test should run in < 30 seconds
- Focus on validation, not integration
- Don't duplicate workflow testing
- Use real AWS resources only when necessary