#!/bin/bash

# Define variables
NAMESPACE="sandee"
CHART_NAME="redis-stack"
FOLDER="redis-helm"

echo "🚀 Creating folder structure: $FOLDER"
mkdir -p $FOLDER/templates

echo "📌 Creating Chart.yaml..."
cat <<EOF > $FOLDER/Chart.yaml
apiVersion: v2
name: redis-stack
description: Redis Stack with Master-Replica Setup
type: application
version: 1.0.0
appVersion: "latest"
EOF

echo "📌 Creating values.yaml..."
cat <<EOF > $FOLDER/values.yaml
global:
  storageClass: "redis-storage-class"

architecture: replication  # ✅ Enables Master-Replica setup

auth:
  enabled: false  # No authentication

image:
  repository: redis/redis-stack  # ✅ Use Redis Stack image
  tag: latest

master:
  nameOverride: redis-stack-master  # ✅ Unique name (prevents conflicts)
  persistence:
    enabled: true
    size: 20Gi
  resources:
    requests:
      memory: "2Gi"
      cpu: "500m"
    limits:
      memory: "4Gi"
      cpu: "1000m"

  extraArgs:
    - /opt/redis-stack/etc/redis-stack.conf

  extraVolumes:
    - name: redis-config
      configMap:
        name: redis-config

  extraVolumeMounts:
    - name: redis-config
      mountPath: /opt/redis-stack/etc/redis-stack.conf
      subPath: redis-stack.conf

replica:
  nameOverride: redis-stack-replica  # ✅ Unique name for replicas
  replicaCount: 2  # ✅ Number of replicas (slaves)
  persistence:
    enabled: true
    size: 10Gi
  resources:
    requests:
      memory: "1.5Gi"
      cpu: "300m"
    limits:
      memory: "3Gi"
      cpu: "500m"

service:
  master:
    type: NodePort
    nodePort: 30016  # ✅ Master NodePort
  replica:
    type: NodePort
    nodePort: 30017  # ✅ Replica NodePort
EOF

echo "📌 Creating configmap.yaml..."
cat <<EOF > $FOLDER/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: $NAMESPACE
data:
  redis-stack.conf: |
    bind 0.0.0.0
    protected-mode no
    loadmodule /opt/redis-stack/lib/redisearch.so
    loadmodule /opt/redis-stack/lib/rejson.so
    loadmodule /opt/redis-stack/lib/redisbloom.so
    loadmodule /opt/redis-stack/lib/redistimeseries.so
    maxmemory 6gb
    maxmemory-policy noeviction

    save 60 1000
    save 300 100
    dbfilename dump.rdb
    dir /data

    appendonly yes
    appendfsync everysec
    slowlog-max-len 1024
    hz 100
EOF

echo "📌 Creating service.yaml..."
cat <<EOF > $FOLDER/templates/service.yaml
---
apiVersion: v1
kind: Service
metadata:
  name: redis-stack-master
  namespace: $NAMESPACE
spec:
  type: NodePort
  ports:
    - port: 6379
      targetPort: 6379
      nodePort: 30016
  selector:
    app.kubernetes.io/name: redis-stack-master

---
apiVersion: v1
kind: Service
metadata:
  name: redis-stack-replica
  namespace: $NAMESPACE
spec:
  type: NodePort
  ports:
    - port: 6379
      targetPort: 6379
      nodePort: 30017
  selector:
    app.kubernetes.io/name: redis-stack-replica
EOF

echo "📌 Creating namespace if not exists..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "📌 Applying ConfigMap..."
kubectl apply -f $FOLDER/templates/configmap.yaml -n $NAMESPACE

echo "📌 Adding Helm repo (if not added)..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

echo "📌 Deploying Redis Stack with Helm..."
helm upgrade --install $CHART_NAME ./redis-helm -n $NAMESPACE

echo "📌 Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis-stack-master -n $NAMESPACE --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis-stack-replica -n $NAMESPACE --timeout=300s

echo "📌 Deployment complete. Checking pods..."
kubectl get pods -n $NAMESPACE

echo "📌 Verifying Redis Replication..."
kubectl exec -it $(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=redis-stack-master -o jsonpath='{.items[0].metadata.name}') -n $NAMESPACE -- redis-cli INFO replication

echo "✅ Redis Stack Deployment Completed Successfully!"

