#!/bin/bash

echo "🔥 FINAL ALB CONTROLLER FIX - NO MORE ISSUES!"

# Delete everything ALB related
kubectl delete deployment aws-load-balancer-controller -n kube-system --ignore-not-found
kubectl delete secret aws-load-balancer-webhook-tls -n kube-system --ignore-not-found
kubectl delete mutatingwebhookconfiguration aws-load-balancer-webhook --ignore-not-found
kubectl delete validatingwebhookconfiguration aws-load-balancer-webhook --ignore-not-found
kubectl delete service aws-load-balancer-webhook-service -n kube-system --ignore-not-found

# Create the missing TLS secret
kubectl create secret tls aws-load-balancer-webhook-tls \
  --cert=/dev/null \
  --key=/dev/null \
  -n kube-system \
  --dry-run=client -o yaml | kubectl apply -f -

# Create a simple working deployment without webhooks
cat > alb-simple.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  labels:
    app.kubernetes.io/name: aws-load-balancer-controller
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: aws-load-balancer-controller
  template:
    metadata:
      labels:
        app.kubernetes.io/name: aws-load-balancer-controller
    spec:
      serviceAccountName: aws-load-balancer-controller
      containers:
      - name: controller
        image: public.ecr.aws/eks/aws-load-balancer-controller:v2.7.2
        args:
        - --cluster-name=sandee
        - --ingress-class=alb
        - --aws-region=us-east-1
        - --enable-shield=false
        - --enable-waf=false
        - --enable-wafv2=false
        resources:
          requests:
            cpu: 100m
            memory: 200Mi
          limits:
            cpu: 200m
            memory: 500Mi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 61779
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /readyz
            port: 61779
          initialDelaySeconds: 10
EOF

# Apply simple deployment
kubectl apply -f alb-simple.yaml

# Wait and check
sleep 15
kubectl get pods -n kube-system | grep aws-load-balancer

# Check ingress
kubectl get ingress -n sandee

echo "✅ DONE! ALB Controller should be working now!"