# OpenLDAP

內部 LDAP 服務，基於 `osixia/openldap`。

## 環境資訊

| 項目 | 值 |
|------|-----|
| 主機 | your-server-ip |
| Port | 389（LDAP）/ 636（LDAPS）|
| Base DN | `dc=example,dc=local` |
| Admin DN | `cn=admin,dc=example,dc=local` |
| 使用者 OU | `ou=Users,dc=example,dc=local` |
| 群組 OU | `ou=Groups,dc=example,dc=local` |
| 管理員群組 | `cn=admins,ou=Groups,dc=example,dc=local` |

## 啟動

```bash
docker compose up -d
```

## 目錄結構

```
openldap/
├── docker-compose.yml
├── scripts/
│   ├── add-user.sh      # 互動式新增使用者
│   └── backup.sh        # 備份 LDAP 資料
└── backups/             # 備份檔存放位置（git 忽略）
```

## Scripts

### add-user.sh

互動式新增使用者，輸入全名後自動推導所有欄位。

```bash
bash scripts/add-user.sh
```

| 欄位 | 推導方式 |
|------|---------|
| UID | 全名轉小寫底線 + @example.local |
| CN | 名（第一個字）|
| SN | 姓（最後一個字）|
| Mail | 同 UID |
| 密碼 | 名_姓 + 建立日期（YYYYMMDD）|

憑證儲存至 `/tmp/openldap/.add-user-credentials`（權限 600）。

### backup.sh

匯出完整 LDIF 並壓縮，自動清除 7 天前的舊備份。

```bash
bash scripts/backup.sh
```

備份檔命名格式：`ldap_YYYYMMDD_HHMMSS.ldif.gz`

建議設定 crontab 每日自動執行：

```bash
0 2 * * * /path/to/openldap/scripts/backup.sh >> /tmp/openldap/backup.log 2>&1
```

## 使用者管理

Web 管理介面：`http://<your-server-ip>:8080/ldap/`

## 整合服務

| 服務 | 用途 |
|------|------|
| GitLab | 使用者登入驗證 |
| Grafana | 使用者登入驗證 |
| LDAP Admin | Web 管理介面 |
