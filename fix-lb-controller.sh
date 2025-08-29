#!/bin/bash

# Fix AWS Load Balancer Controller IAM permissions

echo "Creating IAM role for AWS Load Balancer Controller..."

# Get cluster info
CLUSTER_NAME="sandee-production"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create IAM role for Load Balancer Controller
cat > lb-controller-trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} --query "cluster.identity.oidc.issuer" --output text | sed 's|https://||')"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} --query "cluster.identity.oidc.issuer" --output text | sed 's|https://||'):sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
                    "$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} --query "cluster.identity.oidc.issuer" --output text | sed 's|https://||'):aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
EOF

# Create the role
aws iam create-role \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --assume-role-policy-document file://lb-controller-trust-policy.json \
    --region ${REGION} || echo "Role already exists"

# Attach the policy
aws iam attach-role-policy \
    --policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --region ${REGION}

# Download and apply the Load Balancer Controller policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json \
    --region ${REGION} || echo "Policy already exists"

aws iam attach-role-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --region ${REGION}

# Annotate the service account
kubectl annotate serviceaccount aws-load-balancer-controller \
    -n kube-system \
    eks.amazonaws.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/AmazonEKSLoadBalancerControllerRole \
    --overwrite

# Restart the controller
kubectl rollout restart deployment aws-load-balancer-controller -n kube-system

echo "Waiting for controller to restart..."
kubectl rollout status deployment aws-load-balancer-controller -n kube-system

echo "Load Balancer Controller IAM setup complete!"
echo "Checking LoadBalancer services..."
kubectl get svc -n sandee-production | grep LoadBalancer

# Clean up temp files
rm -f lb-controller-trust-policy.json iam_policy.json