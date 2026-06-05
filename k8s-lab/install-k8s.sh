#!/bin/bash
# 安裝 containerd + kubeadm + kubelet + kubectl
# 在每個節點上執行

set -e

echo "==> 關閉 swap"
swapoff -a

echo "==> 載入必要 kernel module"
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay 2>/dev/null || true
modprobe br_netfilter 2>/dev/null || true

echo "==> 設定 sysctl 網路參數"
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

echo "==> 安裝基本套件"
apt-get update -qq
apt-get install -y -qq curl apt-transport-https ca-certificates gpg

echo "==> 安裝 containerd"
apt-get install -y -qq containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd 2>/dev/null || containerd &

echo "==> 加入 Kubernetes apt repo"
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | \
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | \
  tee /etc/apt/sources.list.d/kubernetes.list

echo "==> 安裝 kubeadm kubelet kubectl"
apt-get update -qq
apt-get install -y -qq kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

echo "==> 完成！版本："
kubeadm version
kubectl version --client
