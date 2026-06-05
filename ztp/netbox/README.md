# NetBox

以 netbox-docker 部署 NetBox，作為 ZTP 流程的 SSOT（Single Source of Truth）。

## 檔案結構

```
netbox/
├── install.sh              # 安裝腳本
├── compose.override.yml    # docker-compose override 範本
├── env.yaml                # 本機設定（不提交 git）
└── env.example.yaml        # 設定範本
```

## 安裝

```bash
# 複製設定範本
cp env.example.yaml env.yaml
# 編輯 env.yaml 填入實際值

sudo ./install.sh
```

常用旗標：

```
--port         <port>    Web UI port          (預設: 80)
--dir          <path>    安裝目錄              (預設: /opt/netbox-docker)
--admin-user   <user>    管理員帳號            (預設: admin)
--admin-pass   <pass>    管理員密碼            (預設: <CHANGE_ME>)
--admin-token  <token>   API Token            (預設: 0123456789...)
```

安裝完成後，帳密與 token 會寫入 `/tmp/ztp/.install-credentials`（權限 600）。

> NetBox 首次啟動需要約 2-3 分鐘初始化，`start_period` 設為 300s。

## 資料目錄

資料存放於 `<install_dir>/data/`：

```
data/
├── postgres/    # 資料庫
├── media/       # 上傳的圖片、附件
├── reports/     # 自訂報表
└── scripts/     # 自訂腳本
```

## 在 ZTP 中的角色

NetBox 作為裝機資訊的來源，`ztp-automate.sh` 在 deploy 前會透過 API 查詢：

1. 以機器 MAC address 找到對應裝置
2. 取得裝置的 hostname
3. 取得 Primary IPv4 作為靜態 IP

### API 使用範例

```bash
# 以 MAC address 查詢裝置介面
curl -s -H "Authorization: Bearer <TOKEN>" \
  http://<NETBOX_IP>/api/dcim/interfaces/?mac_address=<MAC>
```

## 常用管理指令

```bash
cd /opt/netbox-docker

# 查看狀態
docker compose ps

# 查看日誌
docker compose logs -f netbox

# 重啟
docker compose restart netbox

# 停止
docker compose down

# 更新
docker compose pull && docker compose up -d
```
