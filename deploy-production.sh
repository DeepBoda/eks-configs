#!/bin/bash

set -e

echo "🚀 Deploying Production Infrastructure..."

# 1. Deploy ALB Ingress
echo "📡 Setting up ALB Ingress..."
kubectl apply -f 10-ingress-alb.yaml

# 2. Deploy HPA
echo "📈 Setting up Auto Scaling..."
kubectl apply -f 11-hpa-autoscaling.yaml

# 3. Deploy PDBs
echo "🛡️ Setting up High Availability..."
kubectl apply -f 12-pod-disruption-budgets.yaml

# 4. Check status
echo "✅ Production Infrastructure Status:"
echo ""
echo "🌐 Ingress:"
kubectl get ingress
echo ""
echo "📈 HPA:"
kubectl get hpa
echo ""
echo "🛡️ PDB:"
kubectl get pdb
echo ""
echo "🚀 All Pods:"
kubectl get pods -o wide
echo ""
echo "🌍 Services:"
kubectl get svc

echo ""
echo "🎉 Production Infrastructure Ready!"
echo ""
echo "📋 Next Steps:"
echo "1. Update DNS: sandee.com → ALB"
echo "2. Update DNS: api.sandee.com → ALB"  
echo "3. Update DNS: admin.sandee.com → ALB"
echo "4. Update certificate ARN in ingress"
echo "5. Monitor scaling and performance"