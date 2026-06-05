#!/bin/bash
set -e

PROJECT="openldap"
LOG_FILE="/tmp/${PROJECT}/add-user.log"
CREDS_FILE="/tmp/${PROJECT}/.add-user-credentials"

ENV_FILE="$(dirname "$0")/../.env"
if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
fi

BASE_DN="${BASE_DN}"
BIND_DN="${BIND_DN}"
BIND_PW="${BIND_PW}"
LDAP_HOST="${LDAP_HOST}"
LDAP_PORT="${LDAP_PORT}"
MAIL_DOMAIN="${MAIL_DOMAIN}"
USER_OU="ou=Users,${BASE_DN}"

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
  if ! command -v ldapsearch > /dev/null 2>&1 || \
     ! command -v ldapadd > /dev/null 2>&1; then
    install_pkg "ldap-utils"
  fi
  command -v python3 > /dev/null 2>&1 || error "缺少必要工具：python3"
}

# ── --help ────────────────────────────────────────────

if [[ "${1:-}" == "--help" ]]; then
  echo "用法：$0 [--help]"
  echo ""
  echo "互動式新增 LDAP 使用者，UID（即 email）/ CN / SN / 密碼均自動由全名推導"
  echo ""
  echo "設定（修改腳本頂部變數）："
  echo "  BASE_DN      LDAP 根 DN    (預設: dc=example,dc=local)"
  echo "  BIND_DN      管理員 DN     (預設: cn=admin,dc=example,dc=local)"
  echo "  BIND_PW      管理員密碼    (預設: <CHANGE_ME>)"
  echo "  LDAP_HOST    LDAP 主機     (預設: 192.168.1.x)"
  echo "  LDAP_PORT    LDAP 埠號     (預設: 389)"
  echo "  MAIL_DOMAIN  郵件網域      (預設: example.local)"
  exit 0
fi

# ── 初始化 ────────────────────────────────────────────

mkdir -p "/tmp/${PROJECT}"
touch "$LOG_FILE"

echo -e "${YELLOW}此腳本將新增 LDAP 使用者，3 秒後繼續（Ctrl+C 取消）...${NC}"
sleep 3

check_deps

# ── 讀取 CN ───────────────────────────────────────────

section "讀取使用者資訊"
read -rp "輸入使用者全名（名 姓）: " FULL_NAME

if [[ -z "$FULL_NAME" ]]; then
  error "姓名不可為空"
fi

# ── 自動推導欄位 ──────────────────────────────────────

NORMALIZED=$(echo "$FULL_NAME" | sed 's/[._,;:\-]/ /g')
CN=$(echo "$NORMALIZED" | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
SN=$(echo "$NORMALIZED" | awk '{print $NF}' | tr '[:upper:]' '[:lower:]')
MAIL_NAME=$(echo "$FULL_NAME" | sed 's/[., ;:\-]/_/g' | tr '[:upper:]' '[:lower:]')
UID_NAME="${MAIL_NAME}@${MAIL_DOMAIN}"
MAIL="$UID_NAME"
DATE=$(date +%Y%m%d)
PASSWORD="${MAIL_NAME}${DATE}"

# ── 冪等性：檢查 UID 是否已存在 ──────────────────────

section "檢查使用者是否已存在"
if ldapsearch -x \
    -H "ldap://${LDAP_HOST}:${LDAP_PORT}" \
    -D "$BIND_DN" -w "$BIND_PW" \
    -b "uid=${UID_NAME},${USER_OU}" \
    -s base "(objectClass=*)" > /dev/null 2>&1; then
  error "使用者 ${UID_NAME} 已存在"
fi
info "UID ${UID_NAME} 可用"

# ── 產生密碼 hash ─────────────────────────────────────

section "產生密碼"
HASHED_PW=$(python3 -c "
import hashlib, os, base64, sys
pw = sys.argv[1].encode()
salt = os.urandom(4)
h = hashlib.sha1(pw + salt)
print('{SSHA}' + base64.b64encode(h.digest() + salt).decode())
" "$PASSWORD")
if [[ -z "$HASHED_PW" ]]; then
  error "無法產生密碼 hash"
fi
info "密碼 hash 產生成功"

# ── 確認 ──────────────────────────────────────────────

section "確認新增"
echo ""
echo "  SN   : $SN"
echo "  CN   : $CN"
echo "  UID  : $UID_NAME"
echo "  DN   : uid=${UID_NAME},${USER_OU}"
echo ""
read -rp "確認新增？ (y/N) " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "取消"
  exit 0
fi

# ── 確保 ou=Users 存在 ────────────────────────────────

section "確認 ou=Users"
if ! ldapsearch -x \
    -H "ldap://${LDAP_HOST}:${LDAP_PORT}" \
    -D "$BIND_DN" -w "$BIND_PW" \
    -b "$USER_OU" -s base "(objectClass=*)" > /dev/null 2>&1; then
  info "建立 ${USER_OU} ..."
  ldapadd -x \
    -H "ldap://${LDAP_HOST}:${LDAP_PORT}" \
    -D "$BIND_DN" -w "$BIND_PW" <<EOF || error "建立 ou=Users 失敗"
dn: $USER_OU
objectClass: organizationalUnit
ou: Users
EOF
fi
info "${USER_OU} 就緒"

# ── 新增使用者 ────────────────────────────────────────

section "新增使用者"
ldapadd -x \
  -H "ldap://${LDAP_HOST}:${LDAP_PORT}" \
  -D "$BIND_DN" -w "$BIND_PW" <<EOF || error "新增使用者失敗"
dn: uid=${UID_NAME},${USER_OU}
objectClass: inetOrgPerson
uid: $UID_NAME
cn: $CN
sn: $SN
mail: $MAIL
userPassword: $HASHED_PW
EOF

info "使用者 ${UID_NAME} 新增成功"

# ── 儲存憑證 ──────────────────────────────────────────

section "儲存憑證"
cat >> "$CREDS_FILE" <<EOF
使用者：$UID_NAME
DN：uid=${UID_NAME},${USER_OU}
Mail：$MAIL
密碼：$PASSWORD
建立時間：$(date '+%Y-%m-%d %H:%M:%S')
EOF
chmod 600 "$CREDS_FILE"

echo ""
echo "  憑證已儲存至：$CREDS_FILE"
echo "  請提醒使用者登入後修改預設密碼"
