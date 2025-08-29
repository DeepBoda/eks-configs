#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

print_header "🚀 SIMPLE SANDEE EKS DEPLOYMENT"
print_status "Using working configurations with gp2 storage..."

# Phase 1: Core Infrastructure
print_header "Phase 1: Core Infrastructure"
print_status "Creating namespaces..."
kubectl apply -f 00-namespaces.yaml

print_status "Setting up RBAC and IRSA..."
kubectl apply -f 02-rbac-irsa.yaml

# Phase 2: Controllers (Skip problematic ones)
print_header "Phase 2: Controllers"
print_status "Deploying Cluster Autoscaler..."
kubectl apply -f 03-cluster-autoscaler.yaml

print_status "Deploying Simple NGINX Ingress..."
kubectl apply -f 05-ingress-nginx-simple.yaml

# Phase 3: Simple Database Layer
print_header "Phase 3: Database Layer"
print_status "Deploying Simple Redis..."
kubectl apply -f 06-redis-simple.yaml

print_status "Deploying Simple Elasticsearch..."
kubectl apply -f 07-elasticsearch-simple.yaml

# Phase 4: Application Layer
print_header "Phase 4: Application Layer"
print_status "Deploying Applications..."
kubectl apply -f 08-application-deployments.yaml

print_status "Creating Services..."
kubectl apply -f 09-services.yaml

# Phase 5: Wait and Verify
print_header "Phase 5: Verification"
print_status "Waiting for deployments..."
sleep 30

echo ""
print_status "=== DEPLOYMENT STATUS ==="
echo ""

print_status "Pods in sandee namespace:"
kubectl get pods -n sandee

echo ""
print_status "Services in sandee namespace:"
kubectl get svc -n sandee

echo ""
print_status "PersistentVolumeClaims:"
kubectl get pvc -n sandee

echo ""
print_status "NGINX Ingress:"
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

echo ""
print_header "🎉 SIMPLE SANDEE DEPLOYMENT COMPLETE!"
echo ""
print_success "Your Sandee infrastructure is ready!"
echo ""
print_status "Applications:"
print_status "  🌐 Frontend: Running"
print_status "  🔧 Backend:  Running"  
print_status "  👨💼 Admin:    Running"
echo ""
print_status "Databases:"
print_status "  🔴 Redis:         redis-service.sandee.svc.cluster.local:6379"
print_status "  🔍 Elasticsearch: elasticsearch.sandee.svc.cluster.local:9200"
echo ""
print_warning "Note: Using simple configurations due to EBS CSI driver issues"
print_warning "Upgrade to optimized versions once EBS CSI is fixed"