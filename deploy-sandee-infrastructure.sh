#!/usr/bin/env bash
set -euo pipefail

# Sandee EKS Infrastructure Deployment Script
# This script deploys the complete Sandee application infrastructure on EKS from scratch.

# --- Configuration ---
CLUSTER_NAME="sandee"
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# --- Colors for output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Helper Functions ---
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

check_command() {
  if ! command -v "$1" &> /dev/null; then
    print_error "Required command '$1' is not installed. Please install it and try again."
  fi
}

wait_for_deployment() {
  local name="$1"
  local ns="$2"
  local timeout="${3:-600}"
  print_status "Waiting up to ${timeout}s for deployment '$name' in namespace '$ns' to become available..."
  if ! kubectl wait --for=condition=Available "deployment/$name" -n "$ns" --timeout="${timeout}s"; then
    print_error "Deployment '$name' did not become ready within ${timeout}s."
  fi
  print_success "Deployment '$name' is ready."
}

wait_for_pods() {
  local label="$1"
  local ns="$2"
  local timeout="${3:-600}"
  print_status "Waiting up to ${timeout}s for pods with label '$label' in namespace '$ns' to be ready..."
  if ! kubectl wait --for=condition=Ready pod -l "$label" -n "$ns" --timeout="${timeout}s"; then
    print_error "Pods with label '$label' did not become ready within ${timeout}s."
  fi
  print_success "Pods with label '$label' are ready."
}

# --- Main Execution ---
print_status "Starting Sandee EKS Infrastructure Deployment"
print_status "=========================================="

# 1. Pre-flight Checks
print_status "Phase 1: Pre-flight Checks"
for cmd in kubectl aws helm; do check_command "$cmd"; done
print_status "Verifying kubectl connectivity..."
kubectl cluster-info &> /dev/null || print_error "kubectl cannot connect to the cluster."
print_status "Verifying EKS cluster '$CLUSTER_NAME' exists..."
aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" &> /dev/null || print_error "EKS cluster '$CLUSTER_NAME' not found."
print_success "Pre-flight checks passed."

# 2. Core Infrastructure Setup
print_status "Phase 2: Core Infrastructure (Namespaces, Storage, RBAC)"
kubectl apply -f 00-namespaces.yaml
kubectl apply -f 01-storage-classes.yaml
kubectl apply -f 02-rbac-irsa.yaml
print_success "Core infrastructure applied."

# 3. Infrastructure Components (Autoscaler, Load Balancers, Metrics)
print_status "Phase 3: Infrastructure Components"
kubectl apply -f 03-cluster-autoscaler.yaml
wait_for_deployment "cluster-autoscaler" "kube-system"

VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query "cluster.resourcesVpcConfig.vpcId" --output text)
print_status "Deploying AWS Load Balancer Controller for VPC '$VPC_ID'..."
helm repo add eks https://aws.github.io/eks-charts &> /dev/null
helm repo update &> /dev/null
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n aws-load-balancer-controller --create-namespace \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --wait --timeout 10m
print_success "AWS Load Balancer Controller deployed."

print_status "Deploying ingress-nginx controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx &> /dev/null
helm repo update &> /dev/null
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --create-namespace \
  --set controller.metrics.enabled=true \
  --set controller.config.proxy-body-size="10g" \
  --set controller.config.proxy-connect-timeout="600" \
  --set controller.config.proxy-send-timeout="600" \
  --set controller.config.proxy-read-timeout="600" \
  --set controller.config.use-regex="true" \
  --set controller.config.ssl-redirect="false" \
  --set controller.config.server-tokens="false" \
  --wait --timeout 10m
print_success "ingress-nginx controller deployed."

print_status "Installing metrics-server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
wait_for_deployment "metrics-server" "kube-system"
print_success "Infrastructure components deployed."

# 4. Data Layer (Redis & Elasticsearch)
print_status "Phase 4: Data Layer"
kubectl apply -f 06-redis-statefulset.yaml
kubectl apply -f 07-elasticsearch-secret.yaml
kubectl apply -f 07-elasticsearch-cluster.yaml
wait_for_pods "app=redis" "sandee"
wait_for_pods "app=elasticsearch" "sandee"
print_success "Data layer deployed."

# 5. Application Layer
print_status "Phase 5: Application Layer"
kubectl apply -f 08-application-deployments.yaml
kubectl apply -f 09-services.yaml
wait_for_deployment "sandee-frontend" "sandee"
wait_for_deployment "sandee-backend" "sandee"
wait_for_deployment "sandee-admin" "sandee"
print_success "Application layer deployed."

# 6. Networking, Scaling, and Security
print_status "Phase 6: Networking, Scaling, and Security"
kubectl apply -f 10-ingress-resources.yaml
kubectl apply -f 11-hpa-configurations.yaml
kubectl apply -f 12-pod-disruption-budgets.yaml
kubectl apply -f 13-network-policies.yaml
print_success "Networking, scaling, and security policies applied."

# --- Final Verification ---
print_status "Final Verification..."
kubectl get pods,svc,ingress,hpa,pdb -n sandee
print_success "Deployment script finished successfully!"
