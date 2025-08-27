# 🚀 Sandee EKS Infrastructure - Quick Setup Guide

## ✅ What You Have Now

Your directory now contains **ONLY** the essential files needed for deployment:

```
eks-configs-temp/
├── deploy-sandee-infrastructure.sh    # 🎯 ONE-CLICK DEPLOYMENT SCRIPT
├── consolidated-infrastructure/        # 📁 All K8s configurations
│   ├── 00-namespaces.yaml
│   ├── 01-storage-classes.yaml
│   ├── 02-rbac-irsa.yaml
│   ├── 03-cluster-autoscaler.yaml
│   ├── 04-aws-load-balancer-controller.yaml
│   ├── 05-ingress-nginx.yaml
│   ├── 06-redis-statefulset.yaml
│   ├── 07-elasticsearch-cluster.yaml
│   ├── 08-application-deployments.yaml
│   ├── 09-services.yaml
│   ├── 10-ingress-resources.yaml
│   ├── 11-hpa-configurations.yaml
│   ├── 12-pod-disruption-budgets.yaml
│   └── README.md
└── QUICK-SETUP.md                     # 📖 This guide
```

## 🎯 ONE-COMMAND DEPLOYMENT

### Prerequisites (Do Once)

```bash
# 1. Ensure you have kubectl and aws CLI installed
kubectl version --client
aws --version

# 2. Configure kubectl for your EKS cluster
aws eks update-kubeconfig --region us-east-1 --name sandee

# 3. Verify connection
kubectl cluster-info
```

### 🚀 Deploy Everything

```bash
# Run the automated deployment script
./deploy-sandee-infrastructure.sh
```

**That's it!** The script will:

- ✅ Perform pre-flight checks
- ✅ Deploy all infrastructure in the correct order
- ✅ Wait for each component to be ready
- ✅ Verify the deployment
- ✅ Show you the final status

## 📋 What Gets Deployed

### 🏗️ Infrastructure

- **Namespaces**: sandee, ingress-nginx, aws-load-balancer-controller
- **Storage**: GP3 optimized storage classes with performance tuning
- **RBAC**: Service accounts with IRSA for secure AWS access
- **Autoscaling**: Cluster autoscaler with advanced policies

### 🌐 Networking

- **AWS Load Balancer Controller**: For ALB ingress
- **NGINX Ingress Controller**: For internal routing with HTTP/2
- **Ingress Resources**: Rate limiting, SSL termination, security headers

### 🗄️ Databases

- **Redis Cluster**: 3-node StatefulSet with HA and persistence
- **Elasticsearch Cluster**: 3-node cluster with optimization
- **PostgreSQL**: Single instance with persistent storage

### 🚀 Applications

- **Frontend**: Next.js app with auto-scaling (2-10 replicas)
- **Backend**: Node.js API with auto-scaling (3-15 replicas)
- **Admin Panel**: Admin interface with auto-scaling (2-8 replicas)
- **Cron Jobs**: Background processing (1-5 replicas)

### 📊 Scaling & Availability

- **HPA**: CPU and memory-based autoscaling for all services
- **Pod Disruption Budgets**: Ensures high availability during updates
- **Anti-Affinity**: Distributes pods across nodes and AZs

## 🔧 Customization (If Needed)

Before running the script, you may need to update:

1. **IAM Role ARNs** in `consolidated-infrastructure/02-rbac-irsa.yaml`
2. **VPC/Subnet IDs** in `consolidated-infrastructure/10-ingress-resources.yaml`
3. **Domain names** in ingress configurations
4. **AWS Account ID** in `deploy-sandee-infrastructure.sh` (line 12)

## 🎯 Post-Deployment

After successful deployment:

1. **Get Load Balancer URLs**:

   ```bash
   kubectl get ingress -n sandee
   kubectl get svc -n ingress-nginx
   ```

2. **Update DNS Records**:

   - Point `sandee.com` to ALB endpoint
   - Point `admin.sandee.com` to NLB endpoint

3. **Test Endpoints**:

   - https://sandee.com (Frontend)
   - https://admin.sandee.com (Admin)
   - https://api.sandee.com/api (Backend API)

4. **Monitor**:
   ```bash
   kubectl get pods -n sandee
   kubectl get hpa -n sandee
   kubectl top pods -n sandee
   ```

## 🛠️ Troubleshooting

If something goes wrong:

```bash
# Check pod status
kubectl get pods -n sandee
kubectl describe pod <pod-name> -n sandee

# Check logs
kubectl logs <pod-name> -n sandee

# Check events
kubectl get events -n sandee --sort-by='.lastTimestamp'
```

## 📚 Full Documentation

For detailed information, see `consolidated-infrastructure/README.md`

---

**🎉 You now have a production-ready, highly available, auto-scaling EKS infrastructure!**
