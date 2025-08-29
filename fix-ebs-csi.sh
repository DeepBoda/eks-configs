#!/bin/bash

# Fix EBS CSI Driver Issues
echo "🔧 Fixing EBS CSI Driver..."

# 1. Delete broken EBS CSI pods
kubectl delete pods -n kube-system -l app=ebs-csi-node --force --grace-period=0
kubectl delete pods -n kube-system -l app=ebs-csi-controller --force --grace-period=0

# 2. Restart EBS CSI DaemonSet
kubectl rollout restart daemonset/ebs-csi-node -n kube-system
kubectl rollout restart deployment/ebs-csi-controller -n kube-system

# 3. Wait for EBS CSI to be ready
echo "⏳ Waiting for EBS CSI driver to be ready..."
kubectl wait --for=condition=ready pod -l app=ebs-csi-controller -n kube-system --timeout=300s
kubectl wait --for=condition=ready pod -l app=ebs-csi-node -n kube-system --timeout=300s

# 4. Check EBS CSI status
echo "✅ EBS CSI Status:"
kubectl get pods -n kube-system | grep ebs-csi

echo "🚀 EBS CSI driver fixed! Now you can use persistent storage."