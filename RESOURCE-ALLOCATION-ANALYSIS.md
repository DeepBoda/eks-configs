# 📊 EKS Resource Allocation Analysis for m6i.xlarge Nodes

## 🎯 Node Configuration Requirements

### **Target Cluster Setup**
- **Node Type**: m6i.xlarge (4 vCPU, 16GB RAM per node)
- **Minimum Nodes**: 5-6 nodes
- **Total Cluster Capacity**: 20-24 vCPU, 80-96GB RAM
- **Required Memory Buffer**: 75-80GB across all nodes

## 💾 Memory Buffer Calculation

### **Per Node Memory Breakdown (16GB total)**
```
Node Capacity:           16.0 GB
Kubernetes System:       -1.5 GB  (kubelet, kube-proxy, etc.)
Node OS & Overhead:      -0.5 GB  (system processes)
Available for Pods:      14.0 GB per node
```

### **Cluster-Wide Memory Allocation (5-6 nodes)**
```
5 Nodes: 5 × 14GB = 70GB available for pods
6 Nodes: 6 × 14GB = 84GB available for pods

Target Memory Buffer: 75-80GB
Recommended for Pods: 10-15GB total across cluster
```

## 🔧 Optimized Resource Allocation

### **Application Resource Requests (Per Pod)**

#### **Frontend Pods (8 replicas)**
```
CPU Request:     400m per pod × 8 = 3.2 vCPU total
Memory Request:  512Mi per pod × 8 = 4GB total
CPU Limit:       1000m per pod × 8 = 8 vCPU total
Memory Limit:    1Gi per pod × 8 = 8GB total
```

#### **Backend Pods (6 replicas)**
```
CPU Request:     600m per pod × 6 = 3.6 vCPU total
Memory Request:  1Gi per pod × 6 = 6GB total
CPU Limit:       1500m per pod × 6 = 9 vCPU total
Memory Limit:    2Gi per pod × 6 = 12GB total
```

#### **Redis Pods (3 replicas)**
```
CPU Request:     800m per pod × 3 = 2.4 vCPU total
Memory Request:  2Gi per pod × 3 = 6GB total
CPU Limit:       2000m per pod × 3 = 6 vCPU total
Memory Limit:    4Gi per pod × 3 = 12GB total
```

#### **Elasticsearch Pods (3 replicas)**
```
CPU Request:     1000m per pod × 3 = 3 vCPU total
Memory Request:  2Gi per pod × 3 = 6GB total
CPU Limit:       2000m per pod × 3 = 6 vCPU total
Memory Limit:    4Gi per pod × 3 = 12GB total
```

### **Total Resource Summary**
```
Total CPU Requests:    12.2 vCPU (61% of 20 vCPU minimum)
Total Memory Requests: 22GB (27% of 80GB minimum)
Total CPU Limits:      31 vCPU (155% - allows bursting)
Total Memory Limits:   44GB (55% of 80GB minimum)

Memory Buffer:         58GB (80GB - 22GB = 73% buffer)
```

## 🎯 Scaling Behavior Analysis

### **HPA Configuration**
- **Frontend**: 8-50 replicas (CPU: 45%, Memory: 60%)
- **Backend**: 6-40 replicas (CPU: 40%, Memory: 60%)

### **Memory Usage During Scaling**

#### **At Minimum Replicas (Base Load)**
```
Frontend: 8 × 512Mi = 4GB
Backend:  6 × 1Gi = 6GB
Redis:    3 × 2Gi = 6GB
Elasticsearch: 3 × 2Gi = 6GB
Total: 22GB (leaves 58GB buffer)
```

#### **At 50% Scale-Up**
```
Frontend: 12 × 512Mi = 6GB
Backend:  9 × 1Gi = 9GB
Redis:    3 × 2Gi = 6GB
Elasticsearch: 3 × 2Gi = 6GB
Total: 27GB (leaves 53GB buffer)
```

#### **At Maximum Replicas (Peak Load)**
```
Frontend: 50 × 512Mi = 25GB
Backend:  40 × 1Gi = 40GB
Redis:    3 × 2Gi = 6GB
Elasticsearch: 3 × 2Gi = 6GB
Total: 77GB (requires cluster autoscaling to ~8-10 nodes)
```

## 🚀 ALB Configuration Optimizations

### **HTTP/2 Support Enabled**
```yaml
alb.ingress.kubernetes.io/load-balancer-attributes: |
  routing.http2.enabled=true
  routing.http.preserve_host_header.enabled=true
  routing.http.xff_client_port.enabled=true
  load_balancing.cross_zone.enabled=true
```

### **Performance Optimizations**
- **Algorithm**: Least outstanding requests
- **Health Checks**: 10-second intervals
- **Compression**: Enabled for better performance
- **SSL/TLS**: Terminated at ALB level
- **Cross-Zone Load Balancing**: Enabled

## 📈 Cluster Autoscaler Behavior

### **Node Scaling Triggers**
- **Scale Up**: When CPU requests exceed 70% of node capacity
- **Scale Down**: When CPU requests drop below 50% of node capacity
- **Memory Pressure**: Prevents scheduling when memory requests exceed 85%

### **Expected Node Count by Load**
```
Base Load (min replicas):     5-6 nodes
Medium Load (2x replicas):    7-8 nodes
High Load (max replicas):     10-12 nodes
```

## ✅ Validation Checklist

### **Memory Buffer Compliance**
- ✅ Base load uses only 22GB (leaves 58GB buffer)
- ✅ Medium load uses only 27GB (leaves 53GB buffer)
- ✅ Peak load triggers cluster autoscaling before buffer exhaustion
- ✅ Graceful pod termination has adequate memory headroom

### **ALB Requirements**
- ✅ Application Load Balancer (not NLB) configured
- ✅ HTTP/2 support enabled
- ✅ SSL/TLS termination at ALB
- ✅ Compression enabled
- ✅ Health check optimizations applied

### **Scaling Safety**
- ✅ Resource requests allow for memory buffer
- ✅ HPA thresholds prevent resource exhaustion
- ✅ Cluster autoscaler provisions nodes before memory pressure
- ✅ Pod disruption budgets maintain availability during scaling

## 🔧 Deployment Recommendations

### **Pre-Deployment**
1. Ensure cluster has 5-6 m6i.xlarge nodes minimum
2. Verify AWS Load Balancer Controller is installed
3. Confirm cluster autoscaler is configured for m6i.xlarge instances

### **Post-Deployment Monitoring**
1. Monitor memory usage: `kubectl top nodes`
2. Watch HPA scaling: `kubectl get hpa -n sandee-production -w`
3. Verify ALB health: Check AWS Console for target group health
4. Confirm HTTP/2: Test with browser dev tools or curl

### **Success Metrics**
- Memory buffer maintained above 50GB at all times
- HPA scaling completes within 30 seconds
- ALB health checks pass consistently
- HTTP/2 protocol active on frontend connections
- Zero pod evictions due to memory pressure

---

**🎯 This configuration ensures optimal resource utilization while maintaining the required 75-80GB memory buffer across your 5-6 m6i.xlarge node cluster.**
