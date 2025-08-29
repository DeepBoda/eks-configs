#!/bin/bash

# Clean up everything
kubectl delete deployment aws-load-balancer-controller -n kube-system --ignore-not-found

# Install Helm if not present
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Add EKS repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install via Helm (this handles all the RBAC and permissions correctly)
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=sandee \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-1 \
  --set vpcId=vpc-02f40ee7a414a4512

# Check status
kubectl get pods -n kube-system | grep aws-load-balancer