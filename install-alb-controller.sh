#!/bin/bash

# Delete existing deployment
kubectl delete deployment aws-load-balancer-controller -n kube-system --ignore-not-found

# Create IAM role for AWS Load Balancer Controller
cat > alb-controller-trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::838645860193:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/$(aws eks describe-cluster --name sandee --region us-east-1 --query 'cluster.identity.oidc.issuer' --output text | cut -d '/' -f 5)"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.us-east-1.amazonaws.com/id/$(aws eks describe-cluster --name sandee --region us-east-1 --query 'cluster.identity.oidc.issuer' --output text | cut -d '/' -f 5):sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
                    "oidc.eks.us-east-1.amazonaws.com/id/$(aws eks describe-cluster --name sandee --region us-east-1 --query 'cluster.identity.oidc.issuer' --output text | cut -d '/' -f 5):aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
EOF

# Create the IAM role
aws iam create-role --role-name AmazonEKSLoadBalancerControllerRole --assume-role-policy-document file://alb-controller-trust-policy.json --region us-east-1

# Attach the policy
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess --role-name AmazonEKSLoadBalancerControllerRole --region us-east-1

# Install via eksctl
eksctl create iamserviceaccount \
  --cluster=sandee \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess \
  --region=us-east-1 \
  --approve \
  --override-existing-serviceaccounts

# Apply the deployment
kubectl apply -f 04-aws-load-balancer-controller-complete.yaml

echo "AWS Load Balancer Controller installation completed"