# MAAS ZTP

MAAS 自動裝機環境，包含安裝腳本與 ZTP（Zero Touch Provisioning）自動化流程。

## 檔案結構

```
maas/
├── install.sh              # MAAS 安裝腳本
├── ztp-automate.sh         # ZTP 自動化腳本（含 NetBox 串接）
├── env.yaml                # 本機設定（不提交 git）
├── env.example.yaml        # 設定範本
└── cloud-init/
    └── maas.yaml           # Deploy 時套用的 cloud-init 設定
```

## 安裝 MAAS

```bash
# 複製設定範本
cp env.example.yaml env.yaml
# 編輯 env.yaml 填入實際值

sudo ./install.sh
```

支援三種模式（`--mode`）：

| 模式 | 說明 |
|------|------|
| `region+rack` | 單機部署（預設） |
| `region` | 僅 Region Controller |
| `rack` | 僅 Rack Controller，需指定 `--region-url` 與 `--secret` |

其他常用旗標：

```
--maas-channel  <channel>   MAAS snap channel (預設: 3.6/stable)
--maas-url      <url>       MAAS API URL（留空自動偵測）
--db-name       <name>      PostgreSQL 資料庫名稱
--db-pass       <pass>      PostgreSQL 密碼
--admin-pass    <pass>      MAAS 管理員密碼
--skip-dns                  跳過 systemd-resolved 停用
```

安裝完成後，帳密會寫入 `/tmp/ztp/.install-credentials`（權限 600）。

## ZTP 自動化

每分鐘由 cron 執行，自動處理 MAAS 中 `New` 與 `Ready` 狀態的機器：

- **New → Commissioning**：偵測到新機器自動觸發 commission
- **Ready → Deploy**：查詢 NetBox 取得 hostname 與靜態 IP，設定後自動 deploy

### 前置條件

1. MAAS CLI 已登入：`maas login admin <MAAS_URL> <API_KEY>`
2. NetBox 已建立對應裝置（含 Primary IPv4 與介面 MAC）

### 手動執行

```bash
# 模擬執行（不實際寫入）
./ztp-automate.sh --dry-run --netbox-url http://<NETBOX_IP> --netbox-token <TOKEN>

# 實際執行
./ztp-automate.sh --netbox-url http://<NETBOX_IP> --netbox-token <TOKEN>
```

常用旗標：

```
--netbox-url    <url>       NetBox API URL (預設: http://localhost)
--netbox-token  <token>     NetBox API Token（deploy 必填）
--profile       <profile>   MAAS CLI profile (預設: admin)
--dry-run                   模擬執行，不實際寫入
```

### Cron 設定

```cron
* * * * * root /path/to/ztp/maas/ztp-automate.sh \
  --netbox-url http://<NETBOX_IP> \
  --netbox-token <TOKEN> \
  >> /tmp/ztp/ztp-automate-cron.log 2>&1
```

### hold tag

機器在 MAAS 加上 `hold` tag 可在 Ready 狀態暫停自動 deploy，用於需要手動確認的機器。

## 流程說明

```
PXE Boot → Enlistment (New) → [ZTP] Commission
         → Commissioning → Ready → [ZTP] NetBox 查詢
         → 設定 hostname + 靜態 IP → Deploy
         → OS 安裝 → Deployed
```

詳細流程圖：`/opt/src/maas-ztp-flow.svg`
