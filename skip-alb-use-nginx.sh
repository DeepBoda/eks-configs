#!/bin/bash

echo "🔄 SKIPPING ALB - USING NGINX INGRESS ONLY"

# Delete all ALB controller stuff
helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null || true
kubectl delete deployment aws-load-balancer-controller -n kube-system --ignore-not-found

# Update ingress to use nginx class instead of alb
kubectl patch ingress sandee-alb -n sandee -p '{"spec":{"ingressClassName":"nginx"}}'

# Check NGINX ingress controller
kubectl get pods -n ingress-nginx

# Get NGINX LoadBalancer external IP
kubectl get svc -n ingress-nginx

echo "✅ Using NGINX ingress instead of ALB"
echo "📋 Update your DNS to point to the NGINX LoadBalancer external IP"