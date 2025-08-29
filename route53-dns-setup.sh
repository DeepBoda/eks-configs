#!/bin/bash

echo "🌐 Setting up Route 53 DNS for production"

# Get LoadBalancer hostnames
FRONTEND_LB=$(kubectl get svc sandee-frontend-lb -n sandee -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
BACKEND_LB=$(kubectl get svc sandee-backend-lb -n sandee -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
ADMIN_LB=$(kubectl get svc sandee-admin-lb -n sandee -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Frontend LB: $FRONTEND_LB"
echo "Backend LB: $BACKEND_LB"
echo "Admin LB: $ADMIN_LB"

# Create Route 53 records
cat > route53-records.json << EOF
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

# Apply DNS records
aws route53 change-resource-record-sets \
  --hosted-zone-id Z07447471NF0OXP20NO0O \
  --change-batch file://route53-records.json \
  --region us-east-1

echo "✅ DNS records created!"
echo "🌐 Your sites will be available at:"
echo "   https://eks.sandee.com"
echo "   https://eks-backend.sandee.com"
echo "   https://eks-admin.sandee.com"