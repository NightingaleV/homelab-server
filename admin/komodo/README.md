# Komodo

Komodo is a tool to build and deploy software across many servers. It provides a web UI for managing Docker containers, stacks, and deployments across multiple machines.

**Docs:** https://komo.do/docs

## Quick Start

1. **Copy and configure environment:**
   ```bash
   cp .env.example .env
   # Edit .env and change all CHANGE_ME values
   ```

2. **Generate secure secrets:**
   ```bash
   # Generate random values for secrets
   openssl rand -hex 32  # Use for KOMODO_PASSKEY
   openssl rand -hex 32  # Use for KOMODO_WEBHOOK_SECRET
   openssl rand -hex 32  # Use for KOMODO_JWT_SECRET
   ```

3. **Ensure networks exist:**
   ```bash
   docker network create admin 2>/dev/null || true
   docker network create proxy 2>/dev/null || true
   ```

4. **Create volume directories:**
   ```bash
   mkdir -p /mnt/nas/DockerServices/komodo/{mongo/data,mongo/config,backups}
   mkdir -p /etc/komodo
   ```

5. **Start the stack:**
   ```bash
   docker compose up -d
   ```

6. **Access Komodo:**
   - Direct: http://192.168.68.90:9120
   - Via Traefik: https://komodo.slavik.tech

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Komodo Core (9120)                       │
│                    Web UI + API                             │
└─────────────────────┬───────────────────────────────────────┘
                      │ HTTPS (passkey auth)
      ┌───────────────┼───────────────┬───────────────┐
      ▼               ▼               ▼               ▼
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│Periphery │   │Periphery │   │Periphery │   │Periphery │
│ (local)  │   │ LXC #1   │   │ LXC #2   │   │ LXC #3   │
│  :8120   │   │  :8120   │   │  :8120   │   │  :8120   │
└──────────┘   └──────────┘   └──────────┘   └──────────┘
```

---

## Installing Periphery on Remote LXC/VMs

Periphery agents run on each server you want to manage. They communicate with Komodo Core using a shared passkey.

### Option A: Automated Install Script (Recommended)

```bash
# SSH into your LXC/VM
ssh root@192.168.68.XX

# Run the official setup script
curl -sSL https://raw.githubusercontent.com/moghtech/komodo/main/scripts/setup-periphery.py | python3

# Or specify a version
curl -sSL https://raw.githubusercontent.com/moghtech/komodo/main/scripts/setup-periphery.py | python3 - --version=v1.15.0
```

### Option B: Manual Install (Debian/Ubuntu)

```bash
# 1. Download the binary
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    BINARY="periphery-aarch64"
else
    BINARY="periphery-x86_64"
fi

curl -sSL "https://github.com/moghtech/komodo/releases/latest/download/${BINARY}" -o /usr/local/bin/periphery
chmod +x /usr/local/bin/periphery

# 2. Create config directory
mkdir -p /etc/komodo

# 3. Create config file
cat > /etc/komodo/periphery.config.toml << 'EOF'
## Passkeys that this Periphery accepts (comma-separated)
## Must match KOMODO_PASSKEY from your Komodo Core
passkeys = ["YOUR_KOMODO_PASSKEY_HERE"]

## SSL Configuration (recommended)
ssl_enabled = true
ssl_key_file = ""   # Leave empty for auto-generated self-signed
ssl_cert_file = ""  # Leave empty for auto-generated self-signed

## Port to listen on
port = 8120

## Allowed IPs (empty = allow all, or specify ["192.168.68.0/24"])
allowed_ips = []

## Include only specific disk mounts for accurate reporting
include_disk_mounts = ["/etc/hostname"]

## Disable web terminal access
disable_terminals = false
EOF

# 4. Create systemd service
cat > /etc/systemd/system/periphery.service << 'EOF'
[Unit]
Description=Komodo Periphery Agent
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=/usr/local/bin/periphery
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 5. Enable and start
systemctl daemon-reload
systemctl enable periphery
systemctl start periphery

# 6. Verify
systemctl status periphery
```

### Option C: Docker-based Periphery (on remote host)

Create this `docker-compose.yml` on the remote machine:

```yaml
services:
  periphery:
    image: ghcr.io/moghtech/komodo-periphery:latest
    container_name: komodo-periphery
    restart: unless-stopped
    ports:
      - 8120:8120
    environment:
      - PERIPHERY_PASSKEYS=YOUR_KOMODO_PASSKEY_HERE
      - PERIPHERY_SSL_ENABLED=true
      - PERIPHERY_INCLUDE_DISK_MOUNTS=/etc/hostname
      - TZ=Europe/Prague
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /proc:/proc
      - /etc/komodo:/etc/komodo
```

---

## Adding Servers to Komodo

1. Open Komodo UI → **Servers** → **+ New Server**
2. Enter details:
   - **Name:** Descriptive name (e.g., "Media-Server")
   - **Address:** `https://192.168.68.XX:8120`
3. Click **Create**

The server should connect automatically if the passkey matches.

---

## Useful Commands

**View logs:**
```bash
docker compose logs -f core
docker compose logs -f periphery
```

**Restart stack:**
```bash
docker compose restart
```

**Update to latest:**
```bash
docker compose pull
docker compose up -d
```

**Check Periphery status on remote host:**
```bash
systemctl status periphery
journalctl -u periphery -f
```

---

## Troubleshooting

### Server shows "Disconnected"
1. Verify Periphery is running: `systemctl status periphery`
2. Check passkey matches between Core and Periphery config
3. Test connectivity: `curl -k https://192.168.68.XX:8120/health`
4. Check firewall allows port 8120

### MongoDB connection issues
```bash
docker compose logs mongo
# Ensure volume permissions are correct
ls -la /mnt/nas/DockerServices/komodo/mongo/
```

### Periphery won't start
```bash
journalctl -u periphery -n 50
# Common issues: missing Docker, invalid config TOML
```

---

## References

- [Komodo Docs](https://komo.do/docs)
- [GitHub Repository](https://github.com/moghtech/komodo)
- [Core Config Options](https://github.com/moghtech/komodo/blob/main/config/core.config.toml)
- [Periphery Config Options](https://github.com/moghtech/komodo/blob/main/config/periphery.config.toml)
