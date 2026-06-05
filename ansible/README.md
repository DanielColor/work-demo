# Ansible

基礎設施自動化管理，使用 Ansible 統一管理所有機器的設定。

## 前置需求

- Ansible 2.16+
- SSH key 已加入各機器（`~/.ssh/ansible_deploy`，）
- Vault 密碼檔 `~/.vault_pass`（）

## 目錄結構

```
ansible/
├── inventory/
│   └── hosts.yml          # 機器清單與群組設定
├── group_vars/
│   └── all/
│       ├── vars.yml       # 通用變數（ansible_user）
│       ├── users.yml      # 使用者與 SSH key
│       ├── prometheus.yml # 監控相關設定
│       ├── harbor.yml     # Harbor registry 設定
│       ├── gitlab.yml     # GitLab 變數同步設定
│       └── vault.yml      # 機敏資訊（加密）
├── host_vars/
│   └── <hostname>/
│       └── vault.yml      # 機敏資訊（加密）
├── roles/                 # Ansible roles
│   ├── common/
│   ├── timesync/
│   ├── ssh_keys/
│   ├── ssh_config/
│   ├── docker/
│   ├── node_exporter/
│   ├── prometheus_file_sd/
│   ├── gitlab_runner/
│   ├── harbor/
│   └── harbor_registry/
├── init.yml               # 新機器初始化
├── site.yml               # 服務設定
└── ansible.cfg
```

## Roles

| Role | 說明 |
|------|------|
| [common](roles/common/README.md) | 基礎套件與系統設定 |
| [timesync](roles/timesync/README.md) | 時間同步 |
| [ssh_keys](roles/ssh_keys/README.md) | SSH key 管理 |
| [ssh_config](roles/ssh_config/README.md) | 本機 SSH config 產生 |
| [docker](roles/docker/README.md) | Docker 安裝與 Harbor 憑證設定 |
| [node_exporter](roles/node_exporter/README.md) | 安裝 Prometheus node exporter |
| [prometheus_file_sd](roles/prometheus_file_sd/README.md) | 同步 Prometheus targets |
| [gitlab_runner](roles/gitlab_runner/README.md) | GitLab Runner 設定 |
| [harbor](roles/harbor/README.md) | Harbor Registry 安裝與設定 |
| [harbor_registry](roles/harbor_registry/README.md) | Harbor project 與 robot account 管理 |

## 快速開始

### 初始化新機器

```bash
ansible-playbook init.yml --limit <hostname>
```

### 套用服務設定

```bash
ansible-playbook site.yml
```

## 監控管理

監控架構說明：每台機器安裝 node_exporter 收集系統指標，最後由 `prometheus_file_sd` 在 monitor 機器上統一產生 Prometheus target 檔案。

### 新增機器到監控

**1. 在 `inventory/hosts.yml` 加入機器**

```yaml
lab:
  hosts:
    new-server:
      ansible_host: 192.168.1.xxx
      ansible_user: Ansible_Deploy
      init_user: ubuntu
      prom_role: server
```

**2. 將機器加入 `node_exporter` 群組**

```yaml
node_exporter:
  hosts:
    new-server:
```

**3. 安裝 node_exporter**

```bash
ansible-playbook site.yml --limit new-server --tags node_exporter
```

**4. 同步 Prometheus targets**

```bash
ansible-playbook site.yml --tags prometheus_file_sd
```

> Prometheus 的 `scrape_interval` 為 5 分鐘，新 target 最多等 5 分鐘才會出現在 Grafana。

### 移除機器的監控

**1. 從 `node_exporter` 群組移除該機器**

**2. 同步 Prometheus targets**

```bash
ansible-playbook site.yml --tags prometheus_file_sd
```

target 檔案會自動刪除，Prometheus 下次 reload 後不再抓取。

### 只跑特定步驟

```bash
# 只安裝 node_exporter（不影響其他服務）
ansible-playbook site.yml --limit <hostname> --tags node_exporter

# 只更新 Prometheus targets
ansible-playbook site.yml --tags prometheus_file_sd
```

## 協作流程

`main` branch 為 protected，所有改動需透過 MR 合入。

### Branch 命名

| 類型 | 格式 | 範例 |
|------|------|------|
| 新功能 / 新 role | `feature/` | `feature/add-harbor-role` |
| 修正 | `fix/` | `fix/gitlab-runner-config` |
| 維護 / 更新 | `chore/` | `chore/update-inventory` |

### 流程

```bash
# 1. 更新本機 main
git checkout main
git pull

# 2. 開新 branch
git checkout -b feature/add-something

# 3. 改動、commit
git add .
git commit -m "feat: 說明改了什麼"

# 4. push 到遠端
git push -u origin feature/add-something

# 5. 去 GitLab 開 MR，等 review 後 merge
```

