# Cloud CLI Tools Setup Guide

This guide covers setting up and configuring cloud command-line interfaces (CLIs) for AWS, Google Cloud Platform, Microsoft Azure, and related tools.

## Overview

Cloud CLI tools enable you to manage cloud resources from the command line, automate deployments, and integrate cloud services into your development workflow. This guide covers:

- **AWS CLI v2**: Amazon Web Services command-line interface
- **Google Cloud CLI**: Google Cloud Platform SDK
- **Azure CLI**: Microsoft Azure command-line interface  
- **Terraform**: Infrastructure as Code across multiple cloud providers
- **Kubernetes Tools**: kubectl, Helm for container orchestration

## Prerequisites

Ensure you have the cross-platform tools installed:

```bash
# Install cloud tools
scripts/install-tools.sh cloud

# Or install all cloud tools including optional ones
scripts/install-tools.sh all
```

## AWS CLI Setup

### Installation Verification

```bash
# Verify AWS CLI installation
aws --version
# Should show: aws-cli/2.x.x Python/3.x.x...

# Check available commands
aws help
```

### Authentication Methods

#### 1. AWS SSO (Recommended for Organizations)

```bash
# Configure SSO
aws configure sso

# Follow prompts:
# SSO session name: my-company
# SSO start URL: https://my-company.awsapps.com/start
# SSO region: us-east-1
# Account ID: 123456789012
# Role name: PowerUserAccess
# CLI default client region: us-west-2
# CLI default output format: json

# Login to AWS SSO
aws sso login --profile my-company-profile
```

#### 2. IAM Access Keys

```bash
# Configure with access keys
aws configure

# Enter when prompted:
# AWS Access Key ID: AKIAIOSFODNN7EXAMPLE
# AWS Secret Access Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# Default region name: us-west-2
# Default output format: json
```

#### 3. IAM Roles (EC2/ECS/Lambda)

For applications running on AWS services:

```bash
# No additional configuration needed
# AWS CLI automatically uses instance/task/function role
aws sts get-caller-identity
```

### Configuration Management

#### Multiple Profiles

```bash
# Create additional profiles
aws configure --profile production
aws configure --profile staging

# Use specific profile
aws s3 ls --profile production

# Set default profile
export AWS_PROFILE=production
```

#### Configuration Files

Edit `~/.aws/config` and `~/.aws/credentials`:

```ini
# ~/.aws/config
[default]
region = us-west-2
output = json
cli_pager = 

[profile production]
region = us-east-1
output = table
role_arn = arn:aws:iam::123456789012:role/ProductionRole
source_profile = default

# ~/.aws/credentials
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

[production]
aws_access_key_id = AKIAI44QH8DHBEXAMPLE
aws_secret_access_key = je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY
```

### Common AWS CLI Usage

```bash
# List S3 buckets
aws s3 ls

# Describe EC2 instances
aws ec2 describe-instances

# Get current identity
aws sts get-caller-identity

# List IAM users
aws iam list-users

# CloudFormation operations
aws cloudformation list-stacks
aws cloudformation deploy --template-file template.yaml --stack-name my-stack
```

## Google Cloud CLI Setup

### Installation Verification

```bash
# Verify gcloud installation
gcloud version

# Initialize gcloud
gcloud init
```

### Authentication

#### 1. User Account Authentication

```bash
# Login with user account
gcloud auth login

# Set default project
gcloud config set project my-project-id

# Set default region and zone
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a
```

#### 2. Service Account Authentication

```bash
# Authenticate with service account key
gcloud auth activate-service-account --key-file=/path/to/service-account.json

# Set project for service account
gcloud config set project my-project-id
```

#### 3. Application Default Credentials

```bash
# Set up application default credentials
gcloud auth application-default login

# For service accounts
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
```

### Configuration Management

#### Multiple Configurations

```bash
# Create new configuration
gcloud config configurations create production

# Switch configurations
gcloud config configurations activate production

# List configurations
gcloud config configurations list

# Set properties for current configuration
gcloud config set project production-project-id
gcloud config set compute/region us-east1
```

#### Configuration Files

View configuration:

```bash
# Show current configuration
gcloud config list

# Show configuration file location
gcloud info --format="value(config.paths.global_config_dir)"
```

### Common gcloud Usage

```bash
# List projects
gcloud projects list

# Compute Engine
gcloud compute instances list
gcloud compute instances create my-instance

# Kubernetes Engine
gcloud container clusters list
gcloud container clusters get-credentials my-cluster

# Cloud Storage
gsutil ls
gsutil cp file.txt gs://my-bucket/

# Cloud Functions
gcloud functions list
gcloud functions deploy my-function --runtime python39
```

## Azure CLI Setup

### Installation Verification

```bash
# Verify Azure CLI installation
az version

# Get help
az help
```

### Authentication

#### 1. Interactive Login

```bash
# Login interactively
az login

# Login with specific tenant
az login --tenant my-tenant-id

# Set default subscription
az account set --subscription "My Subscription"
```

#### 2. Service Principal Authentication

```bash
# Login with service principal
az login --service-principal \
  --username http://my-app \
  --password my-password \
  --tenant my-tenant-id
```

#### 3. Managed Identity (Azure VMs)

```bash
# Login with managed identity
az login --identity

# Login with user-assigned managed identity
az login --identity --username /subscriptions/subscription-id/resourcegroups/myResourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/myID
```

### Configuration Management

```bash
# List accounts
az account list

# Show current account
az account show

# Set default subscription
az account set --subscription "subscription-name-or-id"

# Set default location
az configure --defaults location=westus2
az configure --defaults group=myResourceGroup
```

### Common Azure CLI Usage

```bash
# Resource groups
az group list
az group create --name myResourceGroup --location westus2

# Virtual machines
az vm list
az vm create --resource-group myResourceGroup --name myVM --image Ubuntu2204

# Kubernetes Service
az aks list
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster

# Storage
az storage account list
az storage blob list --account-name mystorageaccount --container-name mycontainer
```

## Terraform Setup

### Installation Verification

```bash
# Verify Terraform installation
terraform version

# Initialize Terraform in a directory
terraform init
```

### Provider Configuration

#### AWS Provider

```hcl
# main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.6"
}

provider "aws" {
  region = "us-west-2"
  
  # Optional: Use specific profile
  profile = "production"
  
  # Optional: Assume role
  assume_role {
    role_arn = "arn:aws:iam::123456789012:role/TerraformRole"
  }
}
```

#### Google Cloud Provider

```hcl
provider "google" {
  project = "my-project-id"
  region  = "us-central1"
  zone    = "us-central1-a"
  
  # Optional: Use service account key
  credentials = file("path/to/service-account.json")
}
```

#### Azure Provider

```hcl
provider "azurerm" {
  features {}
  
  # Optional: Use service principal
  client_id       = "client-id"
  client_secret   = "client-secret"
  tenant_id       = "tenant-id"
  subscription_id = "subscription-id"
}
```

### Backend Configuration

#### S3 Backend (AWS)

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

#### Google Cloud Storage Backend

```hcl
terraform {
  backend "gcs" {
    bucket = "my-terraform-state"
    prefix = "infrastructure"
  }
}
```

#### Azure Storage Backend

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "terraformstate"
    container_name       = "terraform-state"
    key                  = "infrastructure.terraform.tfstate"
  }
}
```

### Common Terraform Workflow

```bash
# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# Show current state
terraform show

# Destroy infrastructure
terraform destroy

# Validate configuration
terraform validate

# Format code
terraform fmt
```

## Kubernetes Tools

### kubectl Setup

#### Installation Verification

```bash
# Verify kubectl installation
kubectl version --client

# Get cluster information
kubectl cluster-info
```

#### Configuration

```bash
# View current context
kubectl config current-context

# List available contexts
kubectl config get-contexts

# Switch context
kubectl config use-context my-cluster

# Set default namespace
kubectl config set-context --current --namespace=my-namespace
```

#### Common kubectl Commands

```bash
# Get resources
kubectl get pods
kubectl get services
kubectl get deployments

# Describe resources
kubectl describe pod my-pod

# Apply manifests
kubectl apply -f deployment.yaml

# Port forwarding
kubectl port-forward service/my-service 8080:80

# Logs
kubectl logs my-pod
kubectl logs -f deployment/my-deployment

# Execute commands in pods
kubectl exec -it my-pod -- /bin/bash
```

### Helm Setup

#### Installation Verification

```bash
# Verify Helm installation
helm version

# Add repositories
helm repo add stable https://charts.helm.sh/stable
helm repo add bitnami https://charts.bitnami.com/bitnami

# Update repositories
helm repo update
```

#### Common Helm Commands

```bash
# Search charts
helm search repo nginx

# Install chart
helm install my-release bitnami/nginx

# List releases
helm list

# Upgrade release
helm upgrade my-release bitnami/nginx

# Uninstall release
helm uninstall my-release

# Show values
helm show values bitnami/nginx
```

## Multi-Cloud Workflow

### Environment Isolation

```bash
# Use different profiles/configurations per environment
export AWS_PROFILE=production
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/prod-sa.json"
az account set --subscription "Production Subscription"

# Terraform workspaces
terraform workspace new production
terraform workspace select production
```

### Infrastructure as Code Best Practices

```hcl
# modules/networking/main.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cloud_provider" {
  description = "Cloud provider (aws, gcp, azure)"
  type        = string
}

# Use conditional logic for multi-cloud
resource "aws_vpc" "main" {
  count = var.cloud_provider == "aws" ? 1 : 0
  # AWS VPC configuration
}

resource "google_compute_network" "main" {
  count = var.cloud_provider == "gcp" ? 1 : 0
  # GCP VPC configuration
}

resource "azurerm_virtual_network" "main" {
  count = var.cloud_provider == "azure" ? 1 : 0
  # Azure VNet configuration
}
```

### CI/CD Integration

#### GitHub Actions

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-west-2
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: 1.7.4
    
    - name: Terraform Init
      run: terraform init
    
    - name: Terraform Plan
      run: terraform plan
    
    - name: Terraform Apply
      run: terraform apply -auto-approve
```

## Security Best Practices

### Credential Management

1. **Use IAM Roles**: Prefer IAM roles over long-term access keys
2. **Rotate Keys**: Regularly rotate access keys and passwords
3. **Least Privilege**: Grant minimum necessary permissions
4. **MFA**: Enable multi-factor authentication where possible

### Tool-Specific Security

#### AWS

```bash
# Enable MFA for CLI operations
aws configure set mfa_serial arn:aws:iam::123456789012:mfa/username

# Use temporary credentials with aws-vault
aws-vault exec production -- aws s3 ls
```

#### Google Cloud

```bash
# Use service account impersonation
gcloud config set auth/impersonate_service_account sa@project.iam.gserviceaccount.com

# Enable audit logging
gcloud logging sinks create my-sink bigquery.googleapis.com/projects/my-project/datasets/audit_logs
```

#### Azure

```bash
# Use managed identities when possible
az login --identity

# Enable conditional access policies
az ad conditional-access policy create --display-name "Require MFA for CLI"
```

### Secrets Management

```bash
# Use cloud-native secret managers
aws secretsmanager get-secret-value --secret-id my-secret
gcloud secrets versions access latest --secret my-secret
az keyvault secret show --vault-name my-vault --name my-secret

# Never store secrets in code or configuration files
# Use environment variables or secret management tools
```

## Troubleshooting

### Common Issues

#### AWS CLI

```bash
# Debug AWS CLI issues
aws sts get-caller-identity --debug

# Check credentials
aws configure list

# Verify permissions
aws iam get-user
aws iam list-attached-user-policies --user-name my-user
```

#### Google Cloud CLI

```bash
# Debug gcloud issues
gcloud info --log-http

# Check authentication
gcloud auth list

# Verify project permissions
gcloud projects get-iam-policy my-project-id
```

#### Azure CLI

```bash
# Debug Azure CLI issues
az account show --debug

# Check authentication
az account list

# Verify permissions
az role assignment list --assignee user@domain.com
```

#### Terraform

```bash
# Debug Terraform issues
export TF_LOG=DEBUG
terraform plan

# Refresh state
terraform refresh

# Import existing resources
terraform import aws_instance.example i-1234567890abcdef0
```

### Network Issues

```bash
# Test connectivity
curl -I https://aws.amazon.com
curl -I https://cloud.google.com
curl -I https://management.azure.com

# Check proxy settings
echo $HTTP_PROXY
echo $HTTPS_PROXY

# Bypass proxy for cloud endpoints
export NO_PROXY="amazonaws.com,googleapis.com,microsoftonline.com"
```

## Advanced Configuration

### Shell Integration

Add to your shell configuration (`~/.zshrc` or `~/.bashrc`):

```bash
# AWS CLI auto-completion
complete -C aws_completer aws

# Google Cloud CLI
source "$(gcloud info --format='value(installation.sdk_root)')/path.bash.inc"
source "$(gcloud info --format='value(installation.sdk_root)')/completion.bash.inc"

# Azure CLI auto-completion
source /etc/bash_completion.d/azure-cli

# Terraform auto-completion
complete -C /usr/local/bin/terraform terraform

# kubectl auto-completion
source <(kubectl completion zsh)

# Aliases
alias k=kubectl
alias tf=terraform
alias g=gcloud
```

### Tool Configuration Templates

Create configuration templates for consistent setup across environments:

```yaml
# .cloud-config.yaml
aws:
  default_region: us-west-2
  default_output: json
  profiles:
    - name: production
      role_arn: arn:aws:iam::123456789012:role/ProductionRole
    - name: staging
      role_arn: arn:aws:iam::123456789012:role/StagingRole

gcp:
  default_project: my-project-id
  default_region: us-central1
  configurations:
    - name: production
      project: prod-project-id
    - name: staging
      project: stage-project-id

azure:
  default_subscription: production-subscription-id
  default_location: westus2
```

## See Also

- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)
- [Google Cloud CLI Documentation](https://cloud.google.com/sdk/docs)
- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- [kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/)
- [Helm Documentation](https://helm.sh/docs/)
- [Cross-Platform Tools](tools.md)
- [Version Management](version-management.md) 