#!/bin/bash
set -e

PROJECT="ztp"
SCRIPT_NAME=$(basename "$0" .sh)
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
DATE=$(date '+%Y-%m-%d')
LOG_RETENTION=7
LOG_BASE="/tmp/${PROJECT}"
LOG_DIR="${LOG_BASE}/${DATE}"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}-${TIMESTAMP}.log"
mkdir -p "$LOG_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m'

SECTION_COUNTER=0

log()     { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"; }
info()    { echo -e "${GREEN}[INFO]${NC} $1"; log "[INFO] $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; log "[WARN] $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; log "[ERROR] $1"; exit 1; }
dryrun()  { echo -e "${BLUE}[DRY-RUN]${NC} $1"; log "[DRY-RUN] $1"; }

section() {
  SECTION_COUNTER=$((SECTION_COUNTER + 1))
  echo -e "\n${BLUE}==============================${NC}"
  echo -e "${BLUE} ${SECTION_COUNTER}. $1${NC}"
  echo -e "${BLUE}==============================${NC}"
  log "=== ${SECTION_COUNTER}. $1 ==="
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

ZTP 自動化腳本：將 MAAS 上的 New 機器自動 commission，Ready 機器自動 deploy。
Deploy 前從 NetBox 查詢 hostname 與 Primary IP，查不到則跳過。

Options:
  --profile             <name>      MAAS CLI profile 名稱        (default: admin)
  --template            <path>      cloud-init template 路徑     (default: <script_dir>/cloud-init/maas.yaml)
  --netbox-url          <url>       NetBox API URL               (default: http://localhost)
  --netbox-token        <token>     NetBox API Token             (required for deploy)
  --commission                      只處理 New 機器（commission）
  --deploy                          只處理 Ready 機器（deploy）
  --dry-run                         模擬執行，不實際寫入
  --install-cron        <interval>  安裝自動化 cron job          (default: "* * * * *")
  --remove-cron                     移除自動化 cron job
  --install-clean-cron  <interval>  安裝 log 清理 cron job       (default: "0 0 * * *")
  --remove-clean-cron               移除 log 清理 cron job
  --log-retention       <days>      Log 保留天數                 (default: 7)
  -h, --help                        顯示此說明

不帶 --commission 或 --deploy 時，兩個都執行。
EOF
  exit 0
}

# ============================================================
# Defaults
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename "$0")"
MAAS_PROFILE="admin"
TEMPLATE_PATH="${SCRIPT_DIR}/cloud-init/maas.yaml"
NETBOX_URL="http://localhost"
NETBOX_TOKEN=""
DRY_RUN=false
RUN_COMMISSION=false
RUN_DEPLOY=false
INSTALL_CRON=false
REMOVE_CRON=false
INSTALL_CLEAN_CRON=false
REMOVE_CLEAN_CRON=false
CLEAN_LOG=false
CRON_INTERVAL="* * * * *"
CLEAN_CRON_INTERVAL="0 0 * * *"
CRON_FILE="/etc/cron.d/ztp-automate"
CLEAN_CRON_FILE="/etc/cron.d/ztp-clean-log"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)            MAAS_PROFILE="$2";   shift 2 ;;
    --template)           TEMPLATE_PATH="$2";  shift 2 ;;
    --netbox-url)         NETBOX_URL="$2";     shift 2 ;;
    --netbox-token)       NETBOX_TOKEN="$2";   shift 2 ;;
    --commission)         RUN_COMMISSION=true;  shift ;;
    --deploy)             RUN_DEPLOY=true;      shift ;;
    --dry-run)            DRY_RUN=true;         shift ;;
    --install-cron)       INSTALL_CRON=true; shift; [[ -n "$1" && "$1" != --* ]] && { CRON_INTERVAL="$1"; shift; } ;;
    --remove-cron)        REMOVE_CRON=true; shift ;;
    --install-clean-cron) INSTALL_CLEAN_CRON=true; shift; [[ -n "$1" && "$1" != --* ]] && { CLEAN_CRON_INTERVAL="$1"; shift; } ;;
    --remove-clean-cron)  REMOVE_CLEAN_CRON=true; shift ;;
    --log-retention)      LOG_RETENTION="$2"; CLEAN_LOG=true; shift 2 ;;
    -h|--help) usage ;;
    *) error "Unknown option: $1. Use --help for usage." ;;
  esac
done

# ============================================================
# Cron 管理
# ============================================================
if [[ "$INSTALL_CRON" == true ]]; then
  [[ $EUID -ne 0 ]] && error "--install-cron 需要 root 權限"
  cat > "$CRON_FILE" <<EOF
# ZTP automate cron job
SHELL=/bin/bash
PATH=/snap/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
${CRON_INTERVAL} root bash ${SCRIPT_PATH} 2>&1
EOF
  chmod 644 "$CRON_FILE"
  info "Cron job 已安裝：${CRON_FILE}"
  info "執行間隔：${CRON_INTERVAL}"
  exit 0
fi

if [[ "$CLEAN_LOG" == true && "$RUN_COMMISSION" == false && "$RUN_DEPLOY" == false ]]; then
  find "$LOG_BASE" -maxdepth 1 -type d -mtime +"$LOG_RETENTION" -exec rm -rf {} + 2>/dev/null || true
  find "$LOG_BASE" -maxdepth 1 -type d -empty -exec rm -rf {} + 2>/dev/null || true
  echo -e "${GREEN}[INFO]${NC} Log 清理完成（保留 ${LOG_RETENTION} 天）"
  rm -f "$LOG_FILE"
  rmdir "$LOG_DIR" 2>/dev/null || true
  exit 0
fi

if [[ "$REMOVE_CRON" == true ]]; then
  [[ $EUID -ne 0 ]] && error "--remove-cron 需要 root 權限"
  if [[ -f "$CRON_FILE" ]]; then
    rm -f "$CRON_FILE"
    info "Cron job 已移除：${CRON_FILE}"
  else
    warn "Cron job 不存在：${CRON_FILE}"
  fi
  exit 0
fi

if [[ "$INSTALL_CLEAN_CRON" == true ]]; then
  [[ $EUID -ne 0 ]] && error "--install-clean-cron 需要 root 權限"
  cat > "$CLEAN_CRON_FILE" <<EOF
# ZTP log cleanup cron job
SHELL=/bin/bash
PATH=/snap/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
${CLEAN_CRON_INTERVAL} root bash ${SCRIPT_PATH} --log-retention ${LOG_RETENTION} 2>&1
EOF
  chmod 644 "$CLEAN_CRON_FILE"
  info "Log 清理 cron job 已安裝：${CLEAN_CRON_FILE}"
  info "執行間隔：${CLEAN_CRON_INTERVAL}，保留天數：${LOG_RETENTION}"
  exit 0
fi

if [[ "$REMOVE_CLEAN_CRON" == true ]]; then
  [[ $EUID -ne 0 ]] && error "--remove-clean-cron 需要 root 權限"
  if [[ -f "$CLEAN_CRON_FILE" ]]; then
    rm -f "$CLEAN_CRON_FILE"
    info "Log 清理 cron job 已移除：${CLEAN_CRON_FILE}"
  else
    warn "Log 清理 cron job 不存在：${CLEAN_CRON_FILE}"
  fi
  exit 0
fi

# 不帶 flag 時兩個都跑
if [[ "$RUN_COMMISSION" == false && "$RUN_DEPLOY" == false ]]; then
  RUN_COMMISSION=true
  RUN_DEPLOY=true
fi

# ============================================================
# 免責聲明（互動模式才顯示）
# ============================================================
if [[ -t 1 ]]; then
  echo -e "${YELLOW}"
  cat <<EOF
警告：此腳本將對 MAAS 上的機器執行 commission 或 deploy 操作。
請確認 profile、template、NetBox 設定正確後繼續。
EOF
  echo -e "${NC}"
  sleep 3
fi

# ============================================================
# 前置檢查
# ============================================================
section "前置檢查"

command -v maas &>/dev/null  || error "找不到 maas CLI，請先安裝並登入"
info "maas CLI 存在"

command -v jq &>/dev/null    || error "找不到 jq，請先安裝：apt-get install -y jq"
info "jq 存在"

command -v curl &>/dev/null  || error "找不到 curl，請先安裝：apt-get install -y curl"
info "curl 存在"

[[ -f "$TEMPLATE_PATH" ]] || error "找不到 cloud-init template：${TEMPLATE_PATH}"
info "cloud-init template 存在：${TEMPLATE_PATH}"

maas "$MAAS_PROFILE" machines read &>/dev/null || error "MAAS CLI 無法連線，請確認 profile 是否已登入"
info "MAAS CLI 連線正常（profile: ${MAAS_PROFILE}）"

if [[ "$RUN_DEPLOY" == true ]]; then
  [[ -z "$NETBOX_TOKEN" ]] && error "Deploy 需要 --netbox-token"
  NB_STATUS=$(curl -sf -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer ${NETBOX_TOKEN}" \
    "${NETBOX_URL}/api/status/" 2>/dev/null || echo "000")
  [[ "$NB_STATUS" == "200" ]] || error "無法連線 NetBox：${NETBOX_URL}（HTTP ${NB_STATUS}）"
  info "NetBox 連線正常：${NETBOX_URL}"
fi

# ============================================================
# 讀取機器狀態
# ============================================================
section "讀取機器狀態"

MACHINES=$(maas "$MAAS_PROFILE" machines read)

NEW_MACHINES=$(echo "$MACHINES"   | jq -r '.[] | select(.status == 0) | .system_id')
READY_MACHINES=$(echo "$MACHINES" | jq -r '.[] | select(.status == 4) | .system_id')

NEW_COUNT=0
READY_COUNT=0
[[ -n "$NEW_MACHINES" ]]   && NEW_COUNT=$(echo "$NEW_MACHINES"     | grep -c .)
[[ -n "$READY_MACHINES" ]] && READY_COUNT=$(echo "$READY_MACHINES" | grep -c .)

info "New（待 commission）：${NEW_COUNT} 台"
info "Ready（待 deploy）  ：${READY_COUNT} 台"

# ============================================================
# Commission New 機器
# ============================================================
COMMISSIONED=0
if [[ "$RUN_COMMISSION" == true ]]; then
  section "Commission New 機器"

  if [[ -z "$NEW_MACHINES" ]]; then
    info "沒有 New 狀態的機器，跳過"
  else
    while IFS= read -r SYSTEM_ID; do
      HOSTNAME=$(echo "$MACHINES" | jq -r ".[] | select(.system_id == \"$SYSTEM_ID\") | .hostname")
      if [[ "$DRY_RUN" == true ]]; then
        dryrun "會 commission：${HOSTNAME} (${SYSTEM_ID})"
        COMMISSIONED=$((COMMISSIONED + 1))
      else
        info "Commission：${HOSTNAME} (${SYSTEM_ID})"
        if maas "$MAAS_PROFILE" machine commission "$SYSTEM_ID" >> "$LOG_FILE" 2>&1; then
          info "${HOSTNAME} commission 已觸發"
          COMMISSIONED=$((COMMISSIONED + 1))
        else
          warn "${HOSTNAME} commission 失敗，見 log：${LOG_FILE}"
        fi
      fi
    done <<< "$NEW_MACHINES"
  fi
fi

# ============================================================
# Deploy Ready 機器
# ============================================================
DEPLOYED=0
SKIPPED=0
if [[ "$RUN_DEPLOY" == true ]]; then
  section "Deploy Ready 機器"

  if [[ -z "$READY_MACHINES" ]]; then
    info "沒有 Ready 狀態的機器，跳過"
  else
    USER_DATA=$(base64 -w0 "$TEMPLATE_PATH")
    while IFS= read -r SYSTEM_ID; do
      HOSTNAME=$(echo "$MACHINES" | jq -r ".[] | select(.system_id == \"$SYSTEM_ID\") | .hostname")

      # hold tag 檢查
      TAGS=$(echo "$MACHINES" | jq -r ".[] | select(.system_id == \"$SYSTEM_ID\") | .tag_names[]" 2>/dev/null || true)
      if echo "$TAGS" | grep -qx "hold"; then
        warn "${HOSTNAME} (${SYSTEM_ID}) 有 hold tag，跳過 deploy"
        SKIPPED=$((SKIPPED + 1))
        continue
      fi

      # ── NetBox 查詢 ──────────────────────────────────────
      INTERFACES_JSON=$(maas "$MAAS_PROFILE" interfaces read "$SYSTEM_ID" 2>/dev/null)
      MAC=$(echo "$INTERFACES_JSON" | jq -r '[.[] | select(.type == "physical")] | .[0].mac_address // empty')

      if [[ -z "$MAC" ]]; then
        warn "${HOSTNAME} (${SYSTEM_ID}) 無法取得 MAC address，跳過 deploy"
        SKIPPED=$((SKIPPED + 1))
        continue
      fi

      NB_IFACE_JSON=$(curl -sf \
        -H "Authorization: Bearer ${NETBOX_TOKEN}" \
        "${NETBOX_URL}/api/dcim/interfaces/?mac_address=${MAC}" 2>/dev/null || echo '{"count":0}')

      NB_COUNT=$(echo "$NB_IFACE_JSON" | jq -r '.count')
      if [[ "$NB_COUNT" == "0" ]]; then
        warn "${HOSTNAME} (${SYSTEM_ID}) MAC ${MAC} 不在 NetBox，跳過 deploy"
        SKIPPED=$((SKIPPED + 1))
        continue
      fi

      NB_DEVICE_NAME=$(echo "$NB_IFACE_JSON" | jq -r '.results[0].device.name // empty')
      NB_DEVICE_ID=$(echo "$NB_IFACE_JSON"   | jq -r '.results[0].device.id   // empty')

      if [[ -z "$NB_DEVICE_NAME" || -z "$NB_DEVICE_ID" ]]; then
        warn "${HOSTNAME} (${SYSTEM_ID}) NetBox device 資料不完整，跳過 deploy"
        SKIPPED=$((SKIPPED + 1))
        continue
      fi

      NB_DEVICE_JSON=$(curl -sf \
        -H "Authorization: Bearer ${NETBOX_TOKEN}" \
        "${NETBOX_URL}/api/dcim/devices/${NB_DEVICE_ID}/" 2>/dev/null || echo '{}')

      NB_PRIMARY_IP=$(echo "$NB_DEVICE_JSON" | jq -r '.primary_ip.address // empty' | cut -d/ -f1)

      if [[ -z "$NB_PRIMARY_IP" ]]; then
        warn "${HOSTNAME} (${SYSTEM_ID}) NetBox 未設定 Primary IP，跳過 deploy"
        SKIPPED=$((SKIPPED + 1))
        continue
      fi

      info "${HOSTNAME} → NetBox：hostname=${NB_DEVICE_NAME} ip=${NB_PRIMARY_IP}"

      if [[ "$DRY_RUN" == true ]]; then
        dryrun "會更新 hostname：${HOSTNAME} → ${NB_DEVICE_NAME}"
        dryrun "會設定 static IP：${NB_PRIMARY_IP}"
        dryrun "會 deploy：${NB_DEVICE_NAME} (${SYSTEM_ID})"
        DEPLOYED=$((DEPLOYED + 1))
        continue
      fi

      # ── 更新 MAAS hostname ────────────────────────────────
      if ! maas "$MAAS_PROFILE" machine update "$SYSTEM_ID" hostname="$NB_DEVICE_NAME" >> "$LOG_FILE" 2>&1; then
        warn "${HOSTNAME} (${SYSTEM_ID}) hostname 更新失敗，跳過 deploy"
        SKIPPED=$((SKIPPED + 1))
        continue
      fi
      info "${HOSTNAME} → hostname 更新為 ${NB_DEVICE_NAME}"

      # ── 設定 Static IP ────────────────────────────────────
      IFACE_ID=$(echo "$INTERFACES_JSON" | jq -r '[.[] | select(.type == "physical")] | .[0].id')
      CURRENT_IP=$(echo "$INTERFACES_JSON" | jq -r '
        [.[] | select(.type == "physical")] | .[0].links[] |
        select(.mode == "static") | .ip_address // empty' | head -1)

      if [[ "$CURRENT_IP" == "$NB_PRIMARY_IP" ]]; then
        info "${NB_DEVICE_NAME} 靜態 IP 已正確設定：${NB_PRIMARY_IP}，跳過"
      else
        SUBNET_ID=$(echo "$INTERFACES_JSON" | jq -r '
          [.[] | select(.type == "physical")] | .[0].links[] |
          select(.subnet.cidr != null) |
          select(.subnet.cidr | test("^[0-9]")) |
          .subnet.id // empty' | head -1)

        if [[ -z "$SUBNET_ID" ]]; then
          SUBNET_ID=$(maas "$MAAS_PROFILE" subnets read 2>/dev/null | \
            jq -r '.[] | select(.cidr | test("^[0-9]")) | .id' | head -1)
        fi

        if [[ -z "$SUBNET_ID" ]]; then
          warn "${NB_DEVICE_NAME} (${SYSTEM_ID}) 找不到 subnet，跳過 deploy"
          SKIPPED=$((SKIPPED + 1))
          continue
        fi

        IP_ID=$(sudo -u postgres psql -d maasdb -tAc \
          "SELECT id FROM maasserver_staticipaddress WHERE ip = '${NB_PRIMARY_IP}' AND alloc_type NOT IN (1, 2) LIMIT 1;" 2>/dev/null || true)
        if [[ -n "$IP_ID" ]]; then
          sudo -u postgres psql -d maasdb -c "
            DELETE FROM maasserver_dnsresource_ip_addresses WHERE staticipaddress_id = ${IP_ID};
            DELETE FROM maasserver_interface_ip_addresses  WHERE staticipaddress_id = ${IP_ID};
            DELETE FROM maasserver_staticipaddress         WHERE id = ${IP_ID};
          " >> "$LOG_FILE" 2>&1 || true
        fi

        if ! maas "$MAAS_PROFILE" interface link-subnet "$SYSTEM_ID" "$IFACE_ID" \
            mode=STATIC ip_address="$NB_PRIMARY_IP" subnet="$SUBNET_ID" >> "$LOG_FILE" 2>&1; then
          warn "${NB_DEVICE_NAME} (${SYSTEM_ID}) 靜態 IP 設定失敗，跳過 deploy"
          SKIPPED=$((SKIPPED + 1))
          continue
        fi
        info "${NB_DEVICE_NAME} 靜態 IP 設定完成：${NB_PRIMARY_IP}"
      fi

      # ── Deploy ────────────────────────────────────────────
      info "Deploy：${NB_DEVICE_NAME} (${SYSTEM_ID})"
      if maas "$MAAS_PROFILE" machine deploy "$SYSTEM_ID" user_data="$USER_DATA" >> "$LOG_FILE" 2>&1; then
        info "${NB_DEVICE_NAME} deploy 已觸發"
        DEPLOYED=$((DEPLOYED + 1))
      else
        warn "${NB_DEVICE_NAME} deploy 失敗，見 log：${LOG_FILE}"
        SKIPPED=$((SKIPPED + 1))
      fi

    done <<< "$READY_MACHINES"
  fi
fi

# ============================================================
# 摘要
# ============================================================
find "$LOG_BASE" -maxdepth 1 -type d -mtime +"$LOG_RETENTION" -exec rm -rf {} + 2>/dev/null || true
find "$LOG_BASE" -maxdepth 1 -type d -empty -exec rm -rf {} + 2>/dev/null || true

if [[ $COMMISSIONED -eq 0 && $DEPLOYED -eq 0 && $SKIPPED -eq 0 ]]; then
  rm -f "$LOG_FILE"
  rmdir "$LOG_DIR" 2>/dev/null || true
  exit 0
fi

section "執行完成"
[[ "$DRY_RUN" == true ]] && dryrun "DRY-RUN 模式：以上操作均未實際執行"
info "Commission 觸發：${COMMISSIONED} 台 / ${NEW_COUNT} 台"
info "Deploy    觸發：${DEPLOYED} 台 / ${READY_COUNT} 台"
[[ $SKIPPED -gt 0 ]] && warn "跳過（需人工處理）：${SKIPPED} 台"
info "Log：${LOG_FILE}"
