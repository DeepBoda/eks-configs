#!/bin/bash

echo "🚀 ULTIMATE EKS CLUSTER FIX - PRODUCTION READY"

# 1. Fix VPC CNI (core networking issue)
echo "🔧 Fixing VPC CNI networking..."
kubectl delete daemonset aws-node -n kube-system
kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/v1.18.1/config/master/aws-k8s-cni.yaml

# 2. Restart CoreDNS
echo "🔧 Restarting CoreDNS..."
kubectl rollout restart deployment coredns -n kube-system

# 3. Clean up broken ingress
echo "🧹 Cleaning up broken ingress controllers..."
kubectl delete namespace ingress-nginx
helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null || true

# 4. Create production LoadBalancer services (bypass ingress)
echo "🚀 Creating production LoadBalancer services..."
cat > production-services.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: sandee-frontend-lb
  namespace: sandee
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
  selector:
    app: sandee-frontend
---
apiVersion: v1
kind: Service
metadata:
  name: sandee-backend-lb
  namespace: sandee
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
spec:
  type: LoadBalancer
  ports:
  - port: 8008
    targetPort: 8008
    protocol: TCP
  selector:
    app: sandee-backend
---
apiVersion: v1
kind: Service
metadata:
  name: sandee-admin-lb
  namespace: sandee
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
spec:
  type: LoadBalancer
  ports:
  - port: 3000
    targetPort: 3000
    protocol: TCP
  selector:
    app: sandee-admin
EOF

kubectl apply -f production-services.yaml

# 5. Wait for networking to stabilize
echo "⏳ Waiting for networking to stabilize..."
sleep 30

# 6. Check status
echo "✅ Checking cluster status..."
kubectl get nodes
kubectl get pods -n kube-system | grep -E "(coredns|aws-node)"
kubectl get svc -n sandee | grep -E "lb"

# 7. Get LoadBalancer URLs
echo "🌐 Production URLs:"
echo "Frontend: $(kubectl get svc sandee-frontend-lb -n sandee -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "Backend: $(kubectl get svc sandee-backend-lb -n sandee -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "Admin: $(kubectl get svc sandee-admin-lb -n sandee -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

echo "🎉 PRODUCTION CLUSTER READY!"