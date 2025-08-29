#!/bin/bash

echo "🧹 Complete cleanup of ALB controller resources..."

# Delete all ALB controller resources
kubectl delete deployment aws-load-balancer-controller -n kube-system --ignore-not-found
kubectl delete role aws-load-balancer-controller-leader-election-role -n kube-system --ignore-not-found
kubectl delete rolebinding aws-load-balancer-controller-leader-election-rolebinding -n kube-system --ignore-not-found
kubectl delete clusterrole aws-load-balancer-controller --ignore-not-found
kubectl delete clusterrolebinding aws-load-balancer-controller --ignore-not-found
kubectl delete serviceaccount aws-load-balancer-controller -n kube-system --ignore-not-found

# Install fresh via Helm
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=sandee \
  --set region=us-east-1 \
  --set vpcId=vpc-02f40ee7a414a4512 \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::838645860193:role/AmazonEKSLoadBalancerControllerRole"

echo "✅ Fresh installation complete!"
kubectl get pods -n kube-system | grep aws-load-balancer