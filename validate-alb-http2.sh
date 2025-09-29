#!/bin/bash

echo "🔍 ALB and HTTP/2 Configuration Validator"
echo "========================================"
echo ""

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

echo "🔧 CHECKING ALB CONFIGURATION"
echo "============================="

# Check if AWS Load Balancer Controller is installed
print_status "Checking AWS Load Balancer Controller..."
if kubectl get deployment aws-load-balancer-controller -n kube-system &>/dev/null; then
    print_success "AWS Load Balancer Controller is installed"
    
    # Check controller status
    READY_REPLICAS=$(kubectl get deployment aws-load-balancer-controller -n kube-system -o jsonpath='{.status.readyReplicas}')
    DESIRED_REPLICAS=$(kubectl get deployment aws-load-balancer-controller -n kube-system -o jsonpath='{.spec.replicas}')
    
    if [ "$READY_REPLICAS" = "$DESIRED_REPLICAS" ]; then
        print_success "AWS Load Balancer Controller is ready ($READY_REPLICAS/$DESIRED_REPLICAS)"
    else
        print_warning "AWS Load Balancer Controller not fully ready ($READY_REPLICAS/$DESIRED_REPLICAS)"
    fi
else
    print_error "AWS Load Balancer Controller not found"
    echo "Please install it using: kubectl apply -f 04-aws-load-balancer-controller-complete.yaml"
fi

# Check Ingress configurations
print_status "Checking Ingress configurations..."

# Frontend Ingress
if kubectl get ingress sandee-frontend-ingress -n sandee-production &>/dev/null; then
    print_success "Frontend Ingress found"
    
    # Check ALB annotations
    ALB_SCHEME=$(kubectl get ingress sandee-frontend-ingress -n sandee-production -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/scheme}')
    TARGET_TYPE=$(kubectl get ingress sandee-frontend-ingress -n sandee-production -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/target-type}')
    HTTP2_ENABLED=$(kubectl get ingress sandee-frontend-ingress -n sandee-production -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/load-balancer-attributes}' | grep -o "routing.http2.enabled=true")
    
    if [ "$ALB_SCHEME" = "internet-facing" ]; then
        print_success "Frontend ALB scheme: $ALB_SCHEME"
    else
        print_warning "Frontend ALB scheme: $ALB_SCHEME (expected: internet-facing)"
    fi
    
    if [ "$TARGET_TYPE" = "ip" ]; then
        print_success "Frontend ALB target type: $TARGET_TYPE"
    else
        print_warning "Frontend ALB target type: $TARGET_TYPE (expected: ip)"
    fi
    
    if [ "$HTTP2_ENABLED" = "routing.http2.enabled=true" ]; then
        print_success "Frontend HTTP/2 enabled"
    else
        print_error "Frontend HTTP/2 not enabled"
    fi
else
    print_error "Frontend Ingress not found"
fi

# Backend Ingress
if kubectl get ingress sandee-backend-ingress -n sandee-production &>/dev/null; then
    print_success "Backend Ingress found"
    
    # Check ALB annotations
    ALB_SCHEME=$(kubectl get ingress sandee-backend-ingress -n sandee-production -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/scheme}')
    TARGET_TYPE=$(kubectl get ingress sandee-backend-ingress -n sandee-production -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/target-type}')
    HTTP2_ENABLED=$(kubectl get ingress sandee-backend-ingress -n sandee-production -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/load-balancer-attributes}' | grep -o "routing.http2.enabled=true")
    
    if [ "$ALB_SCHEME" = "internet-facing" ]; then
        print_success "Backend ALB scheme: $ALB_SCHEME"
    else
        print_warning "Backend ALB scheme: $ALB_SCHEME (expected: internet-facing)"
    fi
    
    if [ "$TARGET_TYPE" = "ip" ]; then
        print_success "Backend ALB target type: $TARGET_TYPE"
    else
        print_warning "Backend ALB target type: $TARGET_TYPE (expected: ip)"
    fi
    
    if [ "$HTTP2_ENABLED" = "routing.http2.enabled=true" ]; then
        print_success "Backend HTTP/2 enabled"
    else
        print_error "Backend HTTP/2 not enabled"
    fi
else
    print_error "Backend Ingress not found"
fi

echo ""
echo "📊 RESOURCE ALLOCATION VALIDATION"
echo "================================="

# Check node capacity
print_status "Checking node capacity..."
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
NODE_TYPES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.labels.node\.kubernetes\.io/instance-type}' | tr ' ' '\n' | sort | uniq)

print_status "Node count: $NODE_COUNT"
print_status "Node types: $NODE_TYPES"

if [ "$NODE_COUNT" -ge 5 ]; then
    print_success "Sufficient nodes for memory buffer requirements"
else
    print_warning "Consider adding more nodes for better memory buffer"
fi

# Check memory allocation
print_status "Checking memory allocation..."

# Get pod resource requests
FRONTEND_MEMORY=$(kubectl get deployment sandee-frontend -n sandee-production -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "0")
BACKEND_MEMORY=$(kubectl get deployment sandee-backend -n sandee-production -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "0")
REDIS_MEMORY=$(kubectl get statefulset redis -n sandee-production -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "0")
ES_MEMORY=$(kubectl get statefulset elasticsearch -n sandee-production -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "0")

print_status "Frontend memory request per pod: $FRONTEND_MEMORY"
print_status "Backend memory request per pod: $BACKEND_MEMORY"
print_status "Redis memory request per pod: $REDIS_MEMORY"
print_status "Elasticsearch memory request per pod: $ES_MEMORY"

echo ""
echo "🌐 LOAD BALANCER STATUS"
echo "======================"

# Check ALB status in AWS (if possible)
print_status "Checking ALB status..."

# Get ALB addresses from Ingress
FRONTEND_ALB=$(kubectl get ingress sandee-frontend-ingress -n sandee-production -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
BACKEND_ALB=$(kubectl get ingress sandee-backend-ingress -n sandee-production -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

if [ ! -z "$FRONTEND_ALB" ]; then
    print_success "Frontend ALB provisioned: $FRONTEND_ALB"
    
    # Test HTTP/2 if curl is available
    if command -v curl &> /dev/null; then
        print_status "Testing HTTP/2 support on frontend..."
        HTTP2_TEST=$(curl -s -I --http2 "https://$FRONTEND_ALB" 2>/dev/null | grep -i "HTTP/2" || echo "")
        if [ ! -z "$HTTP2_TEST" ]; then
            print_success "HTTP/2 is working on frontend"
        else
            print_warning "HTTP/2 test failed or not available yet"
        fi
    fi
else
    print_warning "Frontend ALB not yet provisioned"
fi

if [ ! -z "$BACKEND_ALB" ]; then
    print_success "Backend ALB provisioned: $BACKEND_ALB"
    
    # Test HTTP/2 if curl is available
    if command -v curl &> /dev/null; then
        print_status "Testing HTTP/2 support on backend..."
        HTTP2_TEST=$(curl -s -I --http2 "https://$BACKEND_ALB/health" 2>/dev/null | grep -i "HTTP/2" || echo "")
        if [ ! -z "$HTTP2_TEST" ]; then
            print_success "HTTP/2 is working on backend"
        else
            print_warning "HTTP/2 test failed or not available yet"
        fi
    fi
else
    print_warning "Backend ALB not yet provisioned"
fi

echo ""
echo "🎯 VALIDATION SUMMARY"
echo "===================="

# Summary of checks
CHECKS_PASSED=0
TOTAL_CHECKS=8

# Check results
if kubectl get deployment aws-load-balancer-controller -n kube-system &>/dev/null; then
    ((CHECKS_PASSED++))
fi

if kubectl get ingress sandee-frontend-ingress -n sandee-production &>/dev/null; then
    ((CHECKS_PASSED++))
fi

if kubectl get ingress sandee-backend-ingress -n sandee-production &>/dev/null; then
    ((CHECKS_PASSED++))
fi

if [ "$NODE_COUNT" -ge 5 ]; then
    ((CHECKS_PASSED++))
fi

if [ ! -z "$FRONTEND_ALB" ]; then
    ((CHECKS_PASSED++))
fi

if [ ! -z "$BACKEND_ALB" ]; then
    ((CHECKS_PASSED++))
fi

# HTTP/2 checks
FRONTEND_HTTP2=$(kubectl get ingress sandee-frontend-ingress -n sandee-production -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/load-balancer-attributes}' 2>/dev/null | grep -o "routing.http2.enabled=true" || echo "")
BACKEND_HTTP2=$(kubectl get ingress sandee-backend-ingress -n sandee-production -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/load-balancer-attributes}' 2>/dev/null | grep -o "routing.http2.enabled=true" || echo "")

if [ "$FRONTEND_HTTP2" = "routing.http2.enabled=true" ]; then
    ((CHECKS_PASSED++))
fi

if [ "$BACKEND_HTTP2" = "routing.http2.enabled=true" ]; then
    ((CHECKS_PASSED++))
fi

print_status "Validation Score: $CHECKS_PASSED/$TOTAL_CHECKS checks passed"

if [ "$CHECKS_PASSED" -eq "$TOTAL_CHECKS" ]; then
    print_success "All validations passed! Your ALB and HTTP/2 configuration is optimal."
elif [ "$CHECKS_PASSED" -ge 6 ]; then
    print_warning "Most validations passed. Minor issues detected."
else
    print_error "Several validations failed. Please review the configuration."
fi

echo ""
echo "📋 NEXT STEPS:"
echo "1. Monitor ALB provisioning in AWS Console"
echo "2. Test HTTP/2 with browser dev tools"
echo "3. Verify memory buffer with: kubectl top nodes"
echo "4. Check HPA scaling: kubectl get hpa -n sandee-production -w"
