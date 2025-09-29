#!/bin/bash

echo "🔍 EKS Performance Diagnostics - Sandee Production"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check cluster connectivity
print_status "Checking cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi
print_success "Connected to cluster"

echo ""
echo "🏗️  CLUSTER OVERVIEW"
echo "==================="

# Node information
print_status "Node Information:"
kubectl get nodes -o wide
echo ""

# Node resource usage
print_status "Node Resource Usage:"
kubectl top nodes 2>/dev/null || print_warning "Metrics server not available"
echo ""

# Cluster autoscaler status
print_status "Cluster Autoscaler Status:"
kubectl get deployment cluster-autoscaler -n kube-system -o wide 2>/dev/null || print_warning "Cluster autoscaler not found"
echo ""

echo "📊 APPLICATION PERFORMANCE"
echo "=========================="

# Pod status in production namespace
print_status "Pod Status (sandee-production):"
kubectl get pods -n sandee-production -o wide
echo ""

# Resource usage by pods
print_status "Pod Resource Usage:"
kubectl top pods -n sandee-production 2>/dev/null || print_warning "Pod metrics not available"
echo ""

# HPA status
print_status "HPA Status:"
kubectl get hpa -n sandee-production
echo ""

# Service status
print_status "Service Status:"
kubectl get svc -n sandee-production
echo ""

echo "🔧 PERFORMANCE BOTTLENECKS"
echo "=========================="

# Check for pending pods
PENDING_PODS=$(kubectl get pods -n sandee-production --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
if [ "$PENDING_PODS" -gt 0 ]; then
    print_error "Found $PENDING_PODS pending pods"
    kubectl get pods -n sandee-production --field-selector=status.phase=Pending
else
    print_success "No pending pods found"
fi
echo ""

# Check for failed pods
FAILED_PODS=$(kubectl get pods -n sandee-production --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l)
if [ "$FAILED_PODS" -gt 0 ]; then
    print_error "Found $FAILED_PODS failed pods"
    kubectl get pods -n sandee-production --field-selector=status.phase=Failed
else
    print_success "No failed pods found"
fi
echo ""

# Check resource requests vs limits
print_status "Resource Analysis:"
echo "Frontend Pods:"
kubectl get pods -n sandee-production -l app=sandee-frontend -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources.requests.cpu}{"\t"}{.spec.containers[0].resources.requests.memory}{"\t"}{.spec.containers[0].resources.limits.cpu}{"\t"}{.spec.containers[0].resources.limits.memory}{"\n"}{end}' | column -t
echo ""

echo "Backend Pods:"
kubectl get pods -n sandee-production -l app=sandee-backend -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources.requests.cpu}{"\t"}{.spec.containers[0].resources.requests.memory}{"\t"}{.spec.containers[0].resources.limits.cpu}{"\t"}{.spec.containers[0].resources.limits.memory}{"\n"}{end}' | column -t
echo ""

echo "💾 STORAGE PERFORMANCE"
echo "====================="

# PVC status
print_status "Persistent Volume Claims:"
kubectl get pvc -n sandee-production
echo ""

# Storage class information
print_status "Storage Classes:"
kubectl get storageclass
echo ""

echo "🌐 NETWORK PERFORMANCE"
echo "======================"

# Ingress status
print_status "Ingress Status:"
kubectl get ingress -n sandee-production
echo ""

# Service endpoints
print_status "Service Endpoints:"
kubectl get endpoints -n sandee-production
echo ""

echo "📈 SCALING ANALYSIS"
echo "=================="

# Current replica counts vs HPA settings
print_status "Scaling Status:"
for deployment in sandee-frontend sandee-backend; do
    CURRENT_REPLICAS=$(kubectl get deployment $deployment -n sandee-production -o jsonpath='{.status.replicas}' 2>/dev/null)
    READY_REPLICAS=$(kubectl get deployment $deployment -n sandee-production -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    HPA_MIN=$(kubectl get hpa ${deployment}-hpa -n sandee-production -o jsonpath='{.spec.minReplicas}' 2>/dev/null)
    HPA_MAX=$(kubectl get hpa ${deployment}-hpa -n sandee-production -o jsonpath='{.spec.maxReplicas}' 2>/dev/null)
    
    echo "$deployment: $READY_REPLICAS/$CURRENT_REPLICAS replicas (HPA: $HPA_MIN-$HPA_MAX)"
done
echo ""

echo "🚨 PERFORMANCE RECOMMENDATIONS"
echo "=============================="

# Analyze current configuration and provide recommendations
print_status "Analyzing current configuration..."

# Check if nodes are m6i.xlarge as mentioned
NODE_TYPES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.labels.node\.kubernetes\.io/instance-type}' | tr ' ' '\n' | sort | uniq)
echo "Detected node types: $NODE_TYPES"

if echo "$NODE_TYPES" | grep -q "m6i.xlarge"; then
    print_warning "Using m6i.xlarge nodes (4 vCPU, 16GB RAM)"
    print_status "Recommendation: Consider upgrading to m6i.2xlarge or m6i.4xlarge for better performance"
fi

# Check resource utilization
print_status "Resource utilization analysis:"
kubectl top nodes 2>/dev/null | awk 'NR>1 {
    cpu_percent = substr($3, 1, length($3)-1)
    mem_percent = substr($5, 1, length($5)-1)
    if (cpu_percent > 70) print "⚠️  High CPU usage on node " $1 ": " $3
    if (mem_percent > 80) print "⚠️  High memory usage on node " $1 ": " $5
}'

echo ""
print_success "Diagnostics complete!"
echo ""
echo "📋 NEXT STEPS:"
echo "1. Apply performance-optimized-manifests.yaml for better resource allocation"
echo "2. Apply redis-performance-optimized.yaml for improved caching"
echo "3. Apply cluster-autoscaler-optimized.yaml for faster scaling"
echo "4. Monitor the application performance after changes"
echo "5. Consider upgrading node types if CPU/memory usage remains high"
