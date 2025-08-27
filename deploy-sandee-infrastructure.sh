#!/bin/bash

# Sandee EKS Infrastructure Deployment Script
# This script deploys the complete Sandee application infrastructure on EKS

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="sandee"
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="838645860193"

# Function to print colored output
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

# Function to check if command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

# Function to wait for deployment to be ready
wait_for_deployment() {
    local deployment=$1
    local namespace=$2
    local timeout=${3:-300}
    
    print_status "Waiting for deployment $deployment in namespace $namespace to be ready..."
    if kubectl wait --for=condition=Available deployment/$deployment -n $namespace --timeout=${timeout}s; then
        print_success "Deployment $deployment is ready"
    else
        print_error "Deployment $deployment failed to become ready within ${timeout}s"
        return 1
    fi
}

# Function to wait for pods to be ready
wait_for_pods() {
    local label=$1
    local namespace=$2
    local timeout=${3:-600}
    
    print_status "Waiting for pods with label $label in namespace $namespace to be ready..."
    if kubectl wait --for=condition=Ready pod -l $label -n $namespace --timeout=${timeout}s; then
        print_success "Pods with label $label are ready"
    else
        print_error "Pods with label $label failed to become ready within ${timeout}s"
        return 1
    fi
}

# Function to check if namespace exists and is active
# Function to check if namespace exists and is active
wait_for_namespace() {
    local namespace=$1
    local timeout=${2:-60}
    local start_time=$(date +%s)

    print_status "Waiting for namespace $namespace to be active..."

    while true; do
        phase=$(kubectl get ns $namespace -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
        if [[ "$phase" == "Active" ]]; then
            print_success "Namespace $namespace is active"
            return 0
        fi

        now=$(date +%s)
        if (( now - start_time > timeout )); then
            print_error "Namespace $namespace failed to become active within ${timeout}s (phase: $phase)"
            return 1
        fi

        sleep 2
    done
}


# Pre-flight checks
print_status "Starting Sandee EKS Infrastructure Deployment"
print_status "=========================================="

print_status "Performing pre-flight checks..."

# Check required commands
check_command kubectl
check_command aws


# Check kubectl connection
print_status "Checking kubectl connection to cluster..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubectl configuration."
    exit 1
fi

# Verify cluster name
CURRENT_CLUSTER=$(kubectl config current-context | cut -d'/' -f2 2>/dev/null || echo "unknown")
print_status "Current cluster context: $CURRENT_CLUSTER"

# Check if EKS cluster exists
print_status "Verifying EKS cluster '$CLUSTER_NAME' exists..."
if ! aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION &> /dev/null; then
    print_error "EKS cluster '$CLUSTER_NAME' not found in region $AWS_REGION"
    exit 1
fi

print_success "Pre-flight checks completed successfully"


print_status "=========================================="
print_status "Phase 1: Core Infrastructure"
print_status "=========================================="

# 1. Apply namespaces
print_status "Creating namespaces..."
kubectl apply -f 00-namespaces.yaml

# Wait for namespaces to be ready
wait_for_namespace "sandee"
wait_for_namespace "ingress-nginx"
wait_for_namespace "aws-load-balancer-controller"

# 2. Apply storage classes
print_status "Creating storage classes..."
kubectl apply -f 01-storage-classes.yaml

# 3. Apply RBAC and IRSA
print_status "Configuring RBAC and IRSA..."
kubectl apply -f 02-rbac-irsa.yaml

print_success "Phase 1 completed successfully"

print_status "=========================================="
print_status "Phase 2: Infrastructure Components"
print_status "=========================================="

# 4. Deploy cluster autoscaler
print_status "Deploying Cluster Autoscaler..."
kubectl apply -f 03-cluster-autoscaler.yaml
wait_for_deployment "cluster-autoscaler" "kube-system"

# 5. Deploy AWS Load Balancer Controller
print_status "Deploying AWS Load Balancer Controller..."
kubectl apply -f 04-aws-load-balancer-controller.yaml
wait_for_deployment "aws-load-balancer-controller" "aws-load-balancer-controller"

# 6. Deploy NGINX Ingress Controller
print_status "Deploying NGINX Ingress Controller..."
kubectl apply -f 05-ingress-nginx.yaml
wait_for_deployment "ingress-nginx-controller" "ingress-nginx"

print_success "Phase 2 completed successfully"

print_status "=========================================="
print_status "Phase 3: Database Layer"
print_status "=========================================="

# 7. Deploy Redis StatefulSet
print_status "Deploying Redis cluster..."
kubectl apply -f 06-redis-statefulset.yaml
wait_for_pods "app=redis" "sandee" 600

# 8. Deploy Elasticsearch cluster
print_status "Deploying Elasticsearch cluster..."
kubectl apply -f 07-elasticsearch-cluster.yaml
wait_for_pods "app=elasticsearch" "sandee" 600

print_success "Phase 3 completed successfully"

print_status "=========================================="
print_status "Phase 4: Application Layer"
print_status "=========================================="

# 9. Deploy applications
print_status "Deploying application services..."
kubectl apply -f 08-application-deployments.yaml

# Wait for applications to be ready
wait_for_deployment "sandee-frontend" "sandee"
wait_for_deployment "sandee-backend" "sandee"
wait_for_deployment "sandee-admin" "sandee"
wait_for_deployment "sandee-cron" "sandee"

# 10. Create services
print_status "Creating Kubernetes services..."
kubectl apply -f 09-services.yaml

print_success "Phase 4 completed successfully"

print_status "=========================================="
print_status "Phase 5: Networking and Scaling"
print_status "=========================================="

# 11. Configure ingress resources
print_status "Configuring ingress resources..."
kubectl apply -f 10-ingress-resources.yaml

# 12. Configure HPA
print_status "Configuring Horizontal Pod Autoscalers..."
kubectl apply -f 11-hpa-configurations.yaml

# 13. Configure Pod Disruption Budgets
print_status "Configuring Pod Disruption Budgets..."
kubectl apply -f 12-pod-disruption-budgets.yaml

print_success "Phase 5 completed successfully"

print_status "=========================================="
print_status "Deployment Verification"
print_status "=========================================="

# Verification
print_status "Verifying deployment status..."

echo ""
print_status "Checking pods in sandee namespace:"
kubectl get pods -n sandee

echo ""
print_status "Checking services in sandee namespace:"
kubectl get svc -n sandee

echo ""
print_status "Checking ingress resources:"
kubectl get ingress -n sandee

echo ""
print_status "Checking HPA status:"
kubectl get hpa -n sandee

echo ""
print_status "Checking Pod Disruption Budgets:"
kubectl get pdb -n sandee

echo ""
print_status "Checking storage:"
kubectl get pvc -n sandee
kubectl get storageclass

echo ""
print_status "Checking infrastructure pods:"
kubectl get pods -n ingress-nginx
kubectl get pods -n aws-load-balancer-controller
kubectl get pods -n kube-system | grep cluster-autoscaler

print_status "=========================================="
print_success "Sandee EKS Infrastructure Deployment Complete!"
print_status "=========================================="

print_status "Next Steps:"
echo "1. Update DNS records to point to the Load Balancer endpoints"
echo "2. Verify SSL certificates are properly configured"
echo "3. Test application endpoints:"
echo "   - https://sandee.com (Frontend)"
echo "   - https://admin.sandee.com (Admin Panel)"
echo "   - https://api.sandee.com/api (Backend API)"
echo "4. Monitor application logs and metrics"
echo "5. Set up backup strategies for databases"

print_status "For troubleshooting, check the README.md file"

print_success "Deployment script completed successfully!"
