#!/bin/bash

echo "🔍 Final Configuration Validator - Functionality & Performance Check"
echo "=================================================================="
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

echo "🔧 CONFIGURATION VALIDATION"
echo "==========================="

# Check critical environment variables
print_status "Checking backend environment variables..."

BACKEND_ENV=$(kubectl get deployment sandee-backend -n sandee-production -o jsonpath='{.spec.template.spec.containers[0].env[*].name}' 2>/dev/null)

if echo "$BACKEND_ENV" | grep -q "NODE_ENV"; then
    print_success "NODE_ENV configured"
else
    print_error "NODE_ENV missing"
fi

if echo "$BACKEND_ENV" | grep -q "PORT"; then
    print_success "PORT configured"
else
    print_error "PORT missing"
fi

if echo "$BACKEND_ENV" | grep -q "REDIS_URL"; then
    print_success "REDIS_URL configured"
else
    print_error "REDIS_URL missing"
fi

if echo "$BACKEND_ENV" | grep -q "ELASTIC_URL"; then
    print_success "ELASTIC_URL configured"
else
    print_error "ELASTIC_URL missing"
fi

# Check resource allocation
print_status "Checking resource allocation..."

FRONTEND_CPU=$(kubectl get deployment sandee-frontend -n sandee-production -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
FRONTEND_MEMORY=$(kubectl get deployment sandee-frontend -n sandee-production -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null)
BACKEND_CPU=$(kubectl get deployment sandee-backend -n sandee-production -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
BACKEND_MEMORY=$(kubectl get deployment sandee-backend -n sandee-production -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null)

print_status "Frontend: $FRONTEND_CPU CPU, $FRONTEND_MEMORY memory"
print_status "Backend: $BACKEND_CPU CPU, $BACKEND_MEMORY memory"

# Check HPA configuration
print_status "Checking HPA configuration..."

FRONTEND_HPA=$(kubectl get hpa sandee-frontend-hpa -n sandee-production -o jsonpath='{.spec.minReplicas}/{.spec.maxReplicas}' 2>/dev/null)
BACKEND_HPA=$(kubectl get hpa sandee-backend-hpa -n sandee-production -o jsonpath='{.spec.minReplicas}/{.spec.maxReplicas}' 2>/dev/null)

if [ ! -z "$FRONTEND_HPA" ]; then
    print_success "Frontend HPA: $FRONTEND_HPA replicas"
else
    print_error "Frontend HPA not found"
fi

if [ ! -z "$BACKEND_HPA" ]; then
    print_success "Backend HPA: $BACKEND_HPA replicas"
else
    print_error "Backend HPA not found"
fi

echo ""
echo "🌐 ALB & HTTP/2 VALIDATION"
echo "=========================="

# Check ALB configuration
FRONTEND_HTTP2=$(kubectl get ingress sandee-frontend-ingress -n sandee-production -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/load-balancer-attributes}' 2>/dev/null | grep -o "routing.http2.enabled=true")
BACKEND_HTTP2=$(kubectl get ingress sandee-backend-ingress -n sandee-production -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/load-balancer-attributes}' 2>/dev/null | grep -o "routing.http2.enabled=true")

if [ "$FRONTEND_HTTP2" = "routing.http2.enabled=true" ]; then
    print_success "Frontend HTTP/2 enabled"
else
    print_error "Frontend HTTP/2 not enabled"
fi

if [ "$BACKEND_HTTP2" = "routing.http2.enabled=true" ]; then
    print_success "Backend HTTP/2 enabled"
else
    print_error "Backend HTTP/2 not enabled"
fi

echo ""
echo "📊 MEMORY BUFFER ANALYSIS"
echo "========================="

# Calculate memory usage
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
print_status "Node count: $NODE_COUNT"

if [ "$NODE_COUNT" -ge 5 ]; then
    TOTAL_MEMORY=$((NODE_COUNT * 16))
    print_status "Total cluster memory: ${TOTAL_MEMORY}GB"
    
    # Calculate pod memory requests
    FRONTEND_REPLICAS=$(kubectl get deployment sandee-frontend -n sandee-production -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    BACKEND_REPLICAS=$(kubectl get deployment sandee-backend -n sandee-production -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    REDIS_REPLICAS=$(kubectl get statefulset redis -n sandee-production -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    ES_REPLICAS=$(kubectl get statefulset elasticsearch -n sandee-production -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    
    # Convert memory to GB (approximate)
    FRONTEND_MEM_GB=$((FRONTEND_REPLICAS * 1))  # 512Mi ≈ 0.5GB, rounded up
    BACKEND_MEM_GB=$((BACKEND_REPLICAS * 1))    # 1Gi = 1GB
    REDIS_MEM_GB=$((REDIS_REPLICAS * 2))        # 2Gi = 2GB
    ES_MEM_GB=$((ES_REPLICAS * 2))              # 2Gi = 2GB
    
    TOTAL_USED=$((FRONTEND_MEM_GB + BACKEND_MEM_GB + REDIS_MEM_GB + ES_MEM_GB))
    MEMORY_BUFFER=$((TOTAL_MEMORY - TOTAL_USED))
    
    print_status "Memory usage breakdown:"
    print_status "  Frontend: ${FRONTEND_REPLICAS} pods × 0.5GB = ${FRONTEND_MEM_GB}GB"
    print_status "  Backend: ${BACKEND_REPLICAS} pods × 1GB = ${BACKEND_MEM_GB}GB"
    print_status "  Redis: ${REDIS_REPLICAS} pods × 2GB = ${REDIS_MEM_GB}GB"
    print_status "  Elasticsearch: ${ES_REPLICAS} pods × 2GB = ${ES_MEM_GB}GB"
    print_status "  Total used: ${TOTAL_USED}GB"
    print_status "  Memory buffer: ${MEMORY_BUFFER}GB"
    
    if [ "$MEMORY_BUFFER" -ge 75 ]; then
        print_success "Memory buffer adequate (${MEMORY_BUFFER}GB ≥ 75GB required)"
    else
        print_warning "Memory buffer insufficient (${MEMORY_BUFFER}GB < 75GB required)"
    fi
else
    print_warning "Insufficient nodes for memory buffer analysis"
fi

echo ""
echo "🚀 FUNCTIONALITY TESTS"
echo "======================"

# Test pod readiness
print_status "Checking pod readiness..."

FRONTEND_READY=$(kubectl get pods -n sandee-production -l app=sandee-frontend --field-selector=status.phase=Running -o name 2>/dev/null | wc -l)
BACKEND_READY=$(kubectl get pods -n sandee-production -l app=sandee-backend --field-selector=status.phase=Running -o name 2>/dev/null | wc -l)
REDIS_READY=$(kubectl get pods -n sandee-production -l app=redis --field-selector=status.phase=Running -o name 2>/dev/null | wc -l)
ES_READY=$(kubectl get pods -n sandee-production -l app=elasticsearch --field-selector=status.phase=Running -o name 2>/dev/null | wc -l)

print_status "Ready pods:"
print_status "  Frontend: $FRONTEND_READY"
print_status "  Backend: $BACKEND_READY"
print_status "  Redis: $REDIS_READY"
print_status "  Elasticsearch: $ES_READY"

# Test health endpoints
print_status "Testing health endpoints..."

if [ "$FRONTEND_READY" -gt 0 ]; then
    FRONTEND_POD=$(kubectl get pods -n sandee-production -l app=sandee-frontend --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ ! -z "$FRONTEND_POD" ]; then
        FRONTEND_HEALTH=$(kubectl exec -n sandee-production $FRONTEND_POD -- curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health 2>/dev/null || echo "000")
        if [ "$FRONTEND_HEALTH" = "200" ]; then
            print_success "Frontend health check: OK"
        else
            print_warning "Frontend health check: HTTP $FRONTEND_HEALTH"
        fi
    fi
fi

if [ "$BACKEND_READY" -gt 0 ]; then
    BACKEND_POD=$(kubectl get pods -n sandee-production -l app=sandee-backend --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ ! -z "$BACKEND_POD" ]; then
        BACKEND_HEALTH=$(kubectl exec -n sandee-production $BACKEND_POD -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8008/health 2>/dev/null || echo "000")
        if [ "$BACKEND_HEALTH" = "200" ]; then
            print_success "Backend health check: OK"
        else
            print_warning "Backend health check: HTTP $BACKEND_HEALTH"
        fi
    fi
fi

echo ""
echo "📋 FINAL SUMMARY"
echo "================"

# Count successful checks
CHECKS_PASSED=0
TOTAL_CHECKS=10

# Environment variables (4 checks)
if echo "$BACKEND_ENV" | grep -q "NODE_ENV"; then ((CHECKS_PASSED++)); fi
if echo "$BACKEND_ENV" | grep -q "PORT"; then ((CHECKS_PASSED++)); fi
if echo "$BACKEND_ENV" | grep -q "REDIS_URL"; then ((CHECKS_PASSED++)); fi
if echo "$BACKEND_ENV" | grep -q "ELASTIC_URL"; then ((CHECKS_PASSED++)); fi

# HPA (2 checks)
if [ ! -z "$FRONTEND_HPA" ]; then ((CHECKS_PASSED++)); fi
if [ ! -z "$BACKEND_HPA" ]; then ((CHECKS_PASSED++)); fi

# HTTP/2 (2 checks)
if [ "$FRONTEND_HTTP2" = "routing.http2.enabled=true" ]; then ((CHECKS_PASSED++)); fi
if [ "$BACKEND_HTTP2" = "routing.http2.enabled=true" ]; then ((CHECKS_PASSED++)); fi

# Health checks (2 checks)
if [ "$FRONTEND_HEALTH" = "200" ]; then ((CHECKS_PASSED++)); fi
if [ "$BACKEND_HEALTH" = "200" ]; then ((CHECKS_PASSED++)); fi

print_status "Validation Score: $CHECKS_PASSED/$TOTAL_CHECKS checks passed"

if [ "$CHECKS_PASSED" -eq "$TOTAL_CHECKS" ]; then
    print_success "🎉 All validations passed! Configuration is optimal for functionality and performance."
elif [ "$CHECKS_PASSED" -ge 8 ]; then
    print_warning "⚠️  Most validations passed. Minor issues detected."
else
    print_error "❌ Several validations failed. Please review the configuration."
fi

echo ""
echo "🎯 RECOMMENDATIONS:"
if [ "$MEMORY_BUFFER" -lt 75 ]; then
    echo "• Add more m6i.xlarge nodes to meet memory buffer requirements"
fi
if [ "$FRONTEND_HEALTH" != "200" ] || [ "$BACKEND_HEALTH" != "200" ]; then
    echo "• Check application logs for health endpoint issues"
fi
if [ "$FRONTEND_HTTP2" != "routing.http2.enabled=true" ]; then
    echo "• Verify ALB provisioning and HTTP/2 configuration"
fi
echo "• Monitor with: kubectl get hpa -n sandee-production -w"
echo "• Check memory usage: kubectl top nodes"
