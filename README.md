# Xray-VLESS-Reality-Setup-Script

#Installs Xray-core and configures a VLESS + Reality proxy server (or client)  on your machine.
#Reality is a TLS camouflage protocol — your traffic looks
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
