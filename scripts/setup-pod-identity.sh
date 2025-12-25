#!/bin/bash
set -e

# Configuration
CLUSTER_NAME="${1:-YOUR_CLUSTER_NAME}"
ECR_ACCOUNT_ID="864992049050"
AWS_ACCOUNT_ID="935743309409"
REGION="us-west-2"
ROLE_NAME="${CLUSTER_NAME}-ecr-pull-role"

echo "Creating Pod Identity for cluster: $CLUSTER_NAME"

# Create IAM role
echo "Creating IAM role..."
aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "pods.eks.amazonaws.com"},
      "Action": ["sts:AssumeRole", "sts:TagSession"]
    }]
  }' 2>/dev/null || echo "Role already exists"

# Attach ECR policy
echo "Attaching ECR policy..."
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "ecr-pull-policy" \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Effect\": \"Allow\",
        \"Action\": [\"ecr:GetAuthorizationToken\"],
        \"Resource\": \"*\"
      },
      {
        \"Effect\": \"Allow\",
        \"Action\": [
          \"ecr:BatchCheckLayerAvailability\",
          \"ecr:GetDownloadUrlForLayer\",
          \"ecr:BatchGetImage\"
        ],
        \"Resource\": \"arn:aws:ecr:*:${ECR_ACCOUNT_ID}:repository/*\"
      }
    ]
  }"

ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"

# Create Pod Identity associations
echo "Creating Pod Identity association for time-service..."
aws eks create-pod-identity-association \
  --cluster-name "$CLUSTER_NAME" \
  --namespace "time-service-dev" \
  --service-account "time-service" \
  --role-arn "$ROLE_ARN" \
  --region "$REGION" 2>/dev/null || echo "Association already exists"

echo "Creating Pod Identity association for version-service..."
aws eks create-pod-identity-association \
  --cluster-name "$CLUSTER_NAME" \
  --namespace "version-service-dev" \
  --service-account "version-service" \
  --role-arn "$ROLE_ARN" \
  --region "$REGION" 2>/dev/null || echo "Association already exists"

echo "Done! Now restart your deployments:"
echo "  kubectl rollout restart deployment/time-service -n time-service-dev"
