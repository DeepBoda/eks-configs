#!/bin/bash

# Fix OIDC provider and IAM role trust relationship

CLUSTER_NAME="sandee-production"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Checking OIDC provider for cluster ${CLUSTER_NAME}..."

# Get OIDC issuer URL
OIDC_ISSUER=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} --query "cluster.identity.oidc.issuer" --output text)
OIDC_ID=$(echo $OIDC_ISSUER | sed 's|https://||')

echo "OIDC Issuer: $OIDC_ISSUER"
echo "OIDC ID: $OIDC_ID"

# Check if OIDC provider exists
aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?ends_with(Arn, '${OIDC_ID}')]" --output text

# Create OIDC provider if it doesn't exist
if ! aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?ends_with(Arn, '${OIDC_ID}')]" --output text | grep -q "${OIDC_ID}"; then
    echo "Creating OIDC provider..."
    
    # Get thumbprint
    THUMBPRINT=$(echo | openssl s_client -servername oidc.eks.${REGION}.amazonaws.com -connect oidc.eks.${REGION}.amazonaws.com:443 2>/dev/null | openssl x509 -fingerprint -noout -sha1 | sed 's/://g' | awk -F= '{print tolower($2)}')
    
    aws iam create-open-id-connect-provider \
        --url $OIDC_ISSUER \
        --thumbprint-list $THUMBPRINT \
        --client-id-list sts.amazonaws.com
else
    echo "OIDC provider already exists"
fi

# Delete existing role to recreate with correct trust policy
echo "Recreating IAM role with correct trust policy..."
aws iam detach-role-policy --role-name AmazonEKSLoadBalancerControllerRole --policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess 2>/dev/null || true
aws iam detach-role-policy --role-name AmazonEKSLoadBalancerControllerRole --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy 2>/dev/null || true
aws iam delete-role --role-name AmazonEKSLoadBalancerControllerRole 2>/dev/null || true

# Create correct trust policy
cat > lb-controller-trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_ID}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "${OIDC_ID}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
                    "${OIDC_ID}:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
EOF

# Create the role with correct trust policy
aws iam create-role \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --assume-role-policy-document file://lb-controller-trust-policy.json

# Attach policies
aws iam attach-role-policy \
    --policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess \
    --role-name AmazonEKSLoadBalancerControllerRole

aws iam attach-role-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
    --role-name AmazonEKSLoadBalancerControllerRole

# Update service account annotation
kubectl annotate serviceaccount aws-load-balancer-controller \
    -n kube-system \
    eks.amazonaws.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/AmazonEKSLoadBalancerControllerRole \
    --overwrite

# Restart the controller
kubectl rollout restart deployment aws-load-balancer-controller -n kube-system

echo "Waiting for controller to restart..."
kubectl rollout status deployment aws-load-balancer-controller -n kube-system

echo "Setup complete! Checking services..."
sleep 10
kubectl get svc -n sandee-production | grep LoadBalancer

# Clean up
rm -f lb-controller-trust-policy.json