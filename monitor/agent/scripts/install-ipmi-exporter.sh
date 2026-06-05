#!/usr/bin/env bash
set -e

# ── constants ────────────────────────────────────────────────────────────────
readonly SCRIPT_NAME="install-ipmi-exporter"
readonly DEFAULT_VERSION="1.8.0"
readonly DEFAULT_PORT="9290"
readonly DEFAULT_IPMI_USER="admin"
readonly DEFAULT_IPMI_DRIVER="LAN_2_0"
readonly SERVICE_USER="ipmi_exporter"
readonly INSTALL_DIR="/usr/local/bin"
readonly CONFIG_DIR="/opt/monitor"
readonly CONFIG_FILE="${CONFIG_DIR}/ipmi.yml"
readonly SERVICE_FILE="/etc/systemd/system/ipmi_exporter.service"

mkdir -p "/tmp/monitor"
readonly LOG_FILE="/tmp/monitor/${SCRIPT_NAME}-$(date +%Y%m%d_%H%M%S).log"
readonly CRED_FILE="/tmp/monitor/.${SCRIPT_NAME}-credentials"

# ── helpers ──────────────────────────────────────────────────────────────────
SECTION=0
info()    { echo -e "\033[0;32m[INFO]\033[0m  $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "\033[0;33m[WARN]\033[0m  $*" | tee -a "$LOG_FILE"; }
section() { SECTION=$(( SECTION + 1 )); echo -e "\n\033[1;34m[${SECTION}]\033[0m $*" | tee -a "$LOG_FILE"; }
error()   { echo -e "\033[0;31m[ERROR]\033[0m $*" | tee -a "$LOG_FILE" >&2; exit 1; }

install_binary() {
  local url="https://github.com/prometheus-community/ipmi_exporter/releases/download/v${VERSION}/ipmi_exporter-${VERSION}.linux-${ARCH_TAG}.tar.gz"
  local tmp_dir
  tmp_dir=$(mktemp -d)

  info "Downloading ipmi_exporter ${VERSION} (${ARCH_TAG})..."
  curl -fsSL "$url" -o "${tmp_dir}/ipmi_exporter.tar.gz" >> "$LOG_FILE" 2>&1 \
    || error "Download failed, check network or version number"

  info "Extracting..."
  tar -xzf "${tmp_dir}/ipmi_exporter.tar.gz" -C "$tmp_dir" >> "$LOG_FILE" 2>&1

  install -m 755 \
    "${tmp_dir}/ipmi_exporter-${VERSION}.linux-${ARCH_TAG}/ipmi_exporter" \
    "${INSTALL_DIR}/ipmi_exporter"
  rm -rf "$tmp_dir"
  info "Binary installed to ${INSTALL_DIR}/ipmi_exporter"
}

# ── usage ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --version     VERSION   ipmi_exporter version (default: ${DEFAULT_VERSION})
  --port        PORT      listening port (default: ${DEFAULT_PORT})
  --ipmi-user   USER      IPMI username (default: ${DEFAULT_IPMI_USER})
  --ipmi-pass   PASS      IPMI password (required)
  --ipmi-driver DRIVER    IPMI driver (default: ${DEFAULT_IPMI_DRIVER})
  --help                  show this message
EOF
  exit 0
}

# ── parse args ────────────────────────────────────────────────────────────────
VERSION="$DEFAULT_VERSION"
PORT="$DEFAULT_PORT"
IPMI_USER="$DEFAULT_IPMI_USER"
IPMI_PASS=""
IPMI_DRIVER="$DEFAULT_IPMI_DRIVER"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)     VERSION="$2";     shift 2 ;;
    --port)        PORT="$2";        shift 2 ;;
    --ipmi-user)   IPMI_USER="$2";   shift 2 ;;
    --ipmi-pass)   IPMI_PASS="$2";   shift 2 ;;
    --ipmi-driver) IPMI_DRIVER="$2"; shift 2 ;;
    --help|-h)     usage ;;
    *) error "Unknown option: $1" ;;
  esac
done

[[ -z "$IPMI_PASS" ]] && error "--ipmi-pass is required"

# ── detect arch ───────────────────────────────────────────────────────────────
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  ARCH_TAG="amd64" ;;
  aarch64) ARCH_TAG="arm64" ;;
  armv7l)  ARCH_TAG="armv7" ;;
  *) error "Unsupported architecture: ${ARCH}" ;;
esac

# ── check root ────────────────────────────────────────────────────────────────
[[ "$EUID" -ne 0 ]] && error "This script must be run as root"

# ── disclaimer ────────────────────────────────────────────────────────────────
echo "============================================="
echo "  IPMI Exporter Installer  v${VERSION}  :${PORT}"
echo "============================================="
echo "  This script will:"
echo "    - Install freeipmi-tools"
echo "    - Create system user '${SERVICE_USER}'"
echo "    - Install binary to ${INSTALL_DIR}"
echo "    - Write config to ${CONFIG_FILE}"
echo "    - Register systemd service"
echo ""
echo "  Press Ctrl+C within 3 seconds to cancel..."
echo "============================================="
sleep 3

# ── [1] prerequisites ─────────────────────────────────────────────────────────
section "Checking prerequisites"
for cmd in curl tar; do
  if ! command -v "$cmd" &>/dev/null; then
    info "Installing ${cmd}..."
    apt-get install -y "$cmd" >> "$LOG_FILE" 2>&1 || error "Failed to install ${cmd}"
  else
    info "${cmd}: ok"
  fi
done

if ! command -v ipmi-sensors &>/dev/null; then
  info "Installing freeipmi-tools..."
  apt-get install -y freeipmi-tools >> "$LOG_FILE" 2>&1 || error "Failed to install freeipmi-tools"
else
  info "freeipmi-tools: ok"
fi

# ── [2] service user ──────────────────────────────────────────────────────────
section "Creating service user"
if id "$SERVICE_USER" &>/dev/null; then
  info "User ${SERVICE_USER} already exists, skipping"
else
  useradd --system --no-create-home --shell /usr/sbin/nologin "$SERVICE_USER"
  info "User ${SERVICE_USER} created"
fi

# ── [3] binary ────────────────────────────────────────────────────────────────
section "Installing binary"
if [[ -f "${INSTALL_DIR}/ipmi_exporter" ]]; then
  CURRENT_VER=$("${INSTALL_DIR}/ipmi_exporter" --version 2>&1 | awk 'NR==1{print $3}')
  if [[ "$CURRENT_VER" == "$VERSION" ]]; then
    info "ipmi_exporter ${VERSION} already installed, skipping"
  else
    info "Upgrading ${CURRENT_VER} → ${VERSION}"
    systemctl stop ipmi_exporter 2>/dev/null || true
    install_binary
  fi
else
  install_binary
fi

# ── [4] config ────────────────────────────────────────────────────────────────
section "Writing config"
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_FILE" <<EOF
modules:
  default:
    user: "${IPMI_USER}"
    pass: "${IPMI_PASS}"
    driver: "${IPMI_DRIVER}"
    privilege: "user"
    collectors:
      - bmc
      - ipmi
      - chassis
      - sel
EOF
chown "root:${SERVICE_USER}" "$CONFIG_FILE"
chmod 640 "$CONFIG_FILE"
info "Config written to ${CONFIG_FILE}"

install -m 600 /dev/null "$CRED_FILE"
cat > "$CRED_FILE" <<EOF
IPMI_USER=${IPMI_USER}
IPMI_PASS=${IPMI_PASS}
EOF
info "Credentials saved to ${CRED_FILE}"

# ── [5] systemd service ───────────────────────────────────────────────────────
section "Configuring systemd service"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Prometheus IPMI Exporter
After=network.target

[Service]
User=${SERVICE_USER}
Group=${SERVICE_USER}
ExecStart=${INSTALL_DIR}/ipmi_exporter --config.file=${CONFIG_FILE} --web.listen-address=:${PORT}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >> "$LOG_FILE" 2>&1
info "Service file written"

# ── [6] enable & start ────────────────────────────────────────────────────────
section "Starting service"
systemctl enable ipmi_exporter >> "$LOG_FILE" 2>&1
if systemctl is-active --quiet ipmi_exporter; then
  info "Restarting ipmi_exporter..."
  systemctl restart ipmi_exporter >> "$LOG_FILE" 2>&1
else
  systemctl start ipmi_exporter >> "$LOG_FILE" 2>&1
fi

sleep 2
systemctl is-active --quiet ipmi_exporter \
  || error "ipmi_exporter failed to start, check: journalctl -u ipmi_exporter"
info "ipmi_exporter is running"

# ── summary ───────────────────────────────────────────────────────────────────
HOST_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "============================================="
echo "  Installation Complete"
echo "============================================="
echo "  Endpoint    : http://${HOST_IP}:${PORT}/ipmi?target=<BMC_IP>"
echo "  Status      : $(systemctl is-active ipmi_exporter)"
echo "  Config      : ${CONFIG_FILE}"
echo "  Credentials : ${CRED_FILE}"
echo "  Log         : ${LOG_FILE}"
echo ""
echo "  [!] 請記錄 IPMI 帳密並考慮更換預設密碼"
echo "============================================="
