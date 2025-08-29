#!/bin/bash

echo "🚀 DEPLOYING SANDEE PRODUCTION APPLICATION"

# 1. Deploy certificate secret first
echo "🔐 Deploying Elasticsearch certificate..."
kubectl apply -f elasticsearch-secret.yaml

# 2. Deploy all manifests
echo "📦 Deploying production manifests..."
kubectl apply -f production-manifests.yaml

# 2. Wait for deployments
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/sandee-frontend -n sandee-production
kubectl wait --for=condition=available --timeout=300s deployment/sandee-backend -n sandee-production
kubectl wait --for=condition=available --timeout=300s deployment/sandee-admin -n sandee-production

# 3. Wait for LoadBalancers
echo "🌐 Waiting for LoadBalancers to provision..."
sleep 60

# 4. Get LoadBalancer URLs
echo "🎯 Production URLs:"
FRONTEND_LB=$(kubectl get svc sandee-frontend-lb -n sandee-production -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
BACKEND_LB=$(kubectl get svc sandee-backend-lb -n sandee-production -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
ADMIN_LB=$(kubectl get svc sandee-admin-lb -n sandee-production -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Frontend: http://$FRONTEND_LB"
echo "Backend: http://$BACKEND_LB:8008"
echo "Admin: http://$ADMIN_LB:3000"

# 5. Create Route 53 DNS records
echo "🌐 Creating DNS records..."
cat > route53-production.json << EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "eks.sandee.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "$FRONTEND_LB"}]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "eks-backend.sandee.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "$BACKEND_LB"}]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "eks-admin.sandee.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "$ADMIN_LB"}]
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id Z07447471NF0OXP20NO0O \
  --change-batch file://route53-production.json \
  --region us-east-1

# 6. Final status check
echo "✅ Production deployment complete!"
echo "🔍 Cluster status:"
kubectl get nodes -o wide
kubectl get pods -n sandee-production -o wide
kubectl get svc -n sandee-production
kubectl get hpa -n sandee-production

echo "🌐 Your production sites:"
echo "   https://eks.sandee.com"
echo "   https://eks-backend.sandee.com"
echo "   https://eks-admin.sandee.com"

echo "🎉 SANDEE PRODUCTION IS LIVE!"