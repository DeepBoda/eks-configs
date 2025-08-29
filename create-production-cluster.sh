#!/bin/bash

echo "🚀 CREATING PRODUCTION EKS CLUSTER - SANDEE-PRODUCTION"

# 1. Delete existing clusters
echo "🗑️ Deleting existing clusters..."
eksctl delete cluster --name sandee --region us-east-1 --wait
eksctl delete cluster --name sandee-new --region us-east-1 --wait

# 2. Create production cluster with optimal settings
echo "🏗️ Creating sandee-production cluster..."
eksctl create cluster \
  --name sandee-production \
  --region us-east-1 \
  --version 1.33 \
  --nodegroup-name production-nodes \
  --node-type m6i.xlarge \
  --nodes 4 \
  --nodes-min 4 \
  --nodes-max 20 \
  --node-volume-size 100 \
  --node-ami-family AmazonLinux2023 \
  --managed \
  --enable-ssm \
  --full-ecr-access \
  --asg-access \
  --external-dns-access \
  --appmesh-access \
  --alb-ingress-access

# 3. Install AWS Load Balancer Controller
echo "🔧 Installing AWS Load Balancer Controller..."
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json \
  --region us-east-1

eksctl create iamserviceaccount \
  --cluster=sandee-production \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --region us-east-1 \
  --approve

# Install via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=sandee-production \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-1

# 4. Install EBS CSI Driver
echo "💾 Installing EBS CSI Driver..."
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster sandee-production \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/Amazon_EBS_CSI_DriverPolicy \
  --approve \
  --override-existing-serviceaccounts \
  --region us-east-1

eksctl create addon \
  --name aws-ebs-csi-driver \
  --cluster sandee-production \
  --service-account-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/eksctl-sandee-production-addon-iamserviceaccount-kube-system-ebs-csi-controller-sa-Role1-* \
  --region us-east-1

# 5. Install Cluster Autoscaler
echo "📈 Installing Cluster Autoscaler..."
eksctl create iamserviceaccount \
  --cluster=sandee-production \
  --namespace=kube-system \
  --name=cluster-autoscaler \
  --attach-policy-arn=arn:aws:iam::aws:policy/AutoScalingFullAccess \
  --override-existing-serviceaccounts \
  --region us-east-1 \
  --approve

echo "✅ Production cluster created successfully!"
echo "🔍 Cluster info:"
kubectl cluster-info
kubectl get nodes -o wide