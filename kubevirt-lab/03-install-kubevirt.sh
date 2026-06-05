#!/bin/bash
# 安裝 KubeVirt
set -e

KUBEVIRT_VERSION="v1.2.0"

echo "==> 安裝 KubeVirt operator"
kubectl apply -f \
  https://github.com/kubevirt/kubevirt/releases/download/${KUBEVIRT_VERSION}/kubevirt-operator.yaml

echo "==> 等待 operator 就緒..."
kubectl -n kubevirt wait deployment virt-operator \
  --for=condition=Available \
  --timeout=120s

echo "==> 安裝 KubeVirt CR"
kubectl apply -f \
  https://github.com/kubevirt/kubevirt/releases/download/${KUBEVIRT_VERSION}/kubevirt-cr.yaml

echo "==> 開啟 Software Emulation（WSL2 無 KVM 需要此設定）"
kubectl patch kubevirt kubevirt \
  -n kubevirt \
  --type merge \
  --patch '{"spec":{"configuration":{"developerConfiguration":{"useEmulation":true}}}}'

echo "==> 等待 KubeVirt 所有元件就緒（約 3~5 分鐘）..."
kubectl -n kubevirt wait kubevirt kubevirt \
  --for=condition=Available \
  --timeout=300s

echo "==> KubeVirt 元件狀態："
kubectl get pods -n kubevirt

echo ""
echo "==> KubeVirt 安裝完成！"
