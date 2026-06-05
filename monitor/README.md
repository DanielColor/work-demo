# Monitor Stack

基於 Docker Compose 的可觀測性監控平台，涵蓋 Metrics、Logs 與 Alerting。

## 架構

```
監控主機                          被監控機器
┌─────────────────────────┐       ┌──────────────────────┐
│  Prometheus             │◄──────│  node-exporter       │
│  Alertmanager           │       │  dcgm-exporter (GPU) │
│  Loki                   │◄──────│  promtail            │
│  Grafana                │       │  ipmi-exporter       │
└─────────────────────────┘       │  pve-exporter        │
                                  └──────────────────────┘
```

| 元件 | 用途 |
|------|------|
| Prometheus | Metrics 收集與儲存、Alert 規則評估 |
| Alertmanager | 告警路由與通知（Telegram） |
| Loki | Log 收集與儲存 |
| Grafana | 視覺化儀表板、LDAP 登入 |
| node-exporter | 主機硬體與 OS metrics |
| dcgm-exporter | NVIDIA GPU metrics |
| promtail | Log 收集推送至 Loki |
| ipmi-exporter | BMC / IPMI 硬體感測 metrics |
| pve-exporter | Proxmox VE metrics |

## 目錄結構

```
monitor/
├── docker-compose.yml          # 監控主機服務
├── .env                        # 環境變數（不進 git）
├── .env.example                # 環境變數範本
├── alertmanager/               # Alertmanager 設定與告警模板
├── grafana/                    # Grafana 設定、LDAP、Provisioning
├── loki/                       # Loki 設定
├── prometheus/
│   ├── prometheus.yml          # Prometheus 主設定
│   ├── rules/                  # Alert 規則
│   └── targets/                # 被監控目標（file_sd）
└── agent/                      # 部署至被監控機器
    ├── docker-compose.yml
    ├── .env                    # 環境變數（不進 git）
    ├── .env.example
    ├── dcgm/                   # DCGM 自訂指標設定
    ├── fluent-bit/             # Fluent Bit 設定（備用 log shipper）
    ├── ipmi/                   # IPMI exporter 設定
    ├── promtail/               # Promtail 設定
    ├── pve/                    # Proxmox exporter 設定
    └── scripts/                # 安裝腳本（bare metal 環境）
```

## 快速開始

### 監控主機

**1. 複製設定範本**

```bash
cp .env.example .env
cp alertmanager/alertmanager.example.yml alertmanager/alertmanager.yml
cp grafana/ldap.example.toml grafana/ldap.toml
```

**2. 填入機密資訊**

`.env`：
```
GRAFANA_ADMIN_PASSWORD=<your-password>
```

`alertmanager/alertmanager.yml`：
```yaml
bot_token: "<telegram-bot-token>"
chat_id: <telegram-chat-id>
```

`grafana/ldap.toml`：
```toml
bind_password = "<ldap-password>"
```

**3. 新增監控目標**

在 `prometheus/targets/` 新增 yml 檔：

```yaml
- targets: ["192.168.1.x:9100"]
  labels:
    job: "node-exporter"
    hostname: "server-01"
    display_name: "server-01 (192.168.1.x)"
    role: "node"
    env: "prod"
```

**4. 啟動**

```bash
docker compose up -d
```

---

### 被監控機器（Agent）

**1. 複製設定範本**

```bash
cp agent/.env.example agent/.env
cp agent/ipmi/ipmi.example.yml agent/ipmi/ipmi.yml
cp agent/pve/pve.example.yml agent/pve/pve.yml
```

**2. 填入機密資訊**

`agent/.env`：
```
LOKI_HOST=<monitor-server-ip>
```

`agent/ipmi/ipmi.yml`：
```yaml
user: "<ipmi-user>"
pass: "<ipmi-password>"
```

`agent/pve/pve.yml`：
```yaml
token_name: "<pve-token-name>"
token_value: "<pve-token-value>"
```

**3. 啟動**

```bash
cd agent && docker compose up -d
```

> 若目標機器無法使用 Docker，可用 `agent/scripts/` 內的腳本直接安裝。

## Port

| 服務 | Port |
|------|------|
| Grafana | 3000 |
| Prometheus | 9090 |
| Alertmanager | 9093 |
| Loki | 3100 |
