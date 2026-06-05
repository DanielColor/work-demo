# KubeVirt 練習題

## 基礎操作

### 練習 1：啟動和停止 VM

```bash
# 建立 VM（不啟動）
kubectl apply -f vms/fedora-vm.yaml

# 看 VM 狀態（Stopped）
kubectl get vms

# 啟動 VM
virtctl start fedora-vm

# 看 VM 狀態（Running）
kubectl get vmis

# 看 VM 對應的 Pod
kubectl get pods -l kubevirt.io=virt-launcher

# 停止 VM
virtctl stop fedora-vm

# 刪除 VM
kubectl delete vm fedora-vm
```

---

### 練習 2：進入 VM Console

```bash
virtctl start fedora-vm

# 等 VM 啟動（約 1~2 分鐘）
kubectl get vmis -w

# 進入 console（帳號：fedora / 密碼：fedora）
virtctl console fedora-vm

# 離開 console：Ctrl + ]
```

---

### 練習 3：VM 熱遷移（Live Migration）

```bash
# 把 VM 從一個 node 遷移到另一個 node（不停機）
virtctl migrate fedora-vm

# 觀察遷移過程
kubectl get vmim -w

# 確認遷移後 VM 跑在不同 node
kubectl get vmis -o wide
```

---

### 練習 4：VM Snapshot

```bash
# 建立快照
cat <<EOF | kubectl apply -f -
apiVersion: snapshot.kubevirt.io/v1alpha1
kind: VirtualMachineSnapshot
metadata:
  name: fedora-snapshot-1
spec:
  source:
    apiGroup: kubevirt.io
    kind: VirtualMachine
    name: fedora-vm
EOF

# 查看快照
kubectl get vmsnapshot

# 從快照還原
cat <<EOF | kubectl apply -f -
apiVersion: snapshot.kubevirt.io/v1alpha1
kind: VirtualMachineRestore
metadata:
  name: fedora-restore-1
spec:
  target:
    apiGroup: kubevirt.io
    kind: VirtualMachine
    name: fedora-vm
  virtualMachineSnapshotName: fedora-snapshot-1
EOF
```

---

### 練習 5：用 K8s Service 暴露 VM 的 Port

```bash
kubectl apply -f vms/vm-with-service.yaml
virtctl start web-vm

# 等 VM 啟動後確認 Service
kubectl get svc web-vm-service

# 取得 NodePort
kubectl get svc web-vm-service -o jsonpath='{.spec.ports[0].nodePort}'
```

---

## 進階：VM 和 Pod 混合部署

```bash
# 同一個 namespace 裡同時有 VM 和容器 Pod
kubectl apply -f vms/fedora-vm.yaml
kubectl create deployment nginx --image=nginx

# 兩者共用 K8s 網路
kubectl get pods
kubectl get vmis

# VM 可以 ping 到 Pod（進入 VM console 後）
virtctl console fedora-vm
# ping <nginx-pod-ip>
```
