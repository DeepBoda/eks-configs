#!/bin/bash

echo "🔧 Quick Fix and Deploy"
echo "======================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi

print_status "Fixing StatefulSet issues..."

# Delete old storage class if exists
print_status "Cleaning up old storage class..."
kubectl delete storageclass gp3-production 2>/dev/null || true

# For StatefulSets, we need to update only the allowed fields
print_status "Updating StatefulSets (template only)..."

# Update Redis StatefulSet template only
kubectl patch statefulset redis -n sandee-production --type='merge' -p='{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "redis",
          "resources": {
            "requests": {
              "cpu": "500m",
              "memory": "1Gi"
            },
            "limits": {
              "cpu": "1",
              "memory": "2Gi"
            }
          },
          "env": [{
            "name": "REDIS_ARGS",
            "value": "--appendonly yes --maxmemory 2gb --maxmemory-policy allkeys-lru"
          }, {
            "name": "REDIS_REPLICATION_MODE",
            "value": "master"
          }]
        }]
      }
    }
  }
}' 2>/dev/null || print_warning "Redis StatefulSet patch failed (may not exist yet)"

# Update Elasticsearch StatefulSet template only
kubectl patch statefulset elasticsearch -n sandee-production --type='merge' -p='{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "elasticsearch",
          "resources": {
            "requests": {
              "cpu": "500m",
              "memory": "1Gi"
            },
            "limits": {
              "cpu": "1",
              "memory": "2Gi"
            }
          },
          "env": [{
            "name": "ES_JAVA_OPTS",
            "value": "-Xms1g -Xmx1g"
          }]
        }]
      }
    }
  }
}' 2>/dev/null || print_warning "Elasticsearch StatefulSet patch failed (may not exist yet)"

# Apply the rest of the configuration
print_status "Applying updated configuration..."
kubectl apply -f production-manifests.yaml

# Check deployment status
print_status "Checking deployment status..."
kubectl get pods -n sandee-production

print_status "Checking HPA status..."
kubectl get hpa -n sandee-production

print_status "✅ Deployment complete!"
print_status "Monitor with: kubectl get pods -n sandee-production -w"
