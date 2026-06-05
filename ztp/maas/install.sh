#!/bin/bash
set -e

# ============================================================
# MAAS Install Script (Non-interactive, defaults-based)
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

Non-interactive MAAS installation. Reads env.yaml if present; CLI flags override.

Mode:
  --mode  <mode>   Installation mode: region+rack | region | rack
                                      (default: region+rack)

MAAS:
  --maas-channel <channel> MAAS snap channel                   (default: 3.6/stable)
  --maas-url     <url>     MAAS API URL (auto-built from primary IP if omitted)

Database (region / region+rack only):
  --db-name      <name>    PostgreSQL database name             (default: maasdb)
  --db-user      <user>    PostgreSQL user                      (default: maas)
  --db-pass      <pass>    PostgreSQL password                  (default: maaspassword)

Admin (region / region+rack only):
  --admin-user   <user>    MAAS admin username                  (default: admin)
  --admin-pass   <pass>    MAAS admin password                  (default: admin)
  --admin-email  <email>   MAAS admin email                     (default: admin@local)

Rack only:
  --region-url   <url>     Region controller MAAS URL           (required for rack mode)
  --secret       <secret>  Region controller secret             (required for rack mode)

Other:
  --skip-dns               Skip systemd-resolved disable
  -h, --help               Show this help message

Examples:
  # region+rack with env.yaml
  sudo $(basename "$0")

  # region only
  sudo $(basename "$0") --mode region --admin-pass secret123

  # rack only
  sudo $(basename "$0") --mode rack --region-url http://192.168.1.x:5240/MAAS --secret <secret>
EOF
  exit 0
}

# ============================================================
# Defaults
# ============================================================
MODE="region+rack"
MAAS_CHANNEL="3.6/stable"
MAAS_URL=""
DB_NAME="maasdb"
DB_USER="maas"
DB_PASS="maaspassword"
ADMIN_USER="admin"
ADMIN_PASS="admin"
ADMIN_EMAIL="admin@local"
REGION_URL=""
SECRET=""
SKIP_DNS=false

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
    val=$(yq ".$1" < "${ENV_FILE}" 2>&1) || error "無法解析 env.yaml：${val}"
    [[ "$val" == "null" ]] && echo "" || echo "$val"
  }
  v=$(_y mode);         [[ -n "$v" ]] && MODE="$v"
  v=$(_y maas_channel); [[ -n "$v" ]] && MAAS_CHANNEL="$v"
  v=$(_y maas_url);     [[ -n "$v" ]] && MAAS_URL="$v"
  v=$(_y db_name);      [[ -n "$v" ]] && DB_NAME="$v"
  v=$(_y db_user);      [[ -n "$v" ]] && DB_USER="$v"
  v=$(_y db_pass);      [[ -n "$v" ]] && DB_PASS="$v"
  v=$(_y admin_user);   [[ -n "$v" ]] && ADMIN_USER="$v"
  v=$(_y admin_pass);   [[ -n "$v" ]] && ADMIN_PASS="$v"
  v=$(_y admin_email);  [[ -n "$v" ]] && ADMIN_EMAIL="$v"
  v=$(_y region_url);   [[ -n "$v" ]] && REGION_URL="$v"
  v=$(_y secret);       [[ -n "$v" ]] && SECRET="$v"
fi

# ============================================================
# Argument parsing
# ============================================================
CLI_ARGS_USED=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)        MODE="$2";        CLI_ARGS_USED=true; shift 2 ;;
    --maas-channel) MAAS_CHANNEL="$2"; CLI_ARGS_USED=true; shift 2 ;;
    --maas-url)    MAAS_URL="$2";    CLI_ARGS_USED=true; shift 2 ;;
    --db-name)     DB_NAME="$2";     CLI_ARGS_USED=true; shift 2 ;;
    --db-user)     DB_USER="$2";     CLI_ARGS_USED=true; shift 2 ;;
    --db-pass)     DB_PASS="$2";     CLI_ARGS_USED=true; shift 2 ;;
    --admin-user)  ADMIN_USER="$2";  CLI_ARGS_USED=true; shift 2 ;;
    --admin-pass)  ADMIN_PASS="$2";  CLI_ARGS_USED=true; shift 2 ;;
    --admin-email) ADMIN_EMAIL="$2"; CLI_ARGS_USED=true; shift 2 ;;
    --region-url)  REGION_URL="$2";  CLI_ARGS_USED=true; shift 2 ;;
    --secret)      SECRET="$2";      CLI_ARGS_USED=true; shift 2 ;;
    --skip-dns)    SKIP_DNS=true;    shift ;;
    -h|--help)     usage ;;
    *) error "Unknown option: $1. Use --help for usage." ;;
  esac
done

if [[ "$CLI_ARGS_USED" == true ]]; then
  cat > "$ENV_FILE" <<EOF
mode: ${MODE}
maas_channel: ${MAAS_CHANNEL}
maas_url: "${MAAS_URL}"
db_name: ${DB_NAME}
db_user: ${DB_USER}
db_pass: ${DB_PASS}
admin_user: ${ADMIN_USER}
admin_pass: ${ADMIN_PASS}
admin_email: ${ADMIN_EMAIL}
region_url: "${REGION_URL}"
secret: "${SECRET}"
EOF
  info "設定已回寫至 ${ENV_FILE}"
fi

# ============================================================
# 模式驗證
# ============================================================
case "$MODE" in
  region+rack|region|rack) ;;
  *) error "無效的 --mode: ${MODE}。可選值：region+rack | region | rack" ;;
esac

if [[ "$MODE" == "rack" ]]; then
  [[ -z "$REGION_URL" ]] && error "rack 模式需要 --region-url"
  [[ -z "$SECRET" ]]     && error "rack 模式需要 --secret"
  [[ -n "$DB_NAME" || -n "$DB_USER" ]] && \
    warn "rack 模式不需要 DB 設定，--db-* 參數將被忽略"
else
  [[ -z "$MAAS_URL" ]] && MAAS_URL="http://$(hostname -I | awk '{print $1}'):5240/MAAS"
fi

disclaimer
log "=== 開始安裝 MAAS (mode: ${MODE}) ==="

# ============================================================
# 1. 安裝必要套件
# ============================================================
section "安裝必要套件"

APT_PACKAGES=()
command -v snap &>/dev/null || APT_PACKAGES+=(snapd)
command -v curl &>/dev/null || APT_PACKAGES+=(curl)

if [[ "$MODE" != "rack" ]]; then
  command -v psql &>/dev/null || APT_PACKAGES+=(postgresql)
fi

if [[ ${#APT_PACKAGES[@]} -gt 0 ]]; then
  info "安裝缺少的套件: ${APT_PACKAGES[*]}"
  apt-get update -qq
  apt-get install -y "${APT_PACKAGES[@]}"
else
  info "所有必要工具已安裝"
fi

# ============================================================
# 2. DNS
# ============================================================
section "修復 DNS"

if [[ "$SKIP_DNS" == false ]]; then
  if systemctl is-active --quiet systemd-resolved; then
    systemctl disable systemd-resolved
    systemctl stop systemd-resolved
    info "systemd-resolved 已停止"
  fi
  rm -f /etc/resolv.conf
  printf "nameserver 8.8.8.8\nnameserver 1.1.1.1\n" > /etc/resolv.conf
  info "DNS 設定完成"
else
  info "跳過 DNS 設定"
fi

ping -c 1 8.8.8.8 &>/dev/null || error "網路不通，請確認網路設定"
info "網路連線正常"

# ============================================================
# 3. PostgreSQL（region / region+rack only）
# ============================================================
if [[ "$MODE" != "rack" ]]; then
  section "設定 PostgreSQL"

  if ! systemctl is-active --quiet postgresql; then
    apt-get install -y postgresql
  fi

  USER_EXISTS=$(sudo -u postgres psql -tAc \
    "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" 2>/dev/null || echo "0")
  if [[ "$USER_EXISTS" != "1" ]]; then
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"
    info "資料庫使用者 ${DB_USER} 建立完成"
  else
    warn "資料庫使用者 ${DB_USER} 已存在，跳過建立"
  fi

  DB_EXISTS=$(sudo -u postgres psql -tAc \
    "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" 2>/dev/null || echo "0")
  if [[ "$DB_EXISTS" != "1" ]]; then
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"
    info "資料庫 ${DB_NAME} 建立完成"
  else
    warn "資料庫 ${DB_NAME} 已存在，跳過建立"
  fi
fi

# ============================================================
# 4. MAAS 安裝與初始化
# ============================================================
section "安裝與初始化 MAAS"

if snap list maas &>/dev/null; then
  warn "MAAS 已安裝，跳過安裝"
else
  snap install maas --channel="${MAAS_CHANNEL}"
  info "MAAS 安裝完成"
fi

MAAS_CONF="/var/snap/maas/current/regiond.conf"

case "$MODE" in
  region+rack)
    if grep -q "database_host" "$MAAS_CONF" 2>/dev/null; then
      warn "MAAS 已初始化，跳過 init"
    else
      maas init region+rack \
        --database-uri "postgres://${DB_USER}:${DB_PASS}@localhost/${DB_NAME}" \
        --maas-url "${MAAS_URL}"
      info "MAAS 初始化完成 (region+rack)"
    fi
    ;;
  region)
    if grep -q "database_host" "$MAAS_CONF" 2>/dev/null; then
      warn "MAAS 已初始化，跳過 init"
    else
      maas init region \
        --database-uri "postgres://${DB_USER}:${DB_PASS}@localhost/${DB_NAME}" \
        --maas-url "${MAAS_URL}"
      info "MAAS 初始化完成 (region)"
    fi
    ;;
  rack)
    RACK_CONF="/var/snap/maas/current/rackd.conf"
    if grep -q "maas_url" "$RACK_CONF" 2>/dev/null; then
      warn "MAAS 已初始化，跳過 init"
    else
      maas init rack \
        --maas-url "${REGION_URL}" \
        --secret "${SECRET}"
      info "MAAS 初始化完成 (rack)"
    fi
    ;;
esac

if [[ "$MODE" != "rack" ]]; then
  ADMIN_EXISTS=$(sudo -u postgres psql -d "${DB_NAME}" -tAc \
    "SELECT 1 FROM auth_user WHERE username='${ADMIN_USER}';" 2>/dev/null || echo "")
  if [[ "$ADMIN_EXISTS" == "1" ]]; then
    warn "管理員帳號 ${ADMIN_USER} 已存在，跳過建立"
  else
    maas createadmin \
      --username "${ADMIN_USER}" \
      --password "${ADMIN_PASS}" \
      --email "${ADMIN_EMAIL}"
    info "管理員帳號 ${ADMIN_USER} 建立完成"
  fi
fi

# ============================================================
# 執行摘要
# ============================================================
HOST_IP=$(hostname -I | awk '{print $1}')

if [[ "$MODE" == "rack" ]]; then
  cat > "$CREDS_FILE" <<EOF
# Generated: $(date)
# Script: ${SCRIPT_NAME}
# Mode: rack
REGION_URL=${REGION_URL}
EOF
else
  MAAS_SECRET=$(cat /var/snap/maas/current/secret 2>/dev/null || echo "")
  cat > "$CREDS_FILE" <<EOF
# Generated: $(date)
# Script: ${SCRIPT_NAME}
# Mode: ${MODE}
ADMIN_USER=${ADMIN_USER}
ADMIN_PASS=${ADMIN_PASS}
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}
MAAS_URL=${MAAS_URL}
MAAS_SECRET=${MAAS_SECRET}
EOF
fi
chmod 600 "$CREDS_FILE"
log "敏感資訊已寫入 $CREDS_FILE"

section "安裝完成 (mode: ${MODE})"

if [[ "$MODE" == "rack" ]]; then
  echo -e "  模式         : ${GREEN}rack controller${NC}"
  echo -e "  Region URL   : ${GREEN}${REGION_URL}${NC}"
else
  echo -e "  模式         : ${GREEN}${MODE}${NC}"
  echo -e "  MAAS Web UI  : ${GREEN}http://${HOST_IP}:5240/MAAS${NC}"
  echo -e "  管理員帳號   : ${GREEN}${ADMIN_USER}${NC}"
  echo -e "  MAAS Channel : ${GREEN}${MAAS_CHANNEL}${NC}"
  echo -e "  DB 名稱      : ${GREEN}${DB_NAME}${NC}"
  if [[ "$MODE" == "region" ]]; then
    echo ""
    echo -e "  ${YELLOW}Rack 安裝時需要以下資訊：${NC}"
    echo -e "  MAAS URL     : ${GREEN}${MAAS_URL}${NC}"
    echo -e "  Secret       : ${BLUE}請查看 ${CREDS_FILE}${NC}"
  fi
fi

echo ""
echo -e "  Log 檔案     : ${BLUE}${LOG_FILE}${NC}"
echo -e "  敏感資訊     : ${BLUE}${CREDS_FILE}${NC}"
echo ""
echo -e "${YELLOW}⚠ 請記錄以上資訊，並立即修改所有預設密碼${NC}"
echo ""
maas status
