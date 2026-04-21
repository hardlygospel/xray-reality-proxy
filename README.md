# 🔒 Xray VLESS + Reality Setup

[![Stars](https://img.shields.io/github/stars/hardlygospel/xray-reality-proxy?style=for-the-badge&color=yellow)](https://github.com/hardlygospel/xray-reality-proxy/stargazers) [![Forks](https://img.shields.io/github/forks/hardlygospel/xray-reality-proxy?style=for-the-badge&color=blue)](https://github.com/hardlygospel/xray-reality-proxy/network/members) [![Issues](https://img.shields.io/github/issues/hardlygospel/xray-reality-proxy?style=for-the-badge&color=red)](https://github.com/hardlygospel/xray-reality-proxy/issues) [![Last Commit](https://img.shields.io/github/last-commit/hardlygospel/xray-reality-proxy?style=for-the-badge&color=green)](https://github.com/hardlygospel/xray-reality-proxy/commits) [![License](https://img.shields.io/badge/License-GPL_v3-blue?style=for-the-badge)](https://github.com/hardlygospel/xray-reality-proxy/blob/main/LICENSE) [![macOS](https://img.shields.io/badge/macOS-supported-brightgreen?style=for-the-badge&logo=apple)](https://github.com/hardlygospel/xray-reality-proxy) [![Linux](https://img.shields.io/badge/Linux-supported-brightgreen?style=for-the-badge&logo=linux)](https://github.com/hardlygospel/xray-reality-proxy) [![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnubash)](https://github.com/hardlygospel/xray-reality-proxy) [![Docker](https://img.shields.io/badge/Docker-ready-2496ED?style=for-the-badge&logo=docker)](https://github.com/hardlygospel/xray-reality-proxy) [![Maintained](https://img.shields.io/badge/Maintained-yes-brightgreen?style=for-the-badge)](https://github.com/hardlygospel/xray-reality-proxy) [![Repo Size](https://img.shields.io/github/repo-size/hardlygospel/xray-reality-proxy?style=for-the-badge)](https://github.com/hardlygospel/xray-reality-proxy) [![Code Size](https://img.shields.io/github/languages/code-size/hardlygospel/xray-reality-proxy?style=for-the-badge)](https://github.com/hardlygospel/xray-reality-proxy)
> A single-script installer for [Xray-core](https://github.com/XTLS/Xray-core) with **VLESS + Reality** — the modern TLS-camouflage proxy that makes your traffic indistinguishable from a normal HTTPS connection to a legitimate site. 🕵️

No fake certificates. No easily-fingerprinted patterns. No fiddly config files to hand-craft.

---

## ⚡ Quick Start

```bash
chmod +x xray-reality-setup.sh

# 🖥️ On your server (VPS):
sudo ./xray-reality-setup.sh server

# 💻 On your machine (Mac or Linux):
./xray-reality-setup.sh client
```

---

## 🤔 What is VLESS + Reality?

[Reality](https://github.com/XTLS/REALITY) is a TLS camouflage protocol built into Xray-core. Instead of presenting a self-signed certificate that screams "this is a proxy", Reality borrows the TLS handshake fingerprint of a real external domain — in this case, `cloudflare.com`. To a passive observer or a deep packet inspector, the connection is indistinguishable from a normal browser visiting Cloudflare over HTTPS.

VLESS is a lightweight, stateless transport protocol. Combined with Reality and the `xtls-rprx-vision` flow, it provides excellent performance with a minimal footprint.

---

## ✅ Requirements

| | 🖥️ Server | 💻 Client |
|---|---|---|
| **OS** | Linux (Debian / Ubuntu / RHEL) | 🍎 macOS or 🐧 Linux |
| **Root** | Yes (`sudo`) | No |
| **Port** | 443 open inbound | No open ports needed |
| **Tools** | `curl`, `openssl` | `curl`, `openssl` |

The script handles the Xray binary installation automatically.

---

## 🚀 Setup

### 1️⃣ Server

Run this on any Linux VPS. The script will:

- 📦 Install Xray via the official installer
- 🔑 Generate a fresh x25519 keypair, UUID, and short ID
- ⚙️ Write a server config on port 443 with Reality camouflage
- 🔓 Open port 443 via `ufw` or `firewalld` if present
- 🔄 Register and start a `systemd` service
- 🔗 Print your VLESS connection link

```bash
sudo ./xray-reality-setup.sh server
```

At the end you'll see something like:

```
Your VLESS link (copy this to your client machine):

vless://a1b2c3d4-...@203.0.113.10:443?encryption=none&flow=xtls-rprx-vision
      &security=reality&sni=cloudflare.com&pbk=<pubkey>&sid=<shortid>
      &type=tcp&fp=chrome#TPPL-Reality
```

> 📋 Copy that link — you'll need it on the client.

---

### 2️⃣ Client

Run this on your Mac or Linux desktop. The script will:

- 📦 Install Xray (via Homebrew on macOS, or direct download)
- 📋 Prompt you to paste the VLESS link from your server
- 🔍 Parse all connection parameters from the link automatically
- ⚙️ Write a client config proxying through your server
- 🔄 Register and start a `launchd` (macOS) or `systemd --user` (Linux) service
- 🧦 Expose a local SOCKS5 proxy on `127.0.0.1:1080`
- 🌐 Expose a local HTTP proxy on `127.0.0.1:1081`
- ✅ Run a live connection test to confirm everything works

```bash
./xray-reality-setup.sh client
```

---

## 🌐 Using the Proxy

Once running, point any application at `127.0.0.1:1080` (SOCKS5) or `127.0.0.1:1081` (HTTP).

### Quick test

```bash
curl --proxy socks5://127.0.0.1:1080 https://ifconfig.me
```

> The IP returned should be your server's IP, not your own.

### macOS system-wide

**System Settings → Network → \[your connection\] → Proxies** → Enable **SOCKS Proxy** → `127.0.0.1:1080`

### Firefox

| Field | Value |
|---|---|
| SOCKS Host | `127.0.0.1` |
| Port | `1080` |
| Type | SOCKS5 |
| Proxy DNS | ✅ enabled |

### curl

```bash
curl --proxy socks5://127.0.0.1:1080 https://example.com
```

### Python requests

```python
proxies = {"https": "socks5://127.0.0.1:1080"}
requests.get("https://example.com", proxies=proxies)
```

---

## 🔧 Service Management

### 🍎 macOS

```bash
launchctl unload ~/Library/LaunchAgents/com.xray.client.plist   # Stop
launchctl load ~/Library/LaunchAgents/com.xray.client.plist     # Start
tail -f ~/.config/xray/xray.log                                  # Logs
```

### 🐧 Linux (server)

```bash
systemctl status xray
systemctl stop xray
systemctl start xray
journalctl -u xray -f
```

### 🐧 Linux (client)

```bash
systemctl --user status xray-client
systemctl --user stop xray-client
systemctl --user start xray-client
journalctl --user -u xray-client -f
```

---

## 🛠️ Other Commands

```bash
./xray-reality-setup.sh status     # Check current status
./xray-reality-setup.sh stop       # Stop Xray
./xray-reality-setup.sh uninstall  # Remove everything
```

---

## 📁 What Gets Installed

### 🖥️ Server (Linux)

| Path | Purpose |
|---|---|
| `/usr/local/bin/xray` | Xray binary |
| `/etc/xray/server.json` | Server config |
| `/etc/systemd/system/xray.service` | systemd unit |
| `~/.xray-vless-link.txt` | Your VLESS link (chmod 600) |
| `/var/log/xray.log` | Log file |

### 💻 Client (macOS)

| Path | Purpose |
|---|---|
| `/usr/local/bin/xray` | Xray binary |
| `~/.config/xray/client.json` | Client config |
| `~/Library/LaunchAgents/com.xray.client.plist` | launchd service |
| `~/.config/xray/xray.log` | Log file |

---

## 🕵️ How Reality Camouflage Works

```
Your machine                 Internet                  Your VPS
    │                           │                          │
    │── TLS ClientHello ────────►│                          │
    │   (looks like Chrome       │                          │
    │    visiting cloudflare.com)│                          │
    │                           │◄── TCP connect ──────────│
    │                           │    (Xray makes the real   │
    │                           │     TLS handshake happen) │
    │◄── TLS ServerHello ───────│                          │
    │   (real Cloudflare cert    │                          │
    │    + your key material)    │                          │
    │                           │                          │
    │══ Encrypted VLESS tunnel ══════════════════════════► │
        (inside what looks like a normal HTTPS session)
```

The server never presents a self-signed cert. Observers see nothing unusual.

---

## 🔀 Routing Behaviour (Client)

- 🏠 **Private IPs** (`10.x`, `192.168.x`, `172.16.x`) → direct
- 🇨🇳 **Chinese domains** (`geosite:cn`) → direct
- 🌍 **Everything else** → through the VLESS+Reality tunnel

Edit `~/.config/xray/client.json` (macOS) or `/etc/xray/client.json` (Linux) to adjust routing rules.

---

## 🔒 Security Notes

- ⚠️ Your VLESS link contains private credentials — treat it like a password. Don't share it or commit it to a repo.
- 🔄 Every server setup run generates a fresh UUID, keypair, and short ID — existing clients will need new configs.
- 🛡️ The server blocks outbound connections to RFC 1918 private ranges to prevent SSRF-style abuse.
- ✅ Port 443 is used by design — standard HTTPS port, rarely blocked.

---

## 🔍 Troubleshooting

| Problem | Fix |
|---|---|
| Test times out or returns wrong IP | Run `./xray-reality-setup.sh status` and check port 443 is open |
| Connection test returns your own IP | Confirm the app is using `127.0.0.1:1080` as SOCKS5, not SOCKS4 |
| macOS: `launchctl load` fails | Check `cat ~/.config/xray/xray.log` or run `xray run -c ~/.config/xray/client.json` |
| Server log shows no connections | Verify the public key in your VLESS link matches `/etc/xray/server.json` |

---

## 🙏 Acknowledgements

- [XTLS/Xray-core](https://github.com/XTLS/Xray-core) — the engine
- [XTLS/REALITY](https://github.com/XTLS/REALITY) — the camouflage protocol
- [XTLS/Xray-install](https://github.com/XTLS/Xray-install) — the official Linux installer

---

## 📄 Licence

This project is licensed under the **GNU General Public License v3.0**.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg?style=for-the-badge)](https://github.com/hardlygospel/jellyfin-mediastack/blob/main/LICENSE)

You are free to use, modify, and distribute this software under the terms of the GPL-3.0. See the [full licence](https://github.com/hardlygospel/jellyfin-mediastack/blob/main/LICENSE) for details.
