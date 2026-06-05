# GitLab

以 Docker Compose 部署的 GitLab CE。

## 檔案說明

| 檔案 | 說明 |
|------|------|
| `docker-compose.yml` | 容器設定 |
| `gitlab.rb` | GitLab 設定（LDAP、Logging、Resources 等） |
| `backup.sh` | 備份腳本 |
| `.env` | 環境變數（不進版控） |
| `.env.example` | 環境變數範本 |

## 首次部署

```bash
cp .env.example .env
# 填入實際密碼
vim .env

sudo docker compose up -d
```

## 備份

備份檔存放於 `./backup/`，保留 7 天。

```bash
# 手動執行
./backup.sh

# 排程（每天凌晨 2 點）
crontab -e
```
```cron
0 2 * * * /path/to/gitlab/backup.sh >> /path/to/gitlab/backup/backup.log 2>&1
```

## 還原

```bash
sudo docker exec -it gitlab gitlab-ctl stop puma
sudo docker exec -it gitlab gitlab-ctl stop sidekiq
sudo docker exec -it gitlab gitlab-backup restore BACKUP=<timestamp>
sudo docker restart gitlab
```

## 環境變數

| 變數 | 說明 |
|------|------|
| `LDAP_PASSWORD` | LDAP bind 密碼 |
| `TELEGRAM_BOT_TOKEN` | Telegram Bot Token，備份通知用 |
| `TELEGRAM_CHAT_ID` | Telegram Chat ID，備份通知用 |
