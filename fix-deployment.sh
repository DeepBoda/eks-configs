#!/bin/bash
# Script to fix the stuck backend deployment

echo "=== Fixing Backend Deployment ==="
echo ""

echo "Step 1: Applying updated configuration with maxSurge: 25%..."
kubectl apply -f production-manifests.yaml

echo ""
echo "Step 2: Waiting 10 seconds for changes to propagate..."
sleep 10

echo ""
echo "Step 3: Checking deployment status..."
kubectl get deployment sandee-backend -n sandee-production

echo ""
echo "Step 4: Checking pod status..."
kubectl get pods -n sandee-production | grep sandee-backend

echo ""
echo "Step 5: Checking rollout status..."
kubectl rollout status deployment/sandee-backend -n sandee-production --timeout=5m

echo ""
echo "=== Deployment Fix Complete ==="
echo ""
echo "If pods are still pending, you may need to:"
echo "1. Delete the old ReplicaSet manually, or"
echo "2. Scale down temporarily and scale back up"
echo ""
echo "To check node resources:"
echo "  kubectl top nodes"
echo ""
echo "To describe a pending pod:"
echo "  kubectl describe pod <pod-name> -n sandee-production"

