# Infrastructure as Code (IDP)

AWS infrastructure managed with Terraform.

## Structure

```
infra/
├── backend/     # Terraform state backend (S3 + DynamoDB)
├── entry/       # Main infrastructure entry point
└── modules/     # Reusable Terraform modules
    ├── eks/     # EKS cluster configuration
    └── vpc/     # VPC networking
```

## Prerequisites

- Terraform >= 1.14.3
- AWS CLI configured
- AWS IAM role for deployments

## Deployment

### Bootstrap Backend (Development)

Run the GitHub Actions workflow:

```bash
gh workflow run "Bootstrap Backend Development" --ref main
```

Or manually:

```bash
cd infra/backend
terraform init
terraform plan
terraform apply
```

### Deploy Infrastructure

```bash
cd infra/entry
terraform init
terraform plan
terraform apply
```

## Environment

- **Region:** us-west-2
- **AWS Account:** 935743309409

