#!/bin/bash

# Clean up
kubectl delete deployment aws-load-balancer-controller -n kube-system --ignore-not-found
kubectl delete pods -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --force --grace-period=0

# Download official manifest
curl -L -o v2_7_2_full.yaml https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.7.2/v2_7_2_full.yaml

# Replace cluster name
sed -i.bak 's/your-cluster-name/sandee/g' v2_7_2_full.yaml

# Apply
kubectl apply -f v2_7_2_full.yaml

# Wait a bit
sleep 10

# Check
kubectl get pods -n kube-system | grep aws-load-balancer