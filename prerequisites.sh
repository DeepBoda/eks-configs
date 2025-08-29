#!/bin/bash

# Prerequisites for Sandee EKS Infrastructure Deployment
# Run these commands before executing deploy-ultimate-sandee.sh

set -e

echo "🔧 EKS Infrastructure Prerequisites Setup"
echo "========================================"

# 1. Verify AWS CLI and kubectl
echo "1. Verifying AWS CLI and kubectl..."
aws --version || { echo "❌ AWS CLI not found. Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"; exit 1; }
kubectl version --client || { echo "❌ kubectl not found. Install: https://kubernetes.io/docs/tasks/tools/"; exit 1; }

# 2. Verify EKS cluster connection
echo "2. Verifying EKS cluster connection..."
aws eks update-kubeconfig --region us-east-1 --name sandee
kubectl get nodes || { echo "❌ Cannot connect to EKS cluster 'sandee'"; exit 1; }

# 3. Install/Update Helm
echo "3. Installing/Updating Helm..."
if ! command -v helm &> /dev/null; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo "✅ Helm already installed: $(helm version --short)"
fi

# 4. Verify IAM Roles exist
echo "4. Verifying IAM Roles..."
aws iam get-role --role-name AmazonEKS_EBS_CSI_DriverRole || echo "⚠️  Create EBS CSI Driver Role"
aws iam get-role --role-name AmazonEKSLoadBalancerControllerRole || echo "⚠️  Create Load Balancer Controller Role"
aws iam get-role --role-name AmazonEKSClusterAutoscalerRole || echo "⚠️  Create Cluster Autoscaler Role"

# 5. Check EBS CSI Driver addon
echo "5. Checking EBS CSI Driver addon..."
aws eks describe-addon --cluster-name sandee --addon-name aws-ebs-csi-driver --region us-east-1 || {
    echo "⚠️  Installing EBS CSI Driver addon..."
    aws eks create-addon --cluster-name sandee --addon-name aws-ebs-csi-driver --region us-east-1 \
        --service-account-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/AmazonEKS_EBS_CSI_DriverRole
}

# 6. Verify VPC and Subnets
echo "6. Verifying VPC configuration..."
aws ec2 describe-vpcs --vpc-ids vpc-02f40ee7a414a4512 --region us-east-1 || echo "❌ VPC vpc-02f40ee7a414a4512 not found"

# 7. Check ACM Certificate
echo "7. Checking ACM Certificate..."
aws acm list-certificates --region us-east-1 --query 'CertificateSummaryList[?DomainName==`*.sandee.com`]' || echo "⚠️  Ensure *.sandee.com certificate exists"

# 8. Verify Node Groups
echo "8. Checking Node Groups..."
aws eks describe-nodegroup --cluster-name sandee --nodegroup-name $(aws eks list-nodegroups --cluster-name sandee --region us-east-1 --query 'nodegroups[0]' --output text) --region us-east-1

# 9. Create required secrets
echo "9. Creating required secrets..."
kubectl create namespace sandee --dry-run=client -o yaml | kubectl apply -f -

# Redis secret
kubectl create secret generic redis-secret \
    --from-literal=password=RedisStrongPassword123! \
    -n sandee --dry-run=client -o yaml | kubectl apply -f -

# Elasticsearch secret  
kubectl create secret generic elasticsearch-secret \
    --from-literal=username=elastic \
    --from-literal=password=ElasticStrongPassword123! \
    -n sandee --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "✅ Prerequisites check completed!"
echo "🚀 You can now run: ./deploy-ultimate-sandee.sh"
echo ""
echo "📋 Manual Steps Required:"
echo "   1. Ensure IAM roles have proper trust relationships"
echo "   2. Verify ACM certificate for *.sandee.com exists"
echo "   3. Update DNS records after deployment"
echo "   4. Configure Route53 hosted zone if needed"