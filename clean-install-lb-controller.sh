#!/bin/bash

echo "Cleaning up existing load balancer controllers..."

# Remove all existing load balancer controllers
kubectl delete deployment aws-load-balancer-controller -n kube-system 2>/dev/null || true
kubectl delete deployment sandee-load-balancer-controller -n kube-system 2>/dev/null || true

# Remove all related pods
kubectl delete pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller 2>/dev/null || true

# Remove service accounts
kubectl delete serviceaccount aws-load-balancer-controller -n kube-system 2>/dev/null || true
kubectl delete serviceaccount sandee-load-balancer-controller -n kube-system 2>/dev/null || true

# Remove any helm releases
helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null || true
helm uninstall sandee-load-balancer-controller -n kube-system 2>/dev/null || true

# Remove secrets
kubectl delete secret aws-load-balancer-tls -n kube-system 2>/dev/null || true

echo "Creating service account with proper IAM role..."

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create service account
kubectl create serviceaccount aws-load-balancer-controller -n kube-system

# Annotate with IAM role
kubectl annotate serviceaccount aws-load-balancer-controller \
    -n kube-system \
    eks.amazonaws.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/AmazonEKSLoadBalancerControllerRole

echo "Installing AWS Load Balancer Controller via Helm..."

# Install via Helm
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=sandee-production \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

echo "Waiting for deployment..."
kubectl rollout status deployment aws-load-balancer-controller -n kube-system

echo "Checking controller status..."
kubectl get pods -n kube-system | grep aws-load-balancer-controller

echo "Checking LoadBalancer services..."
kubectl get svc -n sandee-production | grep LoadBalancer