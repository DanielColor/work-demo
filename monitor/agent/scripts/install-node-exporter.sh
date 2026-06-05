#!/usr/bin/env bash
set -e

# ── constants ────────────────────────────────────────────────────────────────
readonly SCRIPT_NAME="install-node-exporter"
readonly DEFAULT_VERSION="1.8.2"
readonly DEFAULT_PORT="9100"
readonly SERVICE_USER="node_exporter"
readonly INSTALL_DIR="/usr/local/bin"
readonly SERVICE_FILE="/etc/systemd/system/node_exporter.service"

mkdir -p "/tmp/monitor"
readonly LOG_FILE="/tmp/monitor/${SCRIPT_NAME}-$(date +%Y%m%d_%H%M%S).log"

# ── helpers ──────────────────────────────────────────────────────────────────
SECTION=0
info()    { echo -e "\033[0;32m[INFO]\033[0m  $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "\033[0;33m[WARN]\033[0m  $*" | tee -a "$LOG_FILE"; }
section() { SECTION=$(( SECTION + 1 )); echo -e "\n\033[1;34m[${SECTION}]\033[0m $*" | tee -a "$LOG_FILE"; }
error()   { echo -e "\033[0;31m[ERROR]\033[0m $*" | tee -a "$LOG_FILE" >&2; exit 1; }

install_binary() {
  local url="https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/node_exporter-${VERSION}.linux-${ARCH_TAG}.tar.gz"
  local tmp_dir
  tmp_dir=$(mktemp -d)

  info "Downloading node_exporter ${VERSION} (${ARCH_TAG})..."
  curl -fsSL "$url" -o "${tmp_dir}/node_exporter.tar.gz" >> "$LOG_FILE" 2>&1 \
    || error "Download failed, check network or version number"

  info "Extracting..."
  tar -xzf "${tmp_dir}/node_exporter.tar.gz" -C "$tmp_dir" >> "$LOG_FILE" 2>&1

  install -m 755 \
    "${tmp_dir}/node_exporter-${VERSION}.linux-${ARCH_TAG}/node_exporter" \
    "${INSTALL_DIR}/node_exporter"
  rm -rf "$tmp_dir"
  info "Binary installed to ${INSTALL_DIR}/node_exporter"
}

# ── usage ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --version VERSION   node_exporter version (default: ${DEFAULT_VERSION})
  --port    PORT      listening port (default: ${DEFAULT_PORT})
  --help              show this message
EOF
  exit 0
}

# ── parse args ────────────────────────────────────────────────────────────────
VERSION="$DEFAULT_VERSION"
PORT="$DEFAULT_PORT"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --port)    PORT="$2"; shift 2 ;;
    --help|-h) usage ;;
    *) error "Unknown option: $1" ;;
  esac
done

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
echo "  Node Exporter Installer  v${VERSION}  :${PORT}"
echo "============================================="
echo "  This script will:"
echo "    - Create system user '${SERVICE_USER}'"
echo "    - Install binary to ${INSTALL_DIR}"
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
if [[ -f "${INSTALL_DIR}/node_exporter" ]]; then
  CURRENT_VER=$("${INSTALL_DIR}/node_exporter" --version 2>&1 | awk 'NR==1{print $3}')
  if [[ "$CURRENT_VER" == "$VERSION" ]]; then
    info "node_exporter ${VERSION} already installed, skipping"
  else
    info "Upgrading ${CURRENT_VER} → ${VERSION}"
    systemctl stop node_exporter 2>/dev/null || true
    install_binary
  fi
else
  install_binary
fi

# ── [4] systemd service ───────────────────────────────────────────────────────
section "Configuring systemd service"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=${SERVICE_USER}
Group=${SERVICE_USER}
ExecStart=${INSTALL_DIR}/node_exporter --web.listen-address=:${PORT}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >> "$LOG_FILE" 2>&1
info "Service file written"

# ── [5] enable & start ────────────────────────────────────────────────────────
section "Starting service"
systemctl enable node_exporter >> "$LOG_FILE" 2>&1
if systemctl is-active --quiet node_exporter; then
  info "Restarting node_exporter..."
  systemctl restart node_exporter >> "$LOG_FILE" 2>&1
else
  systemctl start node_exporter >> "$LOG_FILE" 2>&1
fi

sleep 2
systemctl is-active --quiet node_exporter \
  || error "node_exporter failed to start, check: journalctl -u node_exporter"
info "node_exporter is running"

# ── summary ───────────────────────────────────────────────────────────────────
HOST_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "============================================="
echo "  Installation Complete"
echo "============================================="
echo "  Endpoint : http://${HOST_IP}:${PORT}/metrics"
echo "  Status   : $(systemctl is-active node_exporter)"
echo "  Log      : ${LOG_FILE}"
echo "============================================="
