#!/bin/bash
set -e

# ============================================================
# Netbox Install Script (Non-interactive, defaults-based)
# ============================================================

PROJECT="ztp"
SCRIPT_NAME=$(basename "$0" .sh)
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
LOG_DIR="/tmp/${PROJECT}"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}-${TIMESTAMP}.log"
CREDS_FILE="${LOG_DIR}/.${SCRIPT_NAME}-credentials"
mkdir -p "$LOG_DIR"

SECTION_COUNTER=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m'

log()     { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"; }
info()    { echo -e "${GREEN}[INFO]${NC} $1"; log "[INFO] $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; log "[WARN] $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; log "[ERROR] $1"; exit 1; }

section() {
  SECTION_COUNTER=$((SECTION_COUNTER + 1))
  echo -e "\n${BLUE}==============================${NC}"
  echo -e "${BLUE} ${SECTION_COUNTER}. $1${NC}"
  echo -e "${BLUE}==============================${NC}"
  log "=== ${SECTION_COUNTER}. $1 ==="
}

disclaimer() {
  echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
  echo -e "${YELLOW} 警告：本腳本使用預設帳號密碼                  ${NC}"
  echo -e "${YELLOW} 僅適用於測試 / lab 環境                       ${NC}"
  echo -e "${YELLOW} 請勿直接用於生產環境                          ${NC}"
  echo -e "${YELLOW} 部署後請立即修改所有預設密碼                  ${NC}"
  echo -e "${YELLOW} 本腳本造成的任何損失，使用者自行負責          ${NC}"
  echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
  sleep 3
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Non-interactive Netbox installation via netbox-docker.
Reads env.yaml if present; CLI flags override.

Options:
  --port         <port>    Host port to expose Netbox Web UI  (default: 80)
  --dir          <path>    Installation directory             (default: /opt/netbox-docker)
  --admin-user   <user>    Netbox superuser username          (default: admin)
  --admin-pass   <pass>    Netbox superuser password          (default: <CHANGE_ME>)
  --admin-email  <email>   Netbox superuser email             (default: admin@local)
  --admin-token  <token>   Netbox superuser API token         (default: 0123456789abcdef0123456789abcdef01234567)
  -h, --help               Show this help message

Examples:
  sudo $(basename "$0")
  sudo $(basename "$0") --port 8080 --admin-pass secret123
EOF
  exit 0
}

# ============================================================
# Defaults
# ============================================================
PORT=80
INSTALL_DIR="/opt/netbox-docker"
ADMIN_USER="admin"
ADMIN_PASS="<CHANGE_ME>"
ADMIN_EMAIL="admin@local"
ADMIN_TOKEN="0123456789abcdef0123456789abcdef01234567"

[[ $EUID -ne 0 ]] && error "請用 root 或 sudo 執行此腳本"

# ============================================================
# env.yaml（若存在則覆蓋預設值，CLI flags 仍可再覆蓋）
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/env.yaml"
if [[ -f "$ENV_FILE" ]]; then
  if ! command -v yq &>/dev/null; then
    apt-get install -y yq || error "yq 安裝失敗，請手動安裝後重試"
    info "yq 安裝完成"
  fi
  _y() {
    local val
    val=$(yq ".$1" "${ENV_FILE}")
    [[ "$val" == "null" ]] && echo "" || echo "$val"
  }
  v="$(_y port)";         [[ -n "$v" ]] && PORT="$v"
  v="$(_y install_dir)";  [[ -n "$v" ]] && INSTALL_DIR="$v"
  v="$(_y admin_user)";   [[ -n "$v" ]] && ADMIN_USER="$v"
  v="$(_y admin_pass)";   [[ -n "$v" ]] && ADMIN_PASS="$v"
  v="$(_y admin_email)";  [[ -n "$v" ]] && ADMIN_EMAIL="$v"
  v="$(_y admin_token)";  [[ -n "$v" ]] && ADMIN_TOKEN="$v"
fi

# ============================================================
# Argument parsing
# ============================================================
CLI_ARGS_USED=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)        PORT="$2";        CLI_ARGS_USED=true; shift 2 ;;
    --dir)         INSTALL_DIR="$2"; CLI_ARGS_USED=true; shift 2 ;;
    --admin-user)  ADMIN_USER="$2";  CLI_ARGS_USED=true; shift 2 ;;
    --admin-pass)  ADMIN_PASS="$2";  CLI_ARGS_USED=true; shift 2 ;;
    --admin-email) ADMIN_EMAIL="$2"; CLI_ARGS_USED=true; shift 2 ;;
    --admin-token) ADMIN_TOKEN="$2"; CLI_ARGS_USED=true; shift 2 ;;
    -h|--help) usage ;;
    *) error "Unknown option: $1. Use --help for usage." ;;
  esac
done

if [[ "$CLI_ARGS_USED" == true ]]; then
  cat > "$ENV_FILE" <<EOF
port: ${PORT}
install_dir: ${INSTALL_DIR}
admin_user: ${ADMIN_USER}
admin_pass: ${ADMIN_PASS}
admin_email: ${ADMIN_EMAIL}
admin_token: ${ADMIN_TOKEN}
EOF
  info "設定已回寫至 ${ENV_FILE}"
fi

disclaimer
log "=== 開始安裝 Netbox ==="

# ============================================================
# 1. 檢測並安裝必要工具
# ============================================================
section "檢測並安裝必要工具"

APT_PACKAGES=()
command -v git    &>/dev/null || APT_PACKAGES+=(git)
command -v curl   &>/dev/null || APT_PACKAGES+=(curl)
command -v docker &>/dev/null || APT_PACKAGES+=(docker.io docker-compose-v2)

if [[ ${#APT_PACKAGES[@]} -gt 0 ]]; then
  info "安裝缺少的套件: ${APT_PACKAGES[*]}"
  apt-get update -qq
  apt-get install -y "${APT_PACKAGES[@]}"
else
  info "所有必要工具已安裝"
fi

if ! systemctl is-active --quiet docker; then
  systemctl enable --now docker
  info "Docker 服務已啟動"
fi

# ============================================================
# 2. Clone netbox-docker
# ============================================================
section "Clone netbox-docker"

if [[ -d "$INSTALL_DIR" ]]; then
  warn "$INSTALL_DIR 已存在，跳過 clone"
else
  git clone -q https://github.com/netbox-community/netbox-docker "$INSTALL_DIR"
  info "Clone 完成：$INSTALL_DIR"
fi

# ============================================================
# 3. 設定 docker-compose.override.yml
# ============================================================
section "設定 docker-compose.override.yml"

cd "$INSTALL_DIR"

DATA_DIR="${INSTALL_DIR}/data"
mkdir -p \
  "${DATA_DIR}/postgres" \
  "${DATA_DIR}/media" \
  "${DATA_DIR}/reports" \
  "${DATA_DIR}/scripts"

OVERRIDE_TPL="${SCRIPT_DIR}/compose.override.yml"
[[ -f "$OVERRIDE_TPL" ]] || error "找不到 override 範本：${OVERRIDE_TPL}"

if [[ ! -f docker-compose.override.yml ]]; then
  export PORT DATA_DIR ADMIN_USER ADMIN_PASS ADMIN_EMAIL ADMIN_TOKEN
  envsubst < "$OVERRIDE_TPL" > docker-compose.override.yml
  info "docker-compose.override.yml 建立完成"
else
  warn "docker-compose.override.yml 已存在，跳過"
fi

# ============================================================
# 4. 啟動 Netbox
# ============================================================
section "啟動 Netbox"

docker compose pull -q
docker compose up -d

# ============================================================
# 執行摘要
# ============================================================
HOST_IP=$(hostname -I | awk '{print $1}')

cat > "$CREDS_FILE" <<EOF
# Generated: $(date)
# Script: ${SCRIPT_NAME}
ADMIN_USER=${ADMIN_USER}
ADMIN_PASS=${ADMIN_PASS}
ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_TOKEN=${ADMIN_TOKEN}
EOF
chmod 600 "$CREDS_FILE"
log "敏感資訊已寫入 $CREDS_FILE"

section "安裝完成"
echo -e "  Netbox Web UI : ${GREEN}http://${HOST_IP}:${PORT}${NC}"
echo -e "  管理員帳號    : ${GREEN}${ADMIN_USER}${NC}"
echo -e "  安裝目錄      : ${GREEN}${INSTALL_DIR}${NC}"
echo ""
echo -e "  Log 檔案      : ${BLUE}${LOG_FILE}${NC}"
echo -e "  敏感資訊      : ${BLUE}${CREDS_FILE}${NC}"
echo ""
echo -e "${YELLOW}⚠ 請記錄以上資訊，並立即修改所有預設密碼與 API Token${NC}"
