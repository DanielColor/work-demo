#!/bin/bash
# 安裝 kind 和 kubectl
set -e

echo "==> 安裝 kind"
curl -Lo /usr/local/bin/kind \
  https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x /usr/local/bin/kind
kind version

echo "==> 安裝 kubectl"
curl -Lo /usr/local/bin/kubectl \
  "https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl"
chmod +x /usr/local/bin/kubectl
kubectl version --client

echo "==> 完成"
