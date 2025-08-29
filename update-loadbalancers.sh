#!/bin/bash

echo "Updating LoadBalancers: ALB for frontend + NLBs for backend/admin..."

# Delete old LoadBalancers
kubectl delete svc sandee-frontend-lb sandee-backend-lb sandee-admin-lb -n sandee-production

# Apply updated manifests
kubectl apply -f production-manifests.yaml

echo "Waiting for LoadBalancers to provision..."
sleep 30

echo "New LoadBalancer endpoints:"
kubectl get svc -n sandee-production | grep LoadBalancer