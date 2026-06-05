#!/bin/bash
# 建立 kind K8s 叢集
set -e

echo "==> 建立 kind 叢集（1 control-plane + 2 workers）"
cat <<EOF | kind create cluster --name kubevirt-lab --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF

echo "==> 確認叢集狀態"
kubectl get nodes

echo "==> 叢集建立完成"
kubectl cluster-info --context kind-kubevirt-lab
