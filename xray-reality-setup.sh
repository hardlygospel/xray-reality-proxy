#!/usr/bin/env bash
# =============================================================================
# Xray VLESS + Reality Setup Script
# Compatible with: macOS (Apple Silicon + Intel) | Linux (Debian/Ubuntu/RHEL)
# =============================================================================
#
# WHAT THIS DOES
# --------------
# Installs Xray-core and configures a VLESS + Reality proxy server (or client)
# on your machine. Reality is a TLS camouflage protocol — your traffic looks
# like a legitimate HTTPS connection to a real site (e.g. cloudflare.com).
# No fake certificates, no detectable fingerprint.
#
# HOW TO USE THIS SCRIPT
# ----------------------
# 1. SERVER SETUP (the machine that will carry your traffic — a VPS, remote box):
#      chmod +x xray-reality-setup.sh
#      sudo ./xray-reality-setup.sh server
#
#    After it runs, it will print:
#      - Your VLESS connection link (paste into any VLESS client)
#      - Your server config location
#      - Commands to start/stop/check the service
#
# 2. CLIENT SETUP — macOS (your Mac, or a Linux desktop):
#      chmod +x xray-reality-setup.sh
#      ./xray-reality-setup.sh client
#
#    You will be prompted to paste in the VLESS link from your server.
#    After it runs:
#      - Xray runs locally on SOCKS5 port 1080 and HTTP port 1081
#      - Point your browser/app proxy to: 127.0.0.1:1080 (SOCKS5)
#      - Or use: 127.0.0.1:1081 (HTTP proxy)
#
# DEVICE SETUP SUMMARY
# --------------------
#   VPS / Remote Server  →  run as: sudo ./xray-reality-setup.sh server
#   Your Mac             →  run as: ./xray-reality-setup.sh client
#   Linux desktop        →  run as: ./xray-reality-setup.sh client
#
# BROWSER / SYSTEM PROXY USAGE
# ------------------------------
# macOS System Proxy (after client setup):
#   System Settings > Network > [Your connection] > Proxies
#   Enable SOCKS Proxy: 127.0.0.1 port 1080
#   OR HTTP Proxy:      127.0.0.1 port 1081
#
# Firefox:
#   Settings > Network Settings > Manual proxy configuration
#   SOCKS Host: 127.0.0.1  Port: 1080  Type: SOCKS5
#
# curl:
#   curl --proxy socks5://127.0.0.1:1080 https://ifconfig.me
#
# =============================================================================

set -euo pipefail

# ── Colour output ─────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
err()     { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}${CYAN}── $* ──${RESET}"; }

# ── Detect OS and architecture ────────────────────────────────────────────────
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Darwin) PLATFORM="mac" ;;
  Linux)  PLATFORM="linux" ;;
  *)      err "Unsupported OS: $OS" ;;
esac

case "$ARCH" in
  x86_64|amd64)   XRAY_ARCH="64" ;;
  arm64|aarch64)  XRAY_ARCH="arm64-v8a" ;;
  *)              err "Unsupported architecture: $ARCH" ;;
esac

# ── Paths ─────────────────────────────────────────────────────────────────────
if [[ "$PLATFORM" == "mac" ]]; then
  XRAY_BIN="/usr/local/bin/xray"
  XRAY_CONF_DIR="$HOME/.config/xray"
  SERVER_CONF="$XRAY_CONF_DIR/server.json"
  CLIENT_CONF="$XRAY_CONF_DIR/client.json"
  SERVICE_DIR="$HOME/Library/LaunchAgents"
  SERVICE_PLIST="$SERVICE_DIR/com.xray.client.plist"
  LOG_FILE="$HOME/.config/xray/xray.log"
else
  XRAY_BIN="/usr/local/bin/xray"
  XRAY_CONF_DIR="/etc/xray"
  SERVER_CONF="$XRAY_CONF_DIR/server.json"
  CLIENT_CONF="$XRAY_CONF_DIR/client.json"
  LOG_FILE="/var/log/xray.log"
fi

VLESS_LINK_FILE="$HOME/.xray-vless-link.txt"
XRAY_VERSION="1.8.11"

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  echo -e "${BOLD}Usage:${RESET} $0 [server|client|stop|status|uninstall]"
  echo
  echo "  server    — Install and configure Xray as a VLESS+Reality server"
  echo "  client    — Install and configure Xray as a local SOCKS5/HTTP proxy"
  echo "  stop      — Stop the running Xray process"
  echo "  status    — Show Xray service status"
  echo "  uninstall — Remove Xray and all configs"
  echo
  echo "Run 'server' on your VPS. Run 'client' on your Mac/desktop."
  exit 1
}

[[ $# -lt 1 ]] && usage
MODE="$1"

# ── Install Xray binary ───────────────────────────────────────────────────────
install_xray() {
  section "Installing Xray $XRAY_VERSION"

  if command -v xray &>/dev/null; then
    INSTALLED_VER=$(xray version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "unknown")
    ok "Xray already installed (version: $INSTALLED_VER)"
    return
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  if [[ "$PLATFORM" == "mac" ]]; then
    # Try Homebrew first
    if command -v brew &>/dev/null; then
      info "Installing via Homebrew..."
      brew install xray 2>/dev/null && ok "Installed via Homebrew" && return
    fi
    # Fall back to direct download
    local fname="Xray-macos-${XRAY_ARCH}.zip"
    local url="https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/${fname}"
    info "Downloading $url"
    curl -L --retry 3 -o "$tmpdir/$fname" "$url"
    unzip -q "$tmpdir/$fname" -d "$tmpdir/xray"
    install -m 755 "$tmpdir/xray/xray" "$XRAY_BIN"
  else
    # Linux — use the official installer script
    if command -v curl &>/dev/null; then
      info "Running official Xray installer..."
      bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh) \
        @ "${XRAY_VERSION}" --without-geodata 2>&1 | tail -5
      # Official installer puts binary at /usr/local/bin/xray
      ok "Xray installed via official script"
      return
    fi
    err "curl is required. Install it first: apt install curl / yum install curl"
  fi

  xray version &>/dev/null && ok "Xray binary OK" || err "Xray binary not working after install"
}

# ── Generate crypto material ──────────────────────────────────────────────────
generate_keys() {
  section "Generating cryptographic keys"
  KEYS_JSON=$(xray x25519)
  PRIVATE_KEY=$(echo "$KEYS_JSON" | grep -i 'Private key' | awk '{print $NF}')
  PUBLIC_KEY=$(echo "$KEYS_JSON"  | grep -i 'Public key'  | awk '{print $NF}')
  UUID=$(xray uuid)
  # Short ID: 8 hex chars
  SHORT_ID=$(openssl rand -hex 4)
  ok "UUID:        $UUID"
  ok "Public key:  $PUBLIC_KEY"
  ok "Short ID:    $SHORT_ID"
}

# ── Write server config ───────────────────────────────────────────────────────
write_server_config() {
  section "Writing server config → $SERVER_CONF"
  mkdir -p "$XRAY_CONF_DIR"

  # Get server's public IP
  SERVER_IP=$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null || \
              curl -4 -s --max-time 5 api.ipify.org 2>/dev/null || \
              echo "YOUR_SERVER_IP")

  cat > "$SERVER_CONF" <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "${LOG_FILE}",
    "error": "${LOG_FILE}"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "cloudflare.com:443",
          "xver": 0,
          "serverNames": ["cloudflare.com", "www.cloudflare.com"],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": ["${SHORT_ID}"]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "block"
      }
    ]
  }
}
EOF

  ok "Server config written"

  # Build the VLESS link
  # Format: vless://UUID@IP:PORT?encryption=none&flow=xtls-rprx-vision&security=reality
  #         &sni=SNI&pbk=PUBLIC_KEY&sid=SHORT_ID&type=tcp&fp=chrome#tag
  VLESS_LINK="vless://${UUID}@${SERVER_IP}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=cloudflare.com&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&fp=chrome&spx=%2F#TPPL-Reality"
  echo "$VLESS_LINK" > "$VLESS_LINK_FILE"
  chmod 600 "$VLESS_LINK_FILE"
}

# ── Set up server systemd service (Linux) ─────────────────────────────────────
setup_server_service_linux() {
  section "Configuring systemd service"
  cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray VLESS+Reality Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=${XRAY_BIN} run -c ${SERVER_CONF}
Restart=on-failure
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable xray
  systemctl restart xray
  ok "xray.service enabled and started"
}

# ── Set up server launchd service (macOS) ─────────────────────────────────────
setup_server_service_mac() {
  section "Configuring launchd service (server)"
  mkdir -p "$SERVICE_DIR"
  cat > "$SERVICE_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.xray.server</string>
  <key>ProgramArguments</key>
  <array>
    <string>${XRAY_BIN}</string>
    <string>run</string>
    <string>-c</string>
    <string>${SERVER_CONF}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${LOG_FILE}</string>
  <key>StandardErrorPath</key>
  <string>${LOG_FILE}</string>
</dict>
</plist>
EOF
  launchctl unload "$SERVICE_PLIST" 2>/dev/null || true
  launchctl load "$SERVICE_PLIST"
  ok "Launchd service loaded"
}

# ── Write client config ───────────────────────────────────────────────────────
write_client_config() {
  section "Writing client config → $CLIENT_CONF"
  mkdir -p "$XRAY_CONF_DIR"

  echo
  echo -e "${BOLD}Paste your VLESS link from the server (then press Enter, then Ctrl+D):${RESET}"
  echo -e "${YELLOW}Example: vless://UUID@1.2.3.4:443?encryption=none&flow=xtls-rprx-vision...${RESET}"
  echo
  VLESS_INPUT=$(cat)

  # Parse the VLESS link
  # vless://UUID@HOST:PORT?params#name
  UUID_C=$(echo "$VLESS_INPUT" | grep -oP '(?<=vless://)([^@]+)(?=@)')
  HOST_C=$(echo "$VLESS_INPUT" | grep -oP '(?<=@)([^:]+)(?=:)')
  PORT_C=$(echo "$VLESS_INPUT" | grep -oP '(?<=:)(\d+)(?=\?)')
  PBK_C=$(echo  "$VLESS_INPUT" | grep -oP '(?<=pbk=)([^&]+)')
  SID_C=$(echo  "$VLESS_INPUT" | grep -oP '(?<=sid=)([^&]+)')
  SNI_C=$(echo  "$VLESS_INPUT" | grep -oP '(?<=sni=)([^&]+)' || echo "cloudflare.com")
  FP_C=$(echo   "$VLESS_INPUT" | grep -oP '(?<=fp=)([^&]+)'  || echo "chrome")

  [[ -z "$UUID_C" || -z "$HOST_C" || -z "$PORT_C" || -z "$PBK_C" || -z "$SID_C" ]] && \
    err "Could not parse VLESS link. Check that you copied the full link from the server."

  info "Server:      $HOST_C:$PORT_C"
  info "UUID:        $UUID_C"
  info "Public key:  $PBK_C"
  info "Short ID:    $SID_C"
  info "SNI:         $SNI_C"

  cat > "$CLIENT_CONF" <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "${LOG_FILE}",
    "error": "${LOG_FILE}"
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 1080,
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true
      },
      "tag": "socks-in",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 1081,
      "protocol": "http",
      "settings": {},
      "tag": "http-in"
    }
  ],
  "outbounds": [
    {
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "${HOST_C}",
            "port": ${PORT_C},
            "users": [
              {
                "id": "${UUID_C}",
                "flow": "xtls-rprx-vision",
                "encryption": "none"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "fingerprint": "${FP_C}",
          "serverName": "${SNI_C}",
          "publicKey": "${PBK_C}",
          "shortId": "${SID_C}",
          "spiderX": "/"
        }
      },
      "tag": "proxy"
    },
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "domain": ["geosite:cn"],
        "outboundTag": "direct"
      }
    ]
  }
}
EOF

  ok "Client config written"
}

# ── Set up client launchd service (macOS) ────────────────────────────────────
setup_client_service_mac() {
  section "Configuring launchd service (client)"
  mkdir -p "$SERVICE_DIR"
  cat > "$SERVICE_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.xray.client</string>
  <key>ProgramArguments</key>
  <array>
    <string>${XRAY_BIN}</string>
    <string>run</string>
    <string>-c</string>
    <string>${CLIENT_CONF}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${LOG_FILE}</string>
  <key>StandardErrorPath</key>
  <string>${LOG_FILE}</string>
</dict>
</plist>
EOF
  launchctl unload "$SERVICE_PLIST" 2>/dev/null || true
  launchctl load "$SERVICE_PLIST"
  ok "Launchd client service loaded"
}

# ── Set up client systemd service (Linux desktop) ────────────────────────────
setup_client_service_linux() {
  section "Configuring systemd user service (client)"
  mkdir -p "$HOME/.config/systemd/user"
  cat > "$HOME/.config/systemd/user/xray-client.service" <<EOF
[Unit]
Description=Xray VLESS+Reality Client
After=network.target

[Service]
Type=simple
ExecStart=${XRAY_BIN} run -c ${CLIENT_CONF}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable xray-client
  systemctl --user restart xray-client
  ok "xray-client user service enabled and started"
}

# ── Open firewall port (Linux server only) ────────────────────────────────────
open_firewall() {
  if command -v ufw &>/dev/null; then
    ufw allow 443/tcp comment "Xray Reality" 2>/dev/null && ok "ufw: 443/tcp allowed"
  elif command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --add-port=443/tcp 2>/dev/null
    firewall-cmd --reload 2>/dev/null
    ok "firewalld: 443/tcp allowed"
  else
    warn "No recognised firewall tool found — ensure port 443 is open manually"
  fi
}

# ── Print server summary ──────────────────────────────────────────────────────
print_server_summary() {
  local link
  link=$(cat "$VLESS_LINK_FILE")

  echo
  echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════════════${RESET}"
  echo -e "${BOLD}${GREEN}  Xray VLESS+Reality server is up!${RESET}"
  echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════════════${RESET}"
  echo
  echo -e "${BOLD}Your VLESS link (copy this to your client machine):${RESET}"
  echo
  echo -e "${YELLOW}$link${RESET}"
  echo
  echo -e "Link also saved to: ${CYAN}$VLESS_LINK_FILE${RESET}"
  echo
  echo -e "${BOLD}Service commands:${RESET}"
  if [[ "$PLATFORM" == "linux" ]]; then
    echo "  Status:  systemctl status xray"
    echo "  Stop:    systemctl stop xray"
    echo "  Start:   systemctl start xray"
    echo "  Logs:    journalctl -u xray -f"
  else
    echo "  Stop:    launchctl unload $SERVICE_PLIST"
    echo "  Start:   launchctl load $SERVICE_PLIST"
    echo "  Logs:    tail -f $LOG_FILE"
  fi
  echo
  echo -e "${BOLD}Next step:${RESET} Run this script on your client machine:"
  echo "  ./xray-reality-setup.sh client"
  echo "  (paste the VLESS link above when prompted)"
  echo
}

# ── Print client summary ──────────────────────────────────────────────────────
print_client_summary() {
  echo
  echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════════════${RESET}"
  echo -e "${BOLD}${GREEN}  Xray client running!${RESET}"
  echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════════════${RESET}"
  echo
  echo -e "${BOLD}Proxy endpoints (local only):${RESET}"
  echo -e "  SOCKS5:  ${CYAN}127.0.0.1:1080${RESET}"
  echo -e "  HTTP:    ${CYAN}127.0.0.1:1081${RESET}"
  echo
  echo -e "${BOLD}Quick test:${RESET}"
  echo "  curl --proxy socks5://127.0.0.1:1080 https://ifconfig.me"
  echo "  (should return your server's IP, not your own)"
  echo
  echo -e "${BOLD}macOS System Proxy:${RESET}"
  echo "  System Settings → Network → [connection] → Proxies"
  echo "  SOCKS Proxy: 127.0.0.1  Port: 1080"
  echo
  echo -e "${BOLD}Firefox:${RESET}"
  echo "  Settings → Network Settings → Manual proxy"
  echo "  SOCKS Host: 127.0.0.1  Port: 1080  SOCKS5"
  echo "  ✓ Proxy DNS when using SOCKS5"
  echo
  echo -e "${BOLD}Service commands:${RESET}"
  if [[ "$PLATFORM" == "mac" ]]; then
    echo "  Stop:    launchctl unload $SERVICE_PLIST"
    echo "  Start:   launchctl load $SERVICE_PLIST"
    echo "  Logs:    tail -f $LOG_FILE"
  else
    echo "  Status:  systemctl --user status xray-client"
    echo "  Stop:    systemctl --user stop xray-client"
    echo "  Logs:    journalctl --user -u xray-client -f"
  fi
  echo
}

# ── Stop ──────────────────────────────────────────────────────────────────────
do_stop() {
  if [[ "$PLATFORM" == "mac" ]]; then
    launchctl unload "$SERVICE_PLIST" 2>/dev/null && ok "Xray stopped" || warn "Service not loaded"
  else
    systemctl stop xray 2>/dev/null || systemctl --user stop xray-client 2>/dev/null || warn "No service found to stop"
    ok "Stopped"
  fi
}

# ── Status ────────────────────────────────────────────────────────────────────
do_status() {
  if [[ "$PLATFORM" == "mac" ]]; then
    launchctl list | grep xray || echo "No xray services found in launchd"
    echo
    pgrep -a xray && ok "Xray process is running" || warn "Xray is not running"
  else
    systemctl status xray 2>/dev/null || systemctl --user status xray-client 2>/dev/null || warn "No xray service found"
  fi
}

# ── Uninstall ─────────────────────────────────────────────────────────────────
do_uninstall() {
  warn "This will remove Xray, all configs, and service files."
  read -rp "Continue? [y/N]: " CONFIRM
  [[ "${CONFIRM,,}" != "y" ]] && echo "Cancelled." && exit 0

  if [[ "$PLATFORM" == "mac" ]]; then
    launchctl unload "$SERVICE_PLIST" 2>/dev/null || true
    rm -f "$SERVICE_PLIST"
    rm -f "$XRAY_BIN"
    rm -rf "$XRAY_CONF_DIR"
  else
    systemctl stop xray 2>/dev/null || true
    systemctl disable xray 2>/dev/null || true
    rm -f /etc/systemd/system/xray.service
    systemctl --user stop xray-client 2>/dev/null || true
    systemctl --user disable xray-client 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/xray-client.service"
    rm -f "$XRAY_BIN"
    rm -rf "$XRAY_CONF_DIR"
  fi

  rm -f "$VLESS_LINK_FILE"
  ok "Xray uninstalled"
}

# ── Main ──────────────────────────────────────────────────────────────────────
case "$MODE" in

  server)
    echo -e "\n${BOLD}${CYAN}Xray VLESS+Reality — SERVER MODE${RESET}\n"

    if [[ "$PLATFORM" == "linux" && "$EUID" -ne 0 ]]; then
      err "Server setup requires root. Run: sudo $0 server"
    fi

    install_xray
    generate_keys
    write_server_config
    open_firewall

    if [[ "$PLATFORM" == "linux" ]]; then
      setup_server_service_linux
    else
      setup_server_service_mac
    fi

    print_server_summary
    ;;

  client)
    echo -e "\n${BOLD}${CYAN}Xray VLESS+Reality — CLIENT MODE${RESET}\n"

    install_xray
    write_client_config

    if [[ "$PLATFORM" == "mac" ]]; then
      setup_client_service_mac
    else
      # Linux client: use user systemd if not root, system if root
      setup_client_service_linux
    fi

    sleep 1
    print_client_summary

    info "Testing connection..."
    sleep 2
    TEST_IP=$(curl -s --max-time 8 --proxy socks5://127.0.0.1:1080 ifconfig.me 2>/dev/null || echo "FAILED")
    if [[ "$TEST_IP" == "FAILED" || -z "$TEST_IP" ]]; then
      warn "Test failed — Xray may still be starting up. Try:"
      warn "  curl --proxy socks5://127.0.0.1:1080 https://ifconfig.me"
    else
      ok "Connection test passed! Outbound IP: $TEST_IP"
    fi
    ;;

  stop)      do_stop ;;
  status)    do_status ;;
  uninstall) do_uninstall ;;
  *)         usage ;;

esac
