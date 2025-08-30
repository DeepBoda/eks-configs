#!/bin/bash

echo "🚀 Deploying with Helm Redis..."

# Update Helm Redis values for production
sed -i 's/redis-storage-class/gp3-production/g' redis-helm/values.yaml

# Deploy Redis with Helm
helm install redis-stack ./redis-helm -n sandee-production --create-namespace

# Wait for Redis
echo "⏳ Waiting for Redis master-replica cluster..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis-stack-master -n sandee-production --timeout=300s

# Deploy other components
kubectl apply -f production-manifests.yaml

echo "✅ Deployment complete!"
echo "🔍 Redis services:"
kubectl get svc -n sandee-production | grep redis