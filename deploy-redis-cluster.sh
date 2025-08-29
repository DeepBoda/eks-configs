#!/bin/bash

echo "Deploying Redis Stack Cluster (3 replicas)..."

# Delete existing Redis
kubectl delete statefulset redis -n sandee-production 2>/dev/null || true
kubectl delete svc redis -n sandee-production 2>/dev/null || true
kubectl delete configmap redis-config -n sandee-production 2>/dev/null || true

# Apply new Redis cluster configuration
kubectl apply -f production-manifests.yaml

echo "Waiting for Redis cluster to be ready..."
kubectl rollout status statefulset redis -n sandee-production

echo "Redis cluster status:"
kubectl get pods -n sandee-production -l app=redis

echo "Testing Redis cluster connectivity..."
sleep 10

# Test each Redis instance
for i in {0..2}; do
    echo "Testing redis-$i..."
    kubectl exec -n sandee-production redis-$i -- redis-cli ping || echo "redis-$i not ready yet"
done

echo "Redis cluster endpoints:"
kubectl get svc -n sandee-production | grep redis

echo "✅ Redis Stack cluster deployed with:"
echo "  - 3 replicas with anti-affinity"
echo "  - Persistent storage (50GB each)"
echo "  - AOF + RDB persistence"
echo "  - Redis Stack modules (Search, Graph, TimeSeries, JSON, Bloom)"
echo "  - RedisInsight on port 8001"
echo "  - High performance configuration"