#!/bin/bash

# Kill the stuck process
pkill -f ultimate-alb-fix.sh

# Clean up
kubectl delete deployment aws-load-balancer-controller -n kube-system --ignore-not-found

# Use official AWS method - download and apply directly
curl -o v2_7_2_full.yaml https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.7.2/v2_7_2_full.yaml

# Edit the deployment to use our cluster name
sed -i 's/your-cluster-name/sandee/g' v2_7_2_full.yaml

# Apply it
kubectl apply -f v2_7_2_full.yaml

# Check status immediately
kubectl get pods -n kube-system | grep aws-load-balancer

echo "Official AWS Load Balancer Controller installed"