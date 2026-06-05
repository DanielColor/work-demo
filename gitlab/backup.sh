#!/bin/bash
set -e

SCRIPT_DIR="$(dirname "$0")"
BACKUP_DIR="$SCRIPT_DIR/backup"
KEEP_DAYS=7

source "$SCRIPT_DIR/.env"

notify_telegram() {
  local message="$1"
  curl -s -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${message}" > /dev/null
}

notify_failure() {
  local TIME
  TIME=$(date '+%Y-%m-%d %H:%M:%S')
  notify_telegram "$(printf '❌ GitLab 備份失敗\n\n🕐 時間：%s\n🖥️ 主機：%s' "$TIME" "$(hostname)")"
}

trap notify_failure ERR

docker exec -t gitlab gitlab-backup create CRON=1

docker exec -t gitlab cat /etc/gitlab/gitlab-secrets.json > "$BACKUP_DIR/gitlab-secrets.json"

find "$BACKUP_DIR" -name "*_gitlab_backup.tar" -mtime +$KEEP_DAYS -delete

LATEST=$(ls -t "$BACKUP_DIR"/*_gitlab_backup.tar | head -1)

chown 1000:1000 "$LATEST"

mkdir -p /tmp/backup
cp "$LATEST" /tmp/backup/

TIME=$(date '+%Y-%m-%d %H:%M:%S')
SIZE=$(du -sh "$LATEST" | cut -f1)

notify_telegram "$(printf '✅ GitLab 備份成功\n\n🕐 時間：%s\n🖥️ 主機：%s\n📦 檔案：%s\n💾 大小：%s' \
  "$TIME" "$(hostname)" "$(basename "$LATEST")" "$SIZE")"

echo "Backup done: $LATEST"
