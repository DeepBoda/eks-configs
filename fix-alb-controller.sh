#!/bin/bash

# Get the correct OIDC issuer ID
OIDC_ID=$(aws eks describe-cluster --name sandee --region us-east-1 --query 'cluster.identity.oidc.issuer' --output text | cut -d '/' -f 5)
echo "OIDC ID: $OIDC_ID"

# Delete existing broken deployment
kubectl delete deployment aws-load-balancer-controller -n kube-system --ignore-not-found

# Create proper trust policy with correct OIDC ID
cat > alb-trust-policy-fixed.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::830986456729:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/$OIDC_ID"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.us-east-1.amazonaws.com/id/$OIDC_ID:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
                    "oidc.eks.us-east-1.amazonaws.com/id/$OIDC_ID:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
EOF

# Update the existing role with correct trust policy
aws iam update-assume-role-policy --role-name AmazonEKSLoadBalancerControllerRole --policy-document file://alb-trust-policy-fixed.json --region us-east-1

# Attach additional required policies
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess --role-name AmazonEKSLoadBalancerControllerRole --region us-east-1
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/EC2FullAccess --role-name AmazonEKSLoadBalancerControllerRole --region us-east-1

# Update service account with correct role ARN
kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system eks.amazonaws.com/role-arn=arn:aws:iam::830986456729:role/AmazonEKSLoadBalancerControllerRole --overwrite

# Apply the deployment
kubectl apply -f 04-aws-load-balancer-controller-complete.yaml

echo "Fixed AWS Load Balancer Controller"