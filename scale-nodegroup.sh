#!/bin/bash

# Scale the node group for better capacity
aws eks update-nodegroup-config \
  --cluster-name sandee-production \
  --nodegroup-name production-nodes \
  --scaling-config minSize=6,maxSize=20,desiredSize=8

# Wait for nodes to be ready
echo "Waiting for nodes to scale..."
sleep 60

# Check node status
kubectl get nodes

# Apply optimized configuration
kubectl apply -f production-manifests.yaml

echo "Node group scaled and configuration applied!"