# xray-reality-setup

A single-script installer for [Xray-core](https://github.com/XTLS/Xray-core) with **VLESS + Reality** — the modern TLS-camouflage proxy that makes your traffic indistinguishable from a normal HTTPS connection to a legitimate site.

No fake certificates. No easily-fingerprinted patterns. No fiddly config files to hand-craft.

```
chmod +x xray-reality-setup.sh

# On your server (VPS):
sudo ./xray-reality-setup.sh server

# On your machine (Mac or Linux desktop):
./xray-reality-setup.sh client
```

---

## What is VLESS + Reality?

[Reality](https://github.com/XTLS/REALITY) is a TLS camouflage protocol built into Xray-core. Instead of presenting a self-signed certificate that screams "this is a proxy", Reality borrows the TLS handshake fingerprint of a real external domain — in this case, `cloudflare.com`. To a passive observer or a deep packet inspector, the connection is indistinguishable from a normal browser visiting Cloudflare over HTTPS.

VLESS is a lightweight, stateless transport protocol. Combined with Reality and the `xtls-rprx-vision` flow, it provides excellent performance with a minimal footprint.

---

## Requirements

| | Server | Client |
|---|---|---|
| **OS** | Linux (Debian / Ubuntu / RHEL) | macOS (Apple Silicon or Intel) or Linux |
| **Root** | Yes (`sudo`) | No |
| **Port** | 443 open inbound | No open ports needed |
| **Tools** | `curl`, `openssl` | `curl`, `openssl` |

The script handles the Xray binary installation automatically.

---

## Quickstart

### 1 — Server

Run this on any Linux VPS. The script will:

- Install Xray via the official installer
- Generate a fresh x25519 keypair, UUID, and short ID
- Write a server config on port 443 with Reality camouflage
- Open port 443 via `ufw` or `firewalld` if present
- Register and start a `systemd` service
- Print your VLESS connection link

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

Copy that link. You'll need it on the client.

---

### 2 — Client

Run this on your Mac or Linux desktop. The script will:

- Install Xray (via Homebrew on macOS, or direct download)
- Prompt you to paste the VLESS link from your server
- Parse all connection parameters from the link automatically
- Write a client config proxying through your server
- Register and start a `launchd` (macOS) or `systemd --user` (Linux) service
- Expose a local SOCKS5 proxy on `127.0.0.1:1080`
- Expose a local HTTP proxy on `127.0.0.1:1081`
- Run a live connection test to confirm everything works

```bash
./xray-reality-setup.sh client
```

---

## Using the proxy

Once the client is running, point any application at `127.0.0.1:1080` (SOCKS5) or `127.0.0.1:1081` (HTTP).

### Quick test

```bash
curl --proxy socks5://127.0.0.1:1080 https://ifconfig.me
```

The IP returned should be your server's IP, not your own.

### macOS system-wide proxy

**System Settings → Network → \[your connection\] → Proxies**

Enable **SOCKS Proxy** and set it to `127.0.0.1` port `1080`.

### Firefox

**Settings → Network Settings → Manual proxy configuration**

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

## Service management

### macOS

```bash
# Stop
launchctl unload ~/Library/LaunchAgents/com.xray.client.plist

# Start
launchctl load ~/Library/LaunchAgents/com.xray.client.plist

# Logs
tail -f ~/.config/xray/xray.log
```

### Linux (server)

```bash
systemctl status xray
systemctl stop xray
systemctl start xray
journalctl -u xray -f
```

### Linux (client)

```bash
systemctl --user status xray-client
systemctl --user stop xray-client
systemctl --user start xray-client
journalctl --user -u xray-client -f
```

---

## Other commands

```bash
# Check current status
./xray-reality-setup.sh status

# Stop xray
./xray-reality-setup.sh stop

# Remove everything (binary, configs, service files)
./xray-reality-setup.sh uninstall
```

---

## What gets installed / created

### Server (Linux)

| Path | Purpose |
|---|---|
| `/usr/local/bin/xray` | Xray binary |
| `/etc/xray/server.json` | Server config |
| `/etc/systemd/system/xray.service` | systemd unit |
| `~/.xray-vless-link.txt` | Your VLESS link (chmod 600) |
| `/var/log/xray.log` | Log file |

### Client (macOS)

| Path | Purpose |
|---|---|
| `/usr/local/bin/xray` | Xray binary |
| `~/.config/xray/client.json` | Client config |
| `~/Library/LaunchAgents/com.xray.client.plist` | launchd service |
| `~/.config/xray/xray.log` | Log file |

---

## How Reality camouflage works

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

The server never presents a self-signed cert. It participates in a real TLS handshake with a legitimate external host, then staples your key material on top. Observers see nothing unusual.

---

## Routing behaviour (client)

The client config routes traffic selectively:

- **Private IPs** (`10.x`, `192.168.x`, `172.16.x`) → direct (not tunnelled)
- **Chinese domains** (`geosite:cn`) → direct
- **Everything else** → through the VLESS+Reality tunnel

Edit `~/.config/xray/client.json` (macOS) or `/etc/xray/client.json` (Linux) to adjust routing rules.

---

## Troubleshooting

**Test times out or returns wrong IP**

Check the client is running: `./xray-reality-setup.sh status`

Confirm port 443 is open on the server: `nc -zv YOUR_SERVER_IP 443`

**Connection test returns your own IP**

The proxy is running but not being used. Confirm the application is configured to use `127.0.0.1:1080` as SOCKS5, not SOCKS4.

**macOS: `launchctl load` fails**

Check the log: `cat ~/.config/xray/xray.log`

Try running manually to see errors: `xray run -c ~/.config/xray/client.json`

**Server log shows no connections**

Verify the public key in your VLESS link matches the one in `/etc/xray/server.json`. If you regenerated keys, re-run the server setup and get a new VLESS link.

---

## Security notes

- The VLESS link contains your private connection credentials. Treat it like a password — don't share it publicly or commit it to a repository.
- The script generates a fresh UUID, keypair, and short ID on every server setup run. Existing client configs will stop working and need to be regenerated.
- The server config blocks outbound connections to RFC 1918 private ranges to prevent SSRF-style abuse.
- Port 443 is used by design — it's the standard HTTPS port and is rarely blocked.

---

## Acknowledgements

- [XTLS/Xray-core](https://github.com/XTLS/Xray-core) — the engine
- [XTLS/REALITY](https://github.com/XTLS/REALITY) — the camouflage protocol
- [XTLS/Xray-install](https://github.com/XTLS/Xray-install) — the official Linux installer, used on the server path

---

## Licence

MIT
