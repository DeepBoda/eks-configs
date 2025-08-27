#!/usr/bin/env bash
set -euo pipefail

# Sandee EKS Infrastructure Deployment Script
# This script deploys the complete Sandee application infrastructure on EKS

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Print an informational message
print_status() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

# Print a success message
print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Print a warning message
print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Print an error message and exit
print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}

# Check that a command exists
check_command() {
  if ! command -v "$1" &> /dev/null; then
    print_error "Required command '$1' is not installed."
  fi
}

# Wait for a deployment to be available
wait_for_deployment() {
  local name="$1"
  local ns="$2"
  local timeout="${3:-300}"
  print_status "Waiting for deployment '$name' in namespace '$ns'..."
  if ! kubectl wait --for=condition=Available \
      "deployment/$name" -n "$ns" --timeout="${timeout}s"; then
    print_error "Deployment '$name' did not become ready within ${timeout}s."
  fi
  print_success "Deployment '$name' is ready."
}

# Wait for pods matching a label to be ready
wait_for_pods() {
  local label="$1"
  local ns="$2"
  local timeout="${3:-600}"
  print_status "Waiting for pods with label '$label' in namespace '$ns'..."
  if ! kubectl wait --for=condition=Ready pod -l "$label" -n "$ns" --timeout="${timeout}s"; then
    print_error "Pods with label '$label' not ready within ${timeout}s."
  fi
  print_success "Pods with label '$label' are ready."
}

# Wait for a namespace to be Active
wait_for_namespace() {
  local ns="$1"
  local timeout="${2:-60}"
  local start
  start=$(date +%s)
  print_status "Waiting for namespace '$ns' to be Active..."
  while true; do
    local phase
    phase=$(kubectl get namespace "$ns" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    if [[ "$phase" == "Active" ]]; then
      print_success "Namespace '$ns' is Active."
      return
    fi
    if (( $(date +%s) - start > timeout )); then
      print_error "Namespace '$ns' did not become Active within ${timeout}s."
    fi
    sleep 2
  done
}

# Load configuration variables
CLUSTER_NAME="sandee"
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="838645860193"

# Main execution
print_status "Starting Sandee EKS Infrastructure Deployment"
print_status "=========================================="

# Pre-flight checks
for cmd in kubectl aws helm; do
  check_command "$cmd"
done

print_status "Verifying kubectl connectivity..."
kubectl cluster-info &> /dev/null || print_error "kubectl cannot connect to cluster."

print_status "Verifying EKS cluster '$CLUSTER_NAME' exists..."
aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" &> /dev/null \
  || print_error "EKS cluster '$CLUSTER_NAME' not found."

print_success "Pre-flight checks passed."

# Phase 1: Core Infrastructure
print_status "Phase 1: Core Infrastructure"
kubectl apply -f 00-namespaces.yaml
wait_for_namespace "sandee"
wait_for_namespace "ingress-nginx"
wait_for_namespace "aws-load-balancer-controller"
kubectl apply -f 01-storage-classes.yaml
kubectl apply -f 02-rbac-irsa.yaml

# Ensure EBS CSI addon is installed (idempotent)
print_status "Ensuring EBS CSI driver addon is installed"
aws eks describe-addon --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" --addon-name aws-ebs-csi-driver >/dev/null 2>&1 \
  && print_status "EBS CSI addon already installed" \
  || aws eks create-addon --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" --addon-name aws-ebs-csi-driver --service-account-role-arn "arn:aws:iam::$AWS_ACCOUNT_ID:role/AmazonEKS_EBS_CSI_DriverRole"
print_success "Phase 1 complete."

# Phase 2: Infrastructure Components
print_status "Phase 2: Infrastructure Components"
kubectl apply -f 03-cluster-autoscaler.yaml
wait_for_deployment "cluster-autoscaler" "kube-system"

# Dynamic values
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
  --query "cluster.resourcesVpcConfig.vpcId" --output text)

print_status "Deploying AWS Load Balancer Controller via Helm"
# Pre-clean potential leftover resources that block Helm ownership
kubectl delete service aws-load-balancer-webhook-service -n aws-load-balancer-controller --ignore-not-found
kubectl delete secret aws-load-balancer-webhook-cert -n aws-load-balancer-controller --ignore-not-found
kubectl delete validatingwebhookconfiguration.admissionregistration.k8s.io aws-load-balancer-webhook --ignore-not-found
kubectl delete mutatingwebhookconfiguration.admissionregistration.k8s.io aws-load-balancer-webhook --ignore-not-found

helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace aws-load-balancer-controller \
  --set installCRDs=true \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set rbac.create=false \
  --set region="$AWS_REGION" \
  --set vpcId="$VPC_ID" \
  --set image.tag=v2.13.4 \
  --atomic \
  --wait \
  --timeout 10m
kubectl rollout status deployment/aws-load-balancer-controller \
  -n aws-load-balancer-controller --timeout=600s

kubectl apply -f 05-ingress-nginx.yaml
wait_for_deployment "ingress-nginx-controller" "ingress-nginx"
print_success "Phase 2 complete."

# Phase 3: Database Layer (external RDS)
print_status "Phase 3: Database Layer"
kubectl apply -f 06-redis-statefulset.yaml
wait_for_pods "app=redis" "sandee"
kubectl apply -f 07-elasticsearch-cluster.yaml
wait_for_pods "app=elasticsearch" "sandee"
print_success "Phase 3 complete."

# Phase 4: Application Layer
print_status "Phase 4: Application Layer"
kubectl apply -f 08-application-deployments.yaml
wait_for_deployment "sandee-frontend" "sandee"
wait_for_deployment "sandee-backend" "sandee"
wait_for_deployment "sandee-admin" "sandee"
wait_for_deployment "sandee-cron" "sandee"
kubectl apply -f 09-services.yaml
print_success "Phase 4 complete."

# Phase 5: Networking and Scaling
print_status "Phase 5: Networking and Scaling"
kubectl apply -f 10-ingress-resources.yaml
kubectl apply -f 11-hpa-configurations.yaml
kubectl apply -f 12-pod-disruption-budgets.yaml
print_success "Phase 5 complete."

# Deployment Verification
print_status "Verifying deployment"
kubectl get pods,svc,ingress,hpa,pdb -n sandee
kubectl get pods -n ingress-nginx
kubectl get pods -n aws-load-balancer-controller
kubectl get pods -n kube-system | grep cluster-autoscaler
print_success "Deployment successful!"
