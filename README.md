# Consolidated EKS Infrastructure - Sandee Application

This directory contains a complete, production-ready Kubernetes infrastructure for the Sandee application on Amazon EKS. The configuration has been modernized with latest best practices, AWS native optimizations, and comprehensive security hardening.

## 🏗️ Architecture Overview

### Infrastructure Components

- **EKS Cluster**: Production-ready cluster with autoscaling and security hardening
- **Application Stack**: Frontend (Next.js), Backend (Node.js), Admin Panel, Cron Jobs
- **Database Layer**: Redis Cluster, Elasticsearch Cluster
- **Networking**: Dual ingress strategy (ALB + NGINX) with HTTP/2 and TLS
- **Storage**: GP3 optimized storage classes with performance tuning
- **Scaling**: HPA with CPU/memory metrics + Cluster Autoscaler
- **Security**: IRSA, RBAC, Pod Security Standards, Network Policies

## 📁 File Structure

```
├── 00-namespaces.yaml                    # Namespace definitions
├── 01-storage-classes.yaml               # GP3 optimized storage classes
├── 02-rbac-irsa.yaml                     # RBAC and IRSA configurations
├── 03-cluster-autoscaler.yaml            # Cluster autoscaler with extended policies
├── 04-aws-load-balancer-controller.yaml  # AWS Load Balancer Controller
├── 05-ingress-nginx.yaml                 # NGINX Ingress with HTTP/2 and security
├── 06-redis-statefulset.yaml             # Redis cluster with HA and persistence
├── 07-elasticsearch-cluster.yaml         # Elasticsearch cluster with optimization
├── 08-application-deployments.yaml       # Application deployments with best practices
├── 09-services.yaml                      # Kubernetes services
├── 10-ingress-resources.yaml             # Ingress resources with rate limiting
├── 11-hpa-configurations.yaml            # HPA with CPU/memory metrics
├── 12-pod-disruption-budgets.yaml        # PDBs for high availability
└── README.md                             # This file
```

## 🚀 Deployment Instructions

### Prerequisites

1. **EKS Cluster**: Ensure you have an EKS cluster named `sandee` running
2. **IAM Roles**: Create the following IAM roles with appropriate policies:
   - `AmazonEKS_EBS_CSI_DriverRole`
   - `AmazonEKSLoadBalancerControllerRole`
   - `AmazonEKSClusterAutoscalerRole`
3. **VPC Configuration**: Update security groups and subnet IDs in the configurations
4. **Domain & SSL**: Ensure ACM certificate is available for your domains

### Step-by-Step Deployment

```bash
# 1. Apply in order (important for dependencies)
kubectl apply -f 00-namespaces.yaml
kubectl apply -f 01-storage-classes.yaml
kubectl apply -f 02-rbac-irsa.yaml

# 2. Deploy infrastructure components
kubectl apply -f 03-cluster-autoscaler.yaml
kubectl apply -f 04-aws-load-balancer-controller.yaml
kubectl apply -f 05-ingress-nginx.yaml

# 3. Deploy database layer
kubectl apply -f 06-redis-statefulset.yaml
kubectl apply -f 07-elasticsearch-cluster.yaml

# 4. Deploy applications
kubectl apply -f 08-application-deployments.yaml
kubectl apply -f 09-services.yaml

# 5. Configure networking and scaling
kubectl apply -f 10-ingress-resources.yaml
kubectl apply -f 11-hpa-configurations.yaml
kubectl apply -f 12-pod-disruption-budgets.yaml
```

### Verification Commands

```bash
# Check all pods are running
kubectl get pods -n sandee
kubectl get pods -n ingress-nginx
kubectl get pods -n aws-load-balancer-controller

# Verify services and ingress
kubectl get svc -n sandee
kubectl get ingress -n sandee

# Check HPA status
kubectl get hpa -n sandee

# Verify PDBs
kubectl get pdb -n sandee
```

## 🔧 Key Features & Improvements

### AWS Native Optimizations

- **IRSA Integration**: Secure AWS service access without storing credentials
- **GP3 Storage**: High-performance storage with optimized IOPS and throughput
- **ALB Integration**: Application Load Balancer with HTTP/2 and SSL termination
- **Cluster Autoscaler**: Advanced scaling policies with cost optimization

### High Availability & Resilience

- **Pod Anti-Affinity**: Ensures pods are distributed across nodes and AZs
- **Topology Spread Constraints**: Even distribution across availability zones
- **Pod Disruption Budgets**: Maintains minimum availability during updates
- **Health Checks**: Comprehensive liveness, readiness, and startup probes

### Security Hardening

- **Security Contexts**: Non-root users, read-only filesystems, dropped capabilities
- **Network Policies**: Micro-segmentation and traffic isolation
- **RBAC**: Least-privilege access control
- **Secret Management**: Encrypted secrets with proper rotation

### Performance Optimization

- **Resource Management**: Proper requests/limits for all containers
- **HPA v2**: CPU and memory-based autoscaling with advanced behaviors
- **Connection Pooling**: Optimized database and cache connections
- **Caching**: Redis cluster with persistence and high availability

### Monitoring & Observability

- **Prometheus Integration**: Metrics collection from all components
- **Structured Logging**: JSON logging with correlation IDs
- **Health Endpoints**: Comprehensive health checking
- **Performance Metrics**: Application and infrastructure monitoring

## 🔐 Security Considerations

### Secrets Management

All sensitive data is stored in Kubernetes secrets:

- `redis-secret`: Redis authentication
- `elasticsearch-secret`: Elasticsearch authentication

### Network Security

- **TLS Everywhere**: End-to-end encryption
- **Rate Limiting**: API protection against abuse
- **CORS Configuration**: Proper cross-origin policies
- **Security Headers**: HSTS, CSP, and other security headers

### Access Control

- **IRSA**: IAM roles for service accounts
- **RBAC**: Role-based access control
- **Pod Security Standards**: Enforced security policies

## 📊 Scaling Configuration

### Horizontal Pod Autoscaler (HPA)

- **Frontend**: 2-10 replicas, 70% CPU, 80% memory
- **Backend**: 3-15 replicas, 60% CPU, 75% memory
- **Admin**: 2-8 replicas, 65% CPU, 80% memory
- **Cron**: 1-5 replicas, 50% CPU, 70% memory

### Cluster Autoscaler

- **Node Range**: 1-100 nodes
- **Instance Types**: m5.large, m5.xlarge, m5.2xlarge
- **Scaling Policy**: Least-waste with balance similar node groups

## 🗄️ Storage Configuration

### Storage Classes

- **gp3-optimized**: Default storage with 3000 IOPS, 125 MB/s throughput
- **gp3-redis**: Redis optimized with 4000 IOPS, 250 MB/s throughput
- **gp3-elasticsearch**: ES optimized with 5000 IOPS, 500 MB/s throughput
- **gp3-high-performance**: High-performance with 16000 IOPS, 1000 MB/s throughput

## 🌐 Domain Configuration

### Primary Domains (ALB)

- `sandee.com` → Frontend
- `eks.sandee.com` → Frontend

### Internal Services (NGINX)

- `admin.sandee.com` → Admin Panel
- `backend-v2.sandee.com` → Backend API
- `api.sandee.com` → Backend API (rate-limited)

## 🔄 Update Strategy

### Rolling Updates

- **Frontend/Backend**: 50% max surge, 25% max unavailable
- **Admin**: 50% max surge, 50% max unavailable
- **Databases**: Recreate strategy for data consistency

### Maintenance Windows

- **Database Updates**: Schedule during low-traffic periods
- **Infrastructure Updates**: Use PDBs to maintain availability
- **Security Patches**: Automated with proper testing

## 📈 Monitoring & Alerting

### Key Metrics to Monitor

- **Application**: Response time, error rate, throughput
- **Infrastructure**: CPU, memory, disk, network utilization
- **Database**: Connection pool, query performance, replication lag
- **Security**: Failed authentication attempts, unusual traffic patterns

### Recommended Alerts

- Pod restart frequency > threshold
- HPA scaling events
- PDB violations
- Storage utilization > 80%
- Certificate expiration warnings

## 🛠️ Troubleshooting

### Common Issues

1. **Pods Stuck in Pending**: Check resource requests vs node capacity
2. **Ingress Not Working**: Verify DNS, certificates, and security groups
3. **Database Connection Issues**: Check secrets and network policies
4. **Scaling Issues**: Review HPA metrics and cluster autoscaler logs

### Useful Commands

```bash
# Debug pod issues
kubectl describe pod <pod-name> -n sandee
kubectl logs <pod-name> -n sandee --previous

# Check resource usage
kubectl top pods -n sandee
kubectl top nodes

# Debug networking
kubectl get endpoints -n sandee
kubectl describe ingress -n sandee
```

## 📝 Customization

### Environment-Specific Changes

1. **Update IAM Role ARNs** in `02-rbac-irsa.yaml`
2. **Configure VPC/Subnet IDs** in `10-ingress-resources.yaml`
3. **Update Domain Names** in ingress configurations
4. **Adjust Resource Limits** based on your workload requirements
5. **Modify Scaling Parameters** in HPA configurations

### Production Considerations

- Enable AWS CloudTrail for audit logging
- Configure backup strategies for databases
- Implement disaster recovery procedures
- Set up monitoring and alerting
- Regular security assessments and updates

---

**Note**: This infrastructure is designed for production use with high availability, security, and performance in mind. Always test in a staging environment before applying to production.
