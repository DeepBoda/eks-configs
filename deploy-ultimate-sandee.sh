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

wait_for_deployment() {
    local name="$1"
    local namespace="$2"
    print_status "Waiting for deployment $name in namespace $namespace..."
    kubectl wait --for=condition=available --timeout=300s "deployment/$name" -n "$namespace" || {
        print_error "Deployment $name failed to become ready"
        kubectl describe deployment "$name" -n "$namespace"
        kubectl logs -l "app=$name" -n "$namespace" --tail=50
        return 1
    }
    print_success "Deployment $name is ready"
}

wait_for_statefulset() {
    local name="$1"
    local namespace="$2"
    local replicas="${3:-1}"
    print_status "Waiting for StatefulSet $name in namespace $namespace..."
    kubectl wait --for=condition=ready --timeout=600s pod -l "app=$name" -n "$namespace" || {
        print_warning "StatefulSet $name may still be starting..."
        kubectl describe statefulset "$name" -n "$namespace"
        kubectl get pods -l "app=$name" -n "$namespace"
    }
}

check_ebs_csi() {
    print_status "Checking EBS CSI Driver..."
    if ! kubectl get pods -n kube-system -l app=ebs-csi-controller | grep -q Running; then
        print_warning "EBS CSI Driver not running, restarting..."
        kubectl delete pods -n kube-system -l app=ebs-csi-controller --force --grace-period=0
        kubectl delete pods -n kube-system -l app=ebs-csi-node --force --grace-period=0
        sleep 30
    fi
    print_success "EBS CSI Driver checked"
}

cleanup_stuck_resources() {
    print_status "Cleaning up stuck resources..."
    
    # Remove old Redis/ES files if they exist
    rm -f 06-redis-statefulset.yaml 07-elasticsearch-cluster.yaml 07-elasticsearch-secret.yaml
    
    # Delete stuck PVCs (graceful)
    kubectl delete pvc --all -n sandee --ignore-not-found=true --timeout=60s
    
    # Delete stuck pods (graceful)
    kubectl delete pods --all -n sandee --ignore-not-found=true --timeout=60s
    
    # Delete old deployments/statefulsets
    kubectl delete statefulset redis -n sandee --ignore-not-found=true
    kubectl delete deployment elasticsearch redis -n sandee --ignore-not-found=true
    
    # Clean up webhooks
    kubectl delete validatingwebhookconfiguration aws-load-balancer-webhook --ignore-not-found=true
    kubectl delete mutatingwebhookconfiguration aws-load-balancer-webhook --ignore-not-found=true
    
    sleep 10
    print_success "Cleanup completed"
}

print_header "🚀 ULTIMATE SANDEE EKS INFRASTRUCTURE DEPLOYMENT"
print_status "Starting deployment with optimized configurations..."

# Phase 0: Cleanup and Preparation
print_header "Phase 0: Cleanup & Preparation"
cleanup_stuck_resources
check_ebs_csi

# Phase 1: Core Infrastructure
print_header "Phase 1: Core Infrastructure"
print_status "Creating namespaces..."
kubectl apply -f 00-namespaces.yaml

print_status "Setting up optimized storage classes..."
kubectl delete storageclass gp3-optimized gp3-redis gp3-elasticsearch redis-high-performance elasticsearch-high-performance --ignore-not-found=true
kubectl apply -f 01-storage-classes.yaml

print_status "Configuring RBAC and IRSA..."
kubectl apply -f 02-rbac-irsa.yaml

# Phase 2: Controllers
print_header "Phase 2: Kubernetes Controllers"

print_status "Deploying Cluster Autoscaler..."
kubectl apply -f 03-cluster-autoscaler.yaml
sleep 10

print_status "Installing AWS Load Balancer Controller via Helm..."
if ! helm repo list | grep -q eks; then
    helm repo add eks https://aws.github.io/eks-charts
fi
helm repo update
helm uninstall aws-load-balancer-controller -n aws-load-balancer-controller 2>/dev/null || true
sleep 5
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n aws-load-balancer-controller \
  --set clusterName=sandee \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-1 \
  --set vpcId=vpc-02f40ee7a414a4512 \
  --wait --timeout=10m

print_status "Deploying NGINX Ingress Controller..."
kubectl apply -f 05-ingress-nginx.yaml
wait_for_deployment "ingress-nginx-controller" "ingress-nginx"

print_status "Installing Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
wait_for_deployment "metrics-server" "kube-system"

# Phase 3: High-Performance Database Layer
print_header "Phase 3: High-Performance Database Layer"

print_status "Deploying Optimized Redis Cluster..."
kubectl apply -f 06-redis-optimized.yaml
wait_for_statefulset "redis" "sandee" 3

print_status "Deploying Optimized Elasticsearch..."
kubectl apply -f 07-elasticsearch-optimized.yaml
wait_for_deployment "elasticsearch" "sandee"

# Phase 4: Application Layer
print_header "Phase 4: Application Layer"

print_status "Deploying Applications..."
kubectl apply -f 08-application-deployments.yaml
wait_for_deployment "sandee-frontend" "sandee"
wait_for_deployment "sandee-backend" "sandee"
wait_for_deployment "sandee-admin" "sandee"

# Phase 5: Networking & Scaling
print_header "Phase 5: Networking & Scaling"

print_status "Creating Services..."
kubectl apply -f 09-services.yaml

print_status "Setting up Ingress Resources..."
kubectl apply -f 10-ingress-resources.yaml

print_status "Configuring HPA and PDB..."
kubectl apply -f 11-hpa-configurations.yaml
kubectl apply -f 12-pod-disruption-budgets.yaml

# Phase 6: Final Verification
print_header "Phase 6: Final Verification & Status"

print_status "Waiting for all pods to be ready..."
sleep 30

echo ""
print_status "=== DEPLOYMENT STATUS ==="
echo ""

print_status "Pods in sandee namespace:"
kubectl get pods -n sandee -o wide

echo ""
print_status "Services in sandee namespace:"
kubectl get svc -n sandee

echo ""
print_status "PersistentVolumeClaims:"
kubectl get pvc -n sandee

echo ""
print_status "Ingress resources:"
kubectl get ingress -n sandee

echo ""
print_status "HPA status:"
kubectl get hpa -n sandee

echo ""
print_status "Storage Classes:"
kubectl get storageclass | grep -E "(redis|elasticsearch|gp3)"

echo ""
print_status "Controller Pods:"
kubectl get pods -n aws-load-balancer-controller
kubectl get pods -n ingress-nginx
kubectl get pods -n kube-system -l app=cluster-autoscaler

echo ""
print_status "Node Information (m6i instances):"
kubectl get nodes -o custom-columns="NAME:.metadata.name,INSTANCE-TYPE:.metadata.labels.node\.kubernetes\.io/instance-type,ZONE:.metadata.labels.topology\.kubernetes\.io/zone,STATUS:.status.conditions[?(@.type=='Ready')].status"

echo ""
print_header "🎉 ULTIMATE SANDEE EKS INFRASTRUCTURE DEPLOYMENT COMPLETE!"
echo ""
print_success "Your high-performance Sandee infrastructure is ready!"
echo ""
print_status "Access your applications at:"
print_status "  🌐 Frontend: https://eks.sandee.com"
print_status "  🔧 Backend:  https://eks-backend.sandee.com"
print_status "  👨‍💼 Admin:    https://eks-admin.sandee.com"
echo ""
print_status "Database Services:"
print_status "  🔴 Redis:         redis-service.sandee.svc.cluster.local:6379"
print_status "  🔍 Elasticsearch: elasticsearch.sandee.svc.cluster.local:9200"
echo ""
print_warning "Remember to:"
print_warning "  - Update DNS records to point to the ALB"
print_warning "  - Monitor resource usage and scale as needed"
print_warning "  - Set up backup strategies for persistent data"
echo ""
print_header "🚀 INFRASTRUCTURE READY FOR PRODUCTION!"