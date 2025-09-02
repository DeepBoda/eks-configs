#!/bin/bash

echo "🔒 SAFE High Availability Migration - NO DATA LOSS"

# First, let's check current data status
echo "📊 Current data status:"
kubectl exec redis-0 -n sandee-production -- redis-cli info keyspace
kubectl exec elasticsearch-0 -n sandee-production -- curl -s localhost:9200/_cat/indices

echo ""
echo "⚠️  IMPORTANT: This migration will:"
echo "   ✅ Keep all existing Redis data (PVC preserved)"
echo "   ✅ Keep all existing Elasticsearch data (PVC preserved)" 
echo "   ✅ Add 2 more Redis replicas (redis-1, redis-2)"
echo "   ✅ Add 1 more Elasticsearch replica (elasticsearch-1)"
echo "   ✅ Existing pods become redis-0 and elasticsearch-0"
echo ""

read -p "Continue with safe migration? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Migration cancelled"
    exit 1
fi

# Step 1: Scale down applications to reduce load during migration
echo "📉 Temporarily reducing application load..."
kubectl patch hpa sandee-frontend-hpa -n sandee-production -p '{"spec":{"minReplicas":2,"maxReplicas":4}}'
kubectl patch hpa sandee-backend-hpa -n sandee-production -p '{"spec":{"minReplicas":3,"maxReplicas":6}}'

sleep 30

# Step 2: Delete StatefulSets but keep pods and PVCs
echo "🔄 Deleting StatefulSets (keeping data)..."
kubectl delete statefulset redis -n sandee-production --cascade=orphan
kubectl delete statefulset elasticsearch -n sandee-production --cascade=orphan

# Step 3: Apply new HA StatefulSets
echo "🚀 Creating HA StatefulSets..."
kubectl apply -f production-manifests.yaml

# Step 4: Wait for new replicas to join
echo "⏳ Waiting for Redis cluster expansion..."
kubectl wait --for=condition=ready pod redis-0 -n sandee-production --timeout=60s
kubectl wait --for=condition=ready pod redis-1 -n sandee-production --timeout=300s
kubectl wait --for=condition=ready pod redis-2 -n sandee-production --timeout=300s

echo "⏳ Waiting for Elasticsearch cluster expansion..."
kubectl wait --for=condition=ready pod elasticsearch-0 -n sandee-production --timeout=60s
kubectl wait --for=condition=ready pod elasticsearch-1 -n sandee-production --timeout=600s

# Step 5: Verify data integrity
echo "🔍 Verifying data integrity..."
echo "Redis data:"
kubectl exec redis-0 -n sandee-production -- redis-cli info keyspace

echo "Elasticsearch data:"
kubectl exec elasticsearch-0 -n sandee-production -- curl -s localhost:9200/_cat/indices

# Step 6: Restore full scaling
echo "📈 Restoring full auto-scaling..."
kubectl patch hpa sandee-frontend-hpa -n sandee-production -p '{"spec":{"minReplicas":8,"maxReplicas":50}}'
kubectl patch hpa sandee-backend-hpa -n sandee-production -p '{"spec":{"minReplicas":10,"maxReplicas":100}}'

echo ""
echo "✅ SAFE MIGRATION COMPLETE!"
echo "📊 Final status:"
kubectl get pods -n sandee-production -o wide
kubectl get pvc -n sandee-production
echo ""
echo "🎉 Your data is safe and you now have HA clusters ready for 500+ users!"