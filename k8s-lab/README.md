# k8s-lab

以 Vagrant + VirtualBox 在本機建立多節點 Kubernetes 叢集，包含選配的 Rancher 管理介面。

## 架構

```
VirtualBox (host-only network: 192.168.56.x)
├── k8s-master    (control plane)
├── k8s-worker1
├── k8s-worker2
└── rancher       (選配，Rancher UI)
```

## 前置需求

- [Vagrant](https://www.vagrantup.com/)
- [VirtualBox](https://www.virtualbox.org/)
- 至少 8GB RAM（master 4G + 每個 worker 2G）

## 快速開始

### 方式一：Vagrant（多節點，含 Rancher）

```bash
# 在 Vagrantfile 填入你的 SSH 公鑰
vim Vagrantfile

# 啟動所有 VM
vagrant up

# 初始化 master
vagrant ssh k8s-master
bash /vagrant/init-master.sh

# 在 worker 節點執行 join 指令（從 master 輸出取得）
vagrant ssh k8s-worker1
sudo kubeadm join ...
```

### 方式二：Docker Compose（單節點，本機測試）

```bash
docker compose up -d
```

## 安裝 Kubernetes（裸機）

```bash
# 安裝 containerd、kubeadm、kubelet、kubectl
bash install-k8s.sh

# 初始化 master（只在 master 執行）
bash init-master.sh
```

## Rancher

Rancher 提供 Web UI 管理 Kubernetes 叢集。

```bash
cd rancher
docker compose up -d
```

存取：`https://192.168.56.x`（初次登入需設定 admin 密碼）

## 網路規劃

| 節點 | 內部 IP | Host-only IP |
|------|---------|--------------|
| k8s-master | 10.10.0.10 | 192.168.56.50 |
| k8s-worker1 | 10.10.0.11 | 192.168.56.51 |
| k8s-worker2 | 10.10.0.12 | 192.168.56.52 |
| rancher | 10.10.0.20 | 192.168.56.60 |
