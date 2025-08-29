#!/bin/bash

echo "🚀 NUCLEAR FIX - DELETING EVERYTHING AND STARTING FRESH"

# Uninstall Helm release
helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null || true

# Delete ALL ALB resources
kubectl delete deployment aws-load-balancer-controller -n kube-system --ignore-not-found
kubectl delete pods -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --force --grace-period=0
kubectl delete ingressclass alb --ignore-not-found
kubectl delete crd ingressclassparams.elbv2.k8s.aws --ignore-not-found
kubectl delete crd targetgroupbindings.elbv2.k8s.aws --ignore-not-found

# Wait
sleep 5

# Create minimal working ALB controller without webhooks or complex features
cat > minimal-alb.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::838645860193:role/AmazonEKSLoadBalancerControllerRole
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: aws-load-balancer-controller
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["extensions", "networking.k8s.io"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: aws-load-balancer-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: aws-load-balancer-controller
subjects:
- kind: ServiceAccount
  name: aws-load-balancer-controller
  namespace: kube-system
---
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: alb
spec:
  controller: ingress.k8s.aws/alb
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aws-load-balancer-controller
  template:
    metadata:
      labels:
        app: aws-load-balancer-controller
    spec:
      serviceAccountName: aws-load-balancer-controller
      hostNetwork: true
      containers:
      - name: controller
        image: public.ecr.aws/eks/aws-load-balancer-controller:v2.7.2
        args:
        - --cluster-name=sandee
        - --ingress-class=alb
        - --aws-region=us-east-1
        - --aws-vpc-id=vpc-02f40ee7a414a4512
        - --enable-shield=false
        - --enable-waf=false
        - --enable-wafv2=false
        - --disable-ingress-class-annotation=true
        - --disable-ingress-group-name-annotation=true
        env:
        - name: AWS_REGION
          value: us-east-1
        - name: AWS_VPC_ID
          value: vpc-02f40ee7a414a4512
        resources:
          requests:
            cpu: 100m
            memory: 200Mi
          limits:
            cpu: 200m
            memory: 500Mi
        securityContext:
          privileged: true
EOF

# Apply minimal config
kubectl apply -f minimal-alb.yaml

# Wait and check
sleep 10
kubectl get pods -n kube-system | grep aws-load-balancer

echo "🎯 NUCLEAR FIX COMPLETE - CHECK IF IT WORKS NOW!"