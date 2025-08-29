#!/bin/bash

echo "=== AWS Load Balancer Controller Master Fix ==="

# Clean up all existing deployments
echo "1. Cleaning up existing deployments..."
kubectl delete deployment aws-load-balancer-controller -n kube-system --ignore-not-found
kubectl delete pods -l app=aws-lb-controller -n kube-system --force --grace-period=0

# Get cluster info
echo "2. Getting cluster information..."
CLUSTER_NAME="sandee"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
OIDC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.identity.oidc.issuer' --output text | cut -d '/' -f 5)

echo "Account ID: $ACCOUNT_ID"
echo "OIDC ID: $OIDC_ID"

# Create correct trust policy
echo "3. Creating correct IAM trust policy..."
cat > alb-trust-final.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::$ACCOUNT_ID:oidc-provider/oidc.eks.$REGION.amazonaws.com/id/$OIDC_ID"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.$REGION.amazonaws.com/id/$OIDC_ID:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
                    "oidc.eks.$REGION.amazonaws.com/id/$OIDC_ID:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
EOF

# Update IAM role
echo "4. Updating IAM role..."
aws iam update-assume-role-policy --role-name AmazonEKSLoadBalancerControllerRole --policy-document file://alb-trust-final.json

# Create custom policy for ALB controller
echo "5. Creating custom ALB policy..."
cat > alb-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateServiceLinkedRole",
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAddresses",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeVpcs",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeInstances",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeTags",
                "ec2:GetCoipPoolUsage",
                "ec2:DescribeCoipPools",
                "elasticloadbalancing:*",
                "iam:PassRole",
                "iam:GetRole",
                "iam:ListRoles"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Create and attach policy
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://alb-policy.json --region $REGION 2>/dev/null || echo "Policy already exists"
aws iam attach-role-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy --role-name AmazonEKSLoadBalancerControllerRole

# Update service account
echo "6. Updating service account..."
kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system eks.amazonaws.com/role-arn=arn:aws:iam::$ACCOUNT_ID:role/AmazonEKSLoadBalancerControllerRole --overwrite

# Deploy controller
echo "7. Deploying AWS Load Balancer Controller..."
kubectl apply -f 04-aws-load-balancer-controller-complete.yaml

# Wait and check
echo "8. Waiting for deployment..."
sleep 30
kubectl get pods -n kube-system | grep aws-load-balancer

echo "9. Checking ingress status..."
kubectl get ingress -n sandee

echo "=== Fix completed ==="