#!/bin/bash

echo "🚀 QUICK PRODUCTION FIX"

# Skip the stuck parts, just create LoadBalancers
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

echo "✅ LoadBalancers created!"
kubectl get svc -n sandee | grep lb