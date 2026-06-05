# KubeVirt Lab

在 Kubernetes 上跑 VM 的練習環境。
使用 kind 建立 K8s 叢集，再安裝 KubeVirt。

## KubeVirt 是什麼

```
傳統：VM 和容器分開管理（vSphere 管 VM、K8s 管容器）
KubeVirt：讓 K8s 也能管理 VM，統一用 kubectl 操作

VM 在 K8s 裡變成一種資源（CRD）：
  kubectl get vms
  kubectl get vmis  （VM Instance，跑起來的 VM）
```

## 架構

```
kind K8s cluster
  └── KubeVirt operator
        └── virt-controller
        └── virt-handler（每個 node 都有）
        └── virt-launcher（每個 VM 一個 Pod）
              └── QEMU/KVM process（實際的 VM）
```

## WSL2 限制

```
WSL2 沒有 KVM 支援
KubeVirt 提供 Software Emulation 模式（useEmulation: true）
效能較差，但足夠學習 API 和概念
```

---

## 安裝步驟

### Step 1：安裝 kind 和 kubectl

```bash
bash 01-install-tools.sh
```

### Step 2：建立 K8s 叢集

```bash
bash 02-create-cluster.sh
```

### Step 3：安裝 KubeVirt

```bash
bash 03-install-kubevirt.sh
```

### Step 4：安裝 virtctl（KubeVirt CLI）

```bash
bash 04-install-virtctl.sh
```

### Step 5：建立第一個 VM

```bash
kubectl apply -f vms/fedora-vm.yaml
kubectl get vms
kubectl get vmis
```

---

## 常用指令

```bash
# 查看所有 VM
kubectl get vms

# 查看跑起來的 VM
kubectl get vmis

# 啟動 VM
virtctl start fedora-vm

# 停止 VM
virtctl stop fedora-vm

# 進入 VM console
virtctl console fedora-vm

# 進入 VM SSH（需要設定 port-forward）
virtctl ssh fedora-vm

# 查看 VM 的 Pod
kubectl get pods -l kubevirt.io=virt-launcher

# 查看 VM 詳細資訊
kubectl describe vmi fedora-vm
```

---

## 清除環境

```bash
kind delete cluster --name kubevirt-lab
```
