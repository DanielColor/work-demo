#!/bin/bash
set -eo pipefail

PROJECT="openldap"
LOG_FILE="/tmp/${PROJECT}/backup.log"

ENV_FILE="$(dirname "$0")/../.env"
if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
fi

BACKUP_DIR="${BACKUP_DIR:-/opt/openldap/backups}"
LDAP_HOST="${LDAP_HOST}"
LDAP_PORT="${LDAP_PORT}"
BIND_DN="${BIND_DN}"
BIND_PW="${BIND_PW}"
BASE_DN="${BASE_DN}"
KEEP_DAYS="${KEEP_DAYS:-7}"

STEP=0

# ── 顏色 ──────────────────────────────────────────────

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── 函式 ──────────────────────────────────────────────

info() {
  local msg="[INFO] $*"
  echo -e "${GREEN}${msg}${NC}"
  echo "$(date '+%Y-%m-%d %H:%M:%S') ${msg}" >> "$LOG_FILE"
}

warn() {
  local msg="[WARN] $*"
  echo -e "${YELLOW}${msg}${NC}" >&2
  echo "$(date '+%Y-%m-%d %H:%M:%S') ${msg}" >> "$LOG_FILE"
}

error() {
  local msg="[ERROR] $*"
  echo -e "${RED}${msg}${NC}" >&2
  echo "$(date '+%Y-%m-%d %H:%M:%S') ${msg}" >> "$LOG_FILE"
  exit 1
}

section() {
  STEP=$((STEP + 1))
  local msg="[${STEP}] $*"
  echo ""
  echo -e "${CYAN}=== ${msg} ===${NC}"
  echo "$(date '+%Y-%m-%d %H:%M:%S') === ${msg} ===" >> "$LOG_FILE"
}

install_pkg() {
  local pkg="$1"
  info "安裝 ${pkg} ..."
  if command -v apt-get > /dev/null 2>&1; then
    apt-get install -y "$pkg" > /dev/null 2>&1 || error "安裝 ${pkg} 失敗"
  elif command -v yum > /dev/null 2>&1; then
    yum install -y "$pkg" > /dev/null 2>&1 || error "安裝 ${pkg} 失敗"
  else
    error "找不到套件管理器，請手動安裝 ${pkg}"
  fi
}

check_deps() {
  if ! command -v ldapsearch > /dev/null 2>&1; then
    install_pkg "ldap-utils"
  fi
  if ! command -v tar > /dev/null 2>&1; then
    install_pkg "tar"
  fi
  if ! command -v find > /dev/null 2>&1; then
    install_pkg "findutils"
  fi
}

# ── --help ────────────────────────────────────────────

if [[ "${1:-}" == "--help" ]]; then
  echo "用法：$0 [--help]"
  echo ""
  echo "備份 LDAP 資料至 LDIF 並壓縮，自動清除舊備份"
  echo ""
  echo "設定（修改腳本頂部變數）："
  echo "  BACKUP_DIR  備份目錄    (預設: /opt/openldap/backups)"
  echo "  KEEP_DAYS   保留天數    (預設: 7)"
  echo "  BASE_DN     LDAP 根 DN  (預設: dc=example,dc=local)"
  echo "  BIND_DN     管理員 DN   (預設: cn=admin,dc=example,dc=local)"
  echo "  BIND_PW     管理員密碼  (由 .env 設定)"
  echo "  LDAP_HOST   LDAP 主機   (由 .env 設定)"
  echo "  LDAP_PORT   LDAP 埠號   (預設: 389)"
  exit 0
fi

# ── 初始化 ────────────────────────────────────────────

: "${LDAP_HOST:?需設定 LDAP_HOST}"
: "${LDAP_PORT:?需設定 LDAP_PORT}"
: "${BIND_DN:?需設定 BIND_DN}"
: "${BIND_PW:?需設定 BIND_PW}"
: "${BASE_DN:?需設定 BASE_DN}"

mkdir -p "/tmp/${PROJECT}" "$BACKUP_DIR"
touch "$LOG_FILE"

echo -e "${YELLOW}此腳本將備份 LDAP 資料，3 秒後繼續（Ctrl+C 取消）...${NC}"
sleep 3

check_deps

# ── 備份 ──────────────────────────────────────────────

section "匯出 LDIF"

DATE=$(date +%Y%m%d_%H%M%S)
OUTFILE="${BACKUP_DIR}/ldap_${DATE}.ldif"

ldapsearch -x \
  -H "ldap://${LDAP_HOST}:${LDAP_PORT}" \
  -D "$BIND_DN" \
  -w "$BIND_PW" \
  -b "$BASE_DN" \
  -LLL \
  > "$OUTFILE" || { rm -f "$OUTFILE"; error "ldapsearch 失敗"; }

if [[ ! -s "$OUTFILE" ]]; then
  rm -f "$OUTFILE"
  error "備份檔案為空"
fi

TARFILE="${OUTFILE%.ldif}.tar.gz"
tar -czf "$TARFILE" -C "$BACKUP_DIR" "$(basename "$OUTFILE")" || { rm -f "$OUTFILE" "$TARFILE"; error "壓縮失敗"; }
rm -f "$OUTFILE"
info "備份完成：${TARFILE}"

# ── 清除舊備份 ────────────────────────────────────────

section "清除舊備份"
find "$BACKUP_DIR" -name "ldap_*.tar.gz" -mtime +"$KEEP_DAYS" -delete
info "已清除 ${KEEP_DAYS} 天前的舊備份"
