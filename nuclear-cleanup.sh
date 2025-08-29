#!/bin/bash

echo "💥 NUCLEAR CLEANUP - EVERYTHING FROM SCRATCH"

# 1. Skip namespace cleanup - cluster deletion will clean everything
echo "⚡ Skipping stuck namespaces - deleting clusters directly..."

# 2. Delete clusters in parallel (this cleans everything)
echo "🗑️ Deleting clusters in parallel..."
eksctl delete cluster --name sandee --region us-east-1 --disable-nodegroup-eviction --parallel=10 &
eksctl delete cluster --name sandee-new --region us-east-1 --disable-nodegroup-eviction --parallel=10 &

# 3. Reset kubectl config completely
echo "🧹 Resetting kubectl config..."
cp ~/.kube/config ~/.kube/config.backup 2>/dev/null || true
cat > ~/.kube/config << 'EOF'
apiVersion: v1
kind: Config
clusters: []
contexts: []
current-context: ""
preferences: {}
users: []
EOF

# 4. Wait for cluster deletions to complete
echo "⏳ Waiting for cluster deletions to complete..."
wait
sleep 30

# 5. Create fresh production cluster
echo "🚀 Creating sandee-production cluster..."
eksctl create cluster \
  --name sandee-production \
  --region us-east-1 \
  --version 1.33 \
  --nodegroup-name production-nodes \
  --node-type m6i.xlarge \
  --nodes 6 \
  --nodes-min 6 \
  --nodes-max 20 \
  --node-volume-size 100 \
  --node-ami-family AmazonLinux2023 \
  --managed \
  --enable-ssm \
  --full-ecr-access \
  --asg-access \
  --external-dns-access \
  --appmesh-access \
  --alb-ingress-access

# 6. Clean up any default namespaces we don't need
echo "🧹 Cleaning up unnecessary namespaces..."
kubectl delete namespace aws-load-balancer-controller --ignore-not-found
kubectl delete namespace ingress-nginx --ignore-not-found

# 7. Verify fresh setup
echo "✅ Fresh setup complete!"
echo "📋 New cluster info:"
kubectl cluster-info
kubectl get nodes -o wide
kubectl get namespaces

echo "🎉 READY FOR PRODUCTION DEPLOYMENT!"