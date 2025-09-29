#!/bin/bash

echo "🚀 Deploying Performance Optimizations for Sandee Production"
echo "============================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
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

# Backup current configuration
print_status "Creating backup of current configuration..."
mkdir -p backups/$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"

kubectl get deployment sandee-frontend -n sandee-production -o yaml > "$BACKUP_DIR/frontend-deployment.yaml" 2>/dev/null
kubectl get deployment sandee-backend -n sandee-production -o yaml > "$BACKUP_DIR/backend-deployment.yaml" 2>/dev/null
kubectl get hpa -n sandee-production -o yaml > "$BACKUP_DIR/hpa-config.yaml" 2>/dev/null
kubectl get statefulset redis -n sandee-production -o yaml > "$BACKUP_DIR/redis-config.yaml" 2>/dev/null
kubectl get statefulset elasticsearch -n sandee-production -o yaml > "$BACKUP_DIR/elasticsearch-config.yaml" 2>/dev/null

print_success "Backup created in $BACKUP_DIR"

# Function to wait for rollout
wait_for_rollout() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    
    print_status "Waiting for $resource_type/$resource_name rollout to complete..."
    if kubectl rollout status $resource_type/$resource_name -n $namespace --timeout=300s; then
        print_success "$resource_type/$resource_name rollout completed"
    else
        print_error "$resource_type/$resource_name rollout failed or timed out"
        return 1
    fi
}

# Deploy optimizations step by step
echo ""
print_status "Step 1: Updating Cluster Autoscaler..."
if kubectl apply -f cluster-autoscaler-optimized.yaml; then
    print_success "Cluster Autoscaler updated"
else
    print_error "Failed to update Cluster Autoscaler"
fi

echo ""
print_status "Step 2: Updating Redis and Elasticsearch..."
if kubectl apply -f redis-performance-optimized.yaml; then
    print_success "Redis and Elasticsearch configurations applied"
    
    # Wait for Redis rollout
    wait_for_rollout "statefulset" "redis" "sandee-production"
    
    # Wait for Elasticsearch rollout
    wait_for_rollout "statefulset" "elasticsearch" "sandee-production"
else
    print_error "Failed to update Redis and Elasticsearch"
fi

echo ""
print_status "Step 3: Updating Application Deployments and HPAs..."
if kubectl apply -f performance-optimized-manifests.yaml; then
    print_success "Application configurations applied"
    
    # Wait for frontend rollout
    wait_for_rollout "deployment" "sandee-frontend" "sandee-production"
    
    # Wait for backend rollout
    wait_for_rollout "deployment" "sandee-backend" "sandee-production"
else
    print_error "Failed to update application configurations"
fi

# Verification
echo ""
print_status "Verifying deployment..."
sleep 30

echo ""
print_status "Current pod status:"
kubectl get pods -n sandee-production

echo ""
print_status "Current HPA status:"
kubectl get hpa -n sandee-production

echo ""
print_status "Current node usage:"
kubectl top nodes 2>/dev/null || print_warning "Metrics server not available"

echo ""
print_status "Current pod usage:"
kubectl top pods -n sandee-production 2>/dev/null || print_warning "Pod metrics not available"

# Performance test
echo ""
print_status "Running basic connectivity tests..."

# Test frontend
FRONTEND_POD=$(kubectl get pods -n sandee-production -l app=sandee-frontend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$FRONTEND_POD" ]; then
    if kubectl exec -n sandee-production $FRONTEND_POD -- curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health 2>/dev/null | grep -q "200"; then
        print_success "Frontend health check passed"
    else
        print_warning "Frontend health check failed"
    fi
fi

# Test backend
BACKEND_POD=$(kubectl get pods -n sandee-production -l app=sandee-backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$BACKEND_POD" ]; then
    if kubectl exec -n sandee-production $BACKEND_POD -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8008/health 2>/dev/null | grep -q "200"; then
        print_success "Backend health check passed"
    else
        print_warning "Backend health check failed"
    fi
fi

# Test Redis
REDIS_POD=$(kubectl get pods -n sandee-production -l app=redis -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$REDIS_POD" ]; then
    if kubectl exec -n sandee-production $REDIS_POD -- redis-cli ping 2>/dev/null | grep -q "PONG"; then
        print_success "Redis connectivity test passed"
    else
        print_warning "Redis connectivity test failed"
    fi
fi

echo ""
print_success "Performance optimizations deployed!"
echo ""
echo "📊 MONITORING RECOMMENDATIONS:"
echo "1. Monitor application response times over the next 30 minutes"
echo "2. Watch HPA scaling behavior: kubectl get hpa -n sandee-production -w"
echo "3. Monitor node resource usage: kubectl top nodes"
echo "4. Check pod resource usage: kubectl top pods -n sandee-production"
echo "5. Run performance-diagnostics.sh for detailed analysis"
echo ""
echo "🔄 ROLLBACK INSTRUCTIONS (if needed):"
echo "kubectl apply -f $BACKUP_DIR/"
echo ""
echo "⚡ EXPECTED IMPROVEMENTS:"
echo "- Faster response times due to increased CPU/memory allocation"
echo "- Better scaling responsiveness with lower HPA thresholds"
echo "- Improved Redis performance with optimized configuration"
echo "- Enhanced Elasticsearch performance with multiple replicas"
echo "- Faster cluster scaling with optimized autoscaler settings"
