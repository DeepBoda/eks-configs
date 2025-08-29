#!/bin/bash

echo "Testing Redis performance for 100k+ ops/minute..."

# Deploy optimized Redis
./deploy-redis-cluster.sh

echo "Running performance benchmark..."
kubectl run redis-benchmark --rm -i --restart=Never --namespace=sandee-production \
  --image=redis:7.0 -- redis-benchmark \
  -h redis-lb -p 6379 \
  -c 100 -n 100000 \
  -d 1024 \
  --csv

echo "Testing cluster connectivity..."
for i in {0..2}; do
    echo "Testing redis-$i performance:"
    kubectl exec -n sandee-production redis-$i -- redis-benchmark -q -n 10000 -c 10
done

echo "Redis configuration:"
kubectl exec -n sandee-production redis-0 -- redis-cli CONFIG GET "*memory*"
kubectl exec -n sandee-production redis-0 -- redis-cli CONFIG GET "*client*"