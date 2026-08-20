#!/bin/bash

echo "🔍 Validating Terraform configuration..."

# Check Terraform format
echo "📝 Checking Terraform format..."
terraform fmt -check -recursive
if [ $? -eq 0 ]; then
    echo "✅ Terraform format is valid"
else
    echo "❌ Terraform format issues found"
    exit 1
fi

# Validate Terraform syntax
echo "🔧 Validating Terraform syntax..."
terraform validate
if [ $? -eq 0 ]; then
    echo "✅ Terraform syntax is valid"
else
    echo "❌ Terraform syntax errors found"
    exit 1
fi

# Check module structure
echo "📁 Checking module structure..."
if [ -d "../../modules/networking" ]; then
    echo "✅ Module directory exists"
else
    echo "❌ Module directory not found"
    exit 1
fi

# Check required files
echo "📄 Checking required files..."
required_files=("main.tf" "variables.tf" "outputs.tf" "versions.tf")
for file in "${required_files[@]}"; do
    if [ -f "../../modules/networking/$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file not found"
        exit 1
    fi
done

echo "🎉 All validation checks passed!"
echo ""
echo "📋 Summary of what will be created:"
echo "   • 1 VPC (10.0.0.0/16)"
echo "   • 1 Public Subnet (10.0.1.0/24)"
echo "   • 2 Private Subnets (10.0.2.0/24, 10.0.3.0/24)"
echo "   • 1 Internet Gateway"
echo "   • 1 Public Route Table"
echo "   • 2 Private Route Tables"
echo "   • Route Table Associations"
echo ""
echo "🚀 To deploy with real AWS credentials, run:"
echo "   terraform plan"
echo "   terraform apply"