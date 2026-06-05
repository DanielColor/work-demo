#!/bin/bash
# 在 master 節點執行 kubeadm init

set -e

echo "==> 初始化 Control Plane"
kubeadm init \
  --apiserver-advertise-address=10.10.0.x \
  --pod-network-cidr=192.168.0.0/16 \
  --node-name=k8s-master \
  2>&1 | tee /root/kubeadm-init.log

echo "==> 設定 kubectl 設定檔"
mkdir -p $HOME/.kube
cp /etc/kubernetes/admin.conf $HOME/.kube/config
chmod 600 $HOME/.kube/config

echo "==> 安裝 CNI 網路（Calico）"
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

echo ""
echo "==> 等待 master 節點 Ready..."
kubectl wait --for=condition=Ready node/k8s-master --timeout=120s

echo ""
echo "==> Master 節點狀態："
kubectl get nodes

echo ""
echo "==> 複製以下 join 指令到 worker 節點執行："
grep "kubeadm join" /root/kubeadm-init.log -A2
