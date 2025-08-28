#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

wait_for_deployment() {
    local name=$1
    local namespace=$2
    print_status "Waiting for deployment $name in namespace $namespace..."
    kubectl wait --for=condition=available --timeout=300s deployment/$name -n $namespace || {
        print_error "Deployment $name failed to become ready"
        return 1
    }
    print_success "Deployment $name is ready"
}

wait_for_pods() {
    local label=$1
    local namespace=$2
    local count=${3:-1}
    print_status "Waiting for $count pods with label $label in namespace $namespace..."
    kubectl wait --for=condition=ready --timeout=300s pod -l $label -n $namespace || {
        print_error "Pods with label $label failed to become ready"
        return 1
    }
    print_success "Pods with label $label are ready"
}

# Phase 1: Namespaces
print_status "Phase 1: Creating namespaces..."
kubectl apply -f 00-namespaces.yaml
print_success "Namespaces created"

# Phase 2: Storage Classes (delete and recreate to avoid update issues)
print_status "Phase 2: Setting up storage classes..."
kubectl delete storageclass gp3-optimized gp3-redis gp3-elasticsearch --ignore-not-found=true
kubectl apply -f 01-storage-classes.yaml
print_success "Storage classes configured"

# Phase 3: RBAC and IRSA
print_status "Phase 3: Configuring RBAC and IRSA..."
kubectl apply -f 02-rbac-irsa.yaml
print_success "RBAC and IRSA configured"

# Phase 4: Cluster Autoscaler
print_status "Phase 4: Deploying Cluster Autoscaler..."
kubectl apply -f 03-cluster-autoscaler.yaml
wait_for_deployment "cluster-autoscaler" "kube-system"

# Phase 5: AWS Load Balancer Controller
print_status "Phase 5: Deploying AWS Load Balancer Controller..."
kubectl delete deployment aws-load-balancer-controller -n aws-load-balancer-controller --ignore-not-found=true
sleep 5
kubectl apply -f 04-aws-load-balancer-controller.yaml
wait_for_deployment "aws-load-balancer-controller" "aws-load-balancer-controller"

# Phase 6: NGINX Ingress Controller
print_status "Phase 6: Deploying NGINX Ingress Controller..."
kubectl apply -f 05-ingress-nginx.yaml
wait_for_deployment "ingress-nginx-controller" "ingress-nginx"

# Phase 7: Metrics Server
print_status "Phase 7: Installing Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
wait_for_deployment "metrics-server" "kube-system"

# Phase 8: Database Layer
print_status "Phase 8: Deploying Redis..."
kubectl apply -f 06-redis-statefulset.yaml
print_status "Waiting for Redis StatefulSet..."
kubectl wait --for=condition=ready --timeout=600s pod -l app=redis -n sandee || print_warning "Redis pods may still be starting"

print_status "Phase 9: Deploying Elasticsearch..."
kubectl apply -f 07-elasticsearch-secret.yaml
kubectl apply -f 07-elasticsearch-cluster.yaml
print_status "Waiting for Elasticsearch..."
kubectl wait --for=condition=ready --timeout=600s pod -l app=elasticsearch -n sandee || print_warning "Elasticsearch pods may still be starting"

# Phase 10: Application Layer
print_status "Phase 10: Deploying Applications..."
kubectl apply -f 08-application-deployments.yaml
wait_for_deployment "sandee-frontend" "sandee"
wait_for_deployment "sandee-backend" "sandee"
wait_for_deployment "sandee-admin" "sandee"

# Phase 11: Services
print_status "Phase 11: Creating Services..."
kubectl apply -f 09-services.yaml
print_success "Services created"

# Phase 12: Ingress Resources
print_status "Phase 12: Creating Ingress Resources..."
kubectl apply -f 10-ingress-resources.yaml
print_success "Ingress resources created"

# Phase 13: HPA and PDB
print_status "Phase 13: Configuring HPA and PDB..."
kubectl apply -f 11-hpa-configurations.yaml
kubectl apply -f 12-pod-disruption-budgets.yaml
print_success "HPA and PDB configured"

# Final Status Check
print_status "Final Status Check..."
echo ""
print_status "Pods in sandee namespace:"
kubectl get pods -n sandee
echo ""
print_status "Services in sandee namespace:"
kubectl get svc -n sandee
echo ""
print_status "Ingress resources:"
kubectl get ingress -n sandee
echo ""
print_success "Sandee EKS Infrastructure Deployment Complete!"
print_status "Access your applications at:"
print_status "  Frontend: https://eks.sandee.com"
print_status "  Backend:  https://eks-backend.sandee.com"
print_status "  Admin:    https://eks-admin.sandee.com"