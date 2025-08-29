#!/bin/bash

echo "=== SANDEE PRODUCTION CLUSTER - ENDPOINTS ==="
echo ""

# Get LoadBalancer endpoints
FRONTEND_LB=$(kubectl get svc sandee-frontend-lb -n sandee-production -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
BACKEND_LB=$(kubectl get svc sandee-backend-lb -n sandee-production -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
ADMIN_LB=$(kubectl get svc sandee-admin-lb -n sandee-production -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "🌐 PRODUCTION ENDPOINTS:"
echo "Frontend:  http://$FRONTEND_LB"
echo "Backend:   http://$BACKEND_LB:8008"
echo "Admin:     http://$ADMIN_LB:3000"
echo ""

echo "📊 CLUSTER STATUS:"
kubectl get pods -n sandee-production --no-headers | awk '{print $1 ": " $3}' | sort
echo ""

echo "🔄 HPA STATUS:"
kubectl get hpa -n sandee-production --no-headers | awk '{print $1 ": " $5 "/" $6 " replicas"}'
echo ""

echo "💾 STORAGE:"
kubectl get pvc -n sandee-production --no-headers | awk '{print $1 ": " $4 " (" $2 ")"}'
echo ""

echo "🧪 TESTING ENDPOINTS:"
echo "Testing Frontend..."
curl -s -o /dev/null -w "Frontend: %{http_code}\n" http://$FRONTEND_LB --connect-timeout 10

echo "Testing Backend..."
curl -s -o /dev/null -w "Backend: %{http_code}\n" http://$BACKEND_LB:8008/health --connect-timeout 10

echo "Testing Admin..."
curl -s -o /dev/null -w "Admin: %{http_code}\n" http://$ADMIN_LB:3000 --connect-timeout 10

echo ""
echo "🎯 DNS SETUP (Route 53):"
echo "Create CNAME records in sandee.com hosted zone:"
echo "  sandee.com        -> $FRONTEND_LB"
echo "  eks.sandee.com    -> $FRONTEND_LB"
echo "  api.sandee.com    -> $BACKEND_LB"
echo "  admin.sandee.com  -> $ADMIN_LB"
echo ""
echo "✅ Production cluster is ready!"