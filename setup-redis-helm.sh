#!/bin/bash

# Define variables
NAMESPACE="sandee"
CHART_NAME="redis-stack-helm"
FOLDER="redis-helm"

echo "🚀 Fixing Redis Stack Deployment Issues..."

# Step 1: Uninstall Existing Helm Deployment (If Exists)
helm uninstall $CHART_NAME -n $NAMESPACE --ignore-not-found=true

# Step 2: Delete any leftover Redis Stack resources
kubectl delete svc redis-stack-master -n $NAMESPACE --ignore-not-found
kubectl delete svc redis-stack-replica -n $NAMESPACE --ignore-not-found
kubectl delete statefulset redis-stack-master -n $NAMESPACE --ignore-not-found
kubectl delete statefulset redis-stack-replica -n $NAMESPACE --ignore-not-found
kubectl delete configmap redis-stack-config -n $NAMESPACE --ignore-not-found
kubectl delete pod -l app.kubernetes.io/name=redis-stack-master -n $NAMESPACE --ignore-not-found
kubectl delete pod -l app.kubernetes.io/name=redis-stack-replica -n $NAMESPACE --ignore-not-found

# Step 3: Create folder structure
mkdir -p $FOLDER/templates

echo "📌 Creating Chart.yaml..."
cat <<EOF > $FOLDER/Chart.yaml
apiVersion: v2
name: redis-stack-helm
description: Redis Stack with Master-Replica Setup
type: application
version: 1.0.0
appVersion: "latest"
EOF

echo "📌 Creating values.yaml..."
cat <<EOF > $FOLDER/values.yaml
global:
  storageClass: "redis-stack-storage-class"

architecture: replication  # ✅ Enables Master-Replica setup

auth:
  enabled: false  # No authentication

image:
  repository: redis/redis-stack  # ✅ Use Redis Stack image
  tag: latest

master:
  nameOverride: redis-stack-master
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
    - name: redis-stack-config
      configMap:
        name: redis-stack-config

  extraVolumeMounts:
    - name: redis-stack-config
      mountPath: /opt/redis-stack/etc/redis-stack.conf
      subPath: redis-stack.conf

replica:
  nameOverride: redis-stack-replica
  replicaCount: 2
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
    nodePort: 31016
  replica:
    type: NodePort
    nodePort: 31017
EOF

echo "📌 Creating configmap.yaml..."
cat <<EOF > $FOLDER/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-stack-config
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/managed-by: Helm
  annotations:
    meta.helm.sh/release-name: redis-stack-helm
    meta.helm.sh/release-namespace: sandee
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

echo "📌 Creating StatefulSet.yaml..."
cat <<EOF > $FOLDER/templates/statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-stack-master
  namespace: $NAMESPACE
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: redis-stack-master
  serviceName: redis-stack-master
  replicas: 1
  template:
    metadata:
      labels:
        app.kubernetes.io/name: redis-stack-master
    spec:
      containers:
        - name: redis-stack
          image: redis/redis-stack:latest
          command: ["redis-server", "/opt/redis-stack/etc/redis-stack.conf"]
          volumeMounts:
            - name: config
              mountPath: /opt/redis-stack/etc/redis-stack.conf
              subPath: redis-stack.conf
      volumes:
        - name: config
          configMap:
            name: redis-stack-config
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-stack-replica
  namespace: $NAMESPACE
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: redis-stack-replica
  serviceName: redis-stack-replica
  replicas: 2
  template:
    metadata:
      labels:
        app.kubernetes.io/name: redis-stack-replica
    spec:
      containers:
        - name: redis-stack
          image: redis/redis-stack:latest
          command: ["redis-server", "/opt/redis-stack/etc/redis-stack.conf"]
          volumeMounts:
            - name: config
              mountPath: /opt/redis-stack/etc/redis-stack.conf
              subPath: redis-stack.conf
      volumes:
        - name: config
          configMap:
            name: redis-stack-config
EOF

echo "📌 Creating namespace if not exists..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "📌 Deploying Redis Stack with Helm..."
helm upgrade --install $CHART_NAME ./$FOLDER -n $NAMESPACE --debug --wait

echo "📌 Verifying Deployment..."
kubectl get pods -n $NAMESPACE
kubectl get statefulsets -n $NAMESPACE
kubectl get svc -n $NAMESPACE

echo "📌 Verifying Redis Replication..."
kubectl exec -it redis-stack-master-0 -n $NAMESPACE -- redis-cli INFO replication

echo "✅ Redis Stack Deployment Completed Successfully!"

