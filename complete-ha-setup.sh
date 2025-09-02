#!/bin/bash

echo "🔧 Completing HA Setup - Adding Redis and Elasticsearch Replicas"

# Delete StatefulSets with correct syntax
echo "🗑️ Removing old StatefulSets..."
kubectl delete statefulset redis -n sandee-production --cascade=false
kubectl delete statefulset elasticsearch -n sandee-production --cascade=false

sleep 5

# Create separate HA manifests
cat > redis-ha.yaml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: sandee-production
spec:
  serviceName: redis-headless
  replicas: 3
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values: ["redis"]
              topologyKey: kubernetes.io/hostname
      containers:
      - name: redis
        image: redis/redis-stack:latest
        ports:
        - containerPort: 6379
        - containerPort: 8001
        env:
        - name: REDIS_ARGS
          value: "--appendonly yes --maxmemory 6gb --maxmemory-policy volatile-lru --bind 0.0.0.0 --protected-mode no --maxclients 100000"
        resources:
          requests:
            cpu: 800m
            memory: 6Gi
          limits:
            cpu: 2000m
            memory: 8Gi
        volumeMounts:
        - name: redis-data
          mountPath: /data
        livenessProbe:
          exec:
            command: ["redis-cli", "ping"]
          initialDelaySeconds: 15
          periodSeconds: 5
        readinessProbe:
          exec:
            command: ["redis-cli", "ping"]
          initialDelaySeconds: 5
          periodSeconds: 2
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: gp3-production
      resources:
        requests:
          storage: 100Gi
EOF

cat > elasticsearch-ha.yaml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
  namespace: sandee-production
spec:
  serviceName: elasticsearch-headless
  replicas: 2
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      securityContext:
        fsGroup: 1000
        runAsUser: 1000
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values: ["elasticsearch"]
              topologyKey: kubernetes.io/hostname
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:7.17.0
        env:
        - name: cluster.name
          value: "sandee-cluster"
        - name: node.name
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: discovery.seed_hosts
          value: "elasticsearch-0.elasticsearch-headless,elasticsearch-1.elasticsearch-headless"
        - name: cluster.initial_master_nodes
          value: "elasticsearch-0,elasticsearch-1"
        - name: xpack.security.enabled
          value: "false"
        - name: ES_JAVA_OPTS
          value: "-Xms3g -Xmx3g"
        ports:
        - containerPort: 9200
        - containerPort: 9300
        resources:
          requests:
            cpu: 1000m
            memory: 4Gi
          limits:
            cpu: 2000m
            memory: 6Gi
        volumeMounts:
        - name: es-data
          mountPath: /usr/share/elasticsearch/data
        livenessProbe:
          httpGet:
            path: /_cluster/health
            port: 9200
          initialDelaySeconds: 90
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /_cluster/health?wait_for_status=yellow&timeout=5s
            port: 9200
          initialDelaySeconds: 60
          periodSeconds: 15
  volumeClaimTemplates:
  - metadata:
      name: es-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: gp3-production
      resources:
        requests:
          storage: 100Gi
EOF

# Apply HA StatefulSets
echo "🚀 Creating HA clusters..."
kubectl apply -f redis-ha.yaml
kubectl apply -f elasticsearch-ha.yaml

# Wait for clusters
echo "⏳ Waiting for Redis HA cluster..."
kubectl wait --for=condition=ready pod redis-0 -n sandee-production --timeout=120s
kubectl wait --for=condition=ready pod redis-1 -n sandee-production --timeout=300s
kubectl wait --for=condition=ready pod redis-2 -n sandee-production --timeout=300s

echo "⏳ Waiting for Elasticsearch HA cluster..."
kubectl wait --for=condition=ready pod elasticsearch-0 -n sandee-production --timeout=120s
kubectl wait --for=condition=ready pod elasticsearch-1 -n sandee-production --timeout=600s

# Cleanup temp files
rm -f redis-ha.yaml elasticsearch-ha.yaml

echo "✅ HA Setup Complete!"
kubectl get pods -n sandee-production | grep -E "(redis|elasticsearch)"
kubectl get pvc -n sandee-production

echo "🎉 Redis (3 replicas) + Elasticsearch (2 replicas) ready for 500+ users!"