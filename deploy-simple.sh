#!/bin/bash

echo "🚀 Simple EKS Deployment - Core Fixes Only"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_status "Deploying simplified configuration..."
print_status "• Frontend: 8 replicas, simple resources"
print_status "• Backend: 6 replicas, simple resources"  
print_status "• Redis: 3 replicas, 2GB memory"
print_status "• ALB with HTTP/2 enabled"

echo ""
read -p "Continue with deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled"
    exit 0
fi

# Backup existing configuration
print_status "Creating backup..."
kubectl get all -n sandee-production -o yaml > backup-$(date +%Y%m%d-%H%M%S).yaml 2>/dev/null || true

# Apply configuration
print_status "Applying configuration..."
if kubectl apply -f production-manifests.yaml; then
    print_status "Configuration applied successfully"
else
    print_error "Failed to apply configuration"
    exit 1
fi

# Wait for rollout
print_status "Waiting for deployments to roll out..."
kubectl rollout status deployment/sandee-frontend -n sandee-production --timeout=300s
kubectl rollout status deployment/sandee-backend -n sandee-production --timeout=300s
kubectl rollout status statefulset/redis -n sandee-production --timeout=300s
kubectl rollout status statefulset/elasticsearch -n sandee-production --timeout=300s

# Check status
print_status "Checking pod status..."
kubectl get pods -n sandee-production

print_status "Checking HPA status..."
kubectl get hpa -n sandee-production

print_status "Checking Ingress status..."
kubectl get ingress -n sandee-production

echo ""
print_status "✅ Deployment complete!"
print_status "Monitor with: kubectl get pods -n sandee-production -w"
print_status "Check HPA: kubectl get hpa -n sandee-production -w"
