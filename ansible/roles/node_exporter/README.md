# node_exporter

在目標機器上安裝 Prometheus node_exporter，收集系統指標（CPU、記憶體、磁碟、網路）。

## 安裝方式

支援兩種安裝方式，預設使用 binary。

| 方式 | 管理 | 適用情境 |
|------|------|---------|
| `binary`（預設）| systemd | 所有機器，不需要 Docker |
| `docker` | docker compose | 已有 Docker 環境 |

## 變數

| 變數 | 預設值 | 說明 |
|------|--------|------|
| `node_exporter_version` | `latest` | 版本號，`latest` 會自動從 GitHub 取得最新版 |
| `node_exporter_install_method` | `binary` | 安裝方式：`binary` 或 `docker` |
| `node_exporter_install_dir` | `/usr/local/bin` | binary 安裝路徑（binary 模式） |
| `node_exporter_service_user` | `node_exporter` | systemd service 執行使用者（binary 模式） |
| `node_exporter_dir` | `/opt/node_exporter` | docker-compose 目錄（docker 模式） |

port 統一由 `group_vars/all/prometheus.yml` 的 `node_exporter_port`（預設 `9100`）控制。

## 使用方式

### 新增機器

在 `inventory/hosts.yml` 將機器加入 `node_exporter` 群組：

```yaml
node_exporter:
  hosts:
    new-server:
```

### 執行安裝

```bash
ansible-playbook site.yml --limit <hostname> --tags node_exporter
```

### 切換為 docker 模式

在 `inventory/hosts.yml` 對該機器設定：

```yaml
lab:
  hosts:
    new-server:
      node_exporter_install_method: docker
```

### 驗證安裝

```bash
# 確認 service 狀態
ansible <hostname> -m command -a "systemctl is-active node_exporter" --become

# 確認 metrics endpoint
curl http://<ip>:9100/metrics | head
```
