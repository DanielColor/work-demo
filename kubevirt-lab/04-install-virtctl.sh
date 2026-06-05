#!/bin/bash
# 安裝 virtctl（KubeVirt CLI 工具）
set -e

KUBEVIRT_VERSION="v1.2.0"

echo "==> 安裝 virtctl"
curl -Lo /usr/local/bin/virtctl \
  https://github.com/kubevirt/kubevirt/releases/download/${KUBEVIRT_VERSION}/virtctl-${KUBEVIRT_VERSION}-linux-amd64
chmod +x /usr/local/bin/virtctl

echo "==> virtctl 版本："
virtctl version --client
