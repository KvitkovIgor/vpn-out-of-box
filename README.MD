# VPN Host

A production-ready, one-command VPN deployment solution that sets up two powerful, censorship-resistant VPN protocols on your Linux server.

```
┌─────────────────────────────────────────────────────────────────┐
│                         VPN Host                                │
│                                                                 │
│   ┌─────────────────────┐       ┌─────────────────────────┐     │
│   │      X-Ray          │       │     AmneziaWG Easy      │     │
│   │   VLESS + Reality   │       │   WireGuard + Amnezia   │     │
│   │                     │       │                         │     │
│   │   Port: 443         │       │   VPN: 51820/UDP        │     │
│   │   Protocol: HTTPS   │       │   Web UI: 51821/TCP     │     │
│   └─────────────────────┘       └─────────────────────────┘     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Features

| Feature | X-Ray (VLESS + Reality) | AmneziaWG Easy |
|---------|------------------------|----------------|
| **Protocol** | VLESS over Reality | WireGuard with Amnezia obfuscation |
| **Obfuscation** | TLS fingerprint spoofing (Chrome) | Anti-DPI obfuscation |
| **Port** | 443 (HTTPS) | 51820 (UDP) |
| **Management** | CLI + Import Links | Web UI + QR Codes |
| **Best For** | Censored networks | General use, mobile |

### Why Two Protocols?

- **X-Ray VLESS + Reality**: Designed specifically for bypassing advanced censorship. Traffic appears as normal HTTPS to Google, making it nearly impossible to detect or block.
- **AmneziaWG**: Modified WireGuard with obfuscation that defeats Deep Packet Inspection (DPI). Easy to use with built-in web management.

---

## Quick Start

### Prerequisites

- Ubuntu 20.04+ or Debian-based Linux server
- Root or sudo access
- Public static IP address
- Open ports: `443`, `51820/UDP`, `51821`

---

## VM Installation Guide

### Step 1: Connect to Your VM

```bash
# Connect via SSH (replace with your server details)
ssh root@YOUR_SERVER_IP

# Or with a specific SSH key
ssh -i ~/.ssh/your_key root@YOUR_SERVER_IP

# Or with a specific user (then use sudo for commands)
ssh your_user@YOUR_SERVER_IP
```

### Step 2: Upload Project Files

**Option A: Using SCP (from your local machine)**

```bash
# Upload the entire project folder
scp -r /path/to/vpn-host root@YOUR_SERVER_IP:/root/

# Or upload individual files
scp setup-vpn.sh vpn.sh root@YOUR_SERVER_IP:/root/vpn-host/
```

**Option B: Using Git**

```bash
# On your VM
git clone https://github.com/KvitkovIgor/vpn-out-of-box.git
cd vpn-out-of-box
```

**Option C: Copy-paste method**

```bash
# Create directory on VM
mkdir -p /root/vpn-host
cd /root/vpn-host

# Create files using nano/vim and paste content
nano setup-vpn.sh
nano vpn.sh
```

### Step 3: Set Executable Permissions

```bash
# Navigate to the project directory
cd /root/vpn-host

# Make scripts executable
chmod +x setup-vpn.sh
chmod +x vpn.sh

# Verify permissions
ls -la *.sh
# Should show: -rwxr-xr-x for both files
```

### Step 4: Run Installation

```bash
# Run the setup script
sudo ./setup-vpn.sh
```

---

### One-Command Installation

```bash
sudo ./setup-vpn.sh
```

That's it! The script will:

1. Detect your OS and verify compatibility
2. Install Docker and Docker Compose (if needed)
3. Auto-detect your server's public IP
4. Generate secure credentials and keys
5. Configure both VPN services
6. Start everything in Docker containers
7. Display your connection information

---

## Architecture

```
                    ┌─────────────────────────────────────────┐
                    │              Your Server                │
                    │                                         │
   Internet         │  ┌─────────────────────────────────┐   │
       │            │  │         Docker Compose          │   │
       │            │  │                                 │   │
       ▼            │  │  ┌───────────┐  ┌───────────┐  │   │
  ┌─────────┐       │  │  │   X-Ray   │  │ AmneziaWG │  │   │
  │ Client  │◄─────►│  │  │ Container │  │ Container │  │   │
  │  Apps   │       │  │  │           │  │           │  │   │
  └─────────┘       │  │  │ :443      │  │ :51820    │  │   │
                    │  │  │           │  │ :51821    │  │   │
                    │  │  └───────────┘  └───────────┘  │   │
                    │  │                                 │   │
                    │  └─────────────────────────────────┘   │
                    │                                         │
                    └─────────────────────────────────────────┘
```

### Generated Files

| File | Purpose |
|------|---------|
| `.vpn_credentials` | Encrypted credentials storage (chmod 600) |
| `xray/config.json` | X-Ray server configuration |
| `docker-compose.yml` | Container orchestration |
| `CONNECTION_INFO.txt` | Human-readable connection details |

---

## Management Commands

Control your VPN services with the management script:

```bash
./vpn.sh [command]
```

### Available Commands

| Command | Description |
|---------|-------------|
| `start` | Start all VPN services |
| `stop` | Stop all VPN services |
| `restart` | Restart all services |
| `status` | Show container status and health |
| `logs` | Follow logs from all containers |
| `logs-xray` | Follow X-Ray container logs |
| `logs-amnezia` | Follow AmneziaWG container logs |
| `info` | Display connection credentials |
| `link` | Generate X-Ray import link |
| `reset` | Reset configuration and reconfigure |
| `uninstall` | Remove everything (containers, images, configs) |
| `help` | Show help menu |

### Options

| Option | Description |
|--------|-------------|
| `-y`, `--yes`, `--force` | Skip confirmation prompts (for reset/uninstall) |

### Examples

```bash
# Check if services are running
./vpn.sh status

# View real-time logs
./vpn.sh logs

# Get your connection info again
./vpn.sh info

# Generate a shareable X-Ray link
./vpn.sh link

# Completely start fresh
./vpn.sh reset

# Reset without confirmation prompt
./vpn.sh reset -y

# Uninstall without confirmation prompt
./vpn.sh uninstall --yes
```

---

## Client Setup

### X-Ray (VLESS + Reality)

After installation, you'll receive an import link like:

```
vless://uuid@server:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.google.com&fp=chrome&pbk=public_key&sid=short_id&type=tcp#VPN-Server
```

#### Recommended Clients

| Platform | Client | Link |
|----------|--------|------|
| Windows | v2rayN | [GitHub](https://github.com/2dust/v2rayN) |
| macOS | V2rayU | [GitHub](https://github.com/yanue/V2rayU) |
| Android | v2rayNG | [Google Play](https://play.google.com/store/apps/details?id=com.v2ray.ang) |
| iOS | Shadowrocket | [App Store](https://apps.apple.com/app/shadowrocket/id932747118) |
| Linux | v2rayA | [GitHub](https://github.com/v2rayA/v2rayA) |

**How to connect:**
1. Copy the import link from `./vpn.sh link`
2. In your client, choose "Import from clipboard" or paste the link
3. Connect!

---

### AmneziaWG Easy

Access the web management interface:

```
http://YOUR_SERVER_IP:51821
```

Login with the password shown during setup (also in `./vpn.sh info`).

#### Recommended Clients

| Platform | Client |
|----------|--------|
| Windows | [AmneziaVPN](https://amnezia.org/en/downloads) |
| macOS | [AmneziaVPN](https://amnezia.org/en/downloads) |
| Android | [AmneziaVPN](https://play.google.com/store/apps/details?id=org.amnezia.vpn) |
| iOS | [AmneziaVPN](https://apps.apple.com/app/amneziavpn/id1600529900) |
| Linux | [AmneziaVPN](https://amnezia.org/en/downloads) |

**How to connect:**
1. Open the web UI at `http://YOUR_SERVER_IP:51821`
2. Click "Create Client" and give it a name
3. Scan the QR code with AmneziaVPN app, or download the config file
4. Connect!

---

## Security Considerations

### Network Security

Ensure these ports are accessible in your firewall:

```bash
# UFW example
sudo ufw allow 443/tcp      # X-Ray
sudo ufw allow 51820/udp    # AmneziaWG VPN
sudo ufw allow 51821/tcp    # AmneziaWG Web UI
```

### Credential Security

- All credentials are stored in `.vpn_credentials` with `chmod 600`
- The file is only readable by root
- Never share your private keys or credentials publicly
- The AmneziaWG web UI is password-protected

### Recommended Hardening

```bash
# Restrict web UI access to specific IPs (optional)
sudo ufw allow from YOUR_HOME_IP to any port 51821

# Or use SSH tunnel for web UI access
ssh -L 51821:localhost:51821 user@your_server
# Then access: http://localhost:51821
```

---

## Troubleshooting

### Services won't start

```bash
# Check Docker status
sudo systemctl status docker

# Check container logs
./vpn.sh logs

# Verify ports aren't in use
sudo netstat -tulpn | grep -E '443|51820|51821'
```

### Can't connect to X-Ray

1. Verify the server is running: `./vpn.sh status`
2. Check if port 443 is open: `nc -zv YOUR_SERVER 443`
3. Ensure your client has the correct import link: `./vpn.sh link`
4. Check X-Ray logs: `./vpn.sh logs-xray`

### Can't access AmneziaWG Web UI

1. Verify the container is running: `./vpn.sh status`
2. Check if port 51821 is accessible
3. Verify the password from: `./vpn.sh info`
4. Check logs: `./vpn.sh logs-amnezia`

### Reset everything

If something goes wrong, you can start fresh:

```bash
./vpn.sh reset
```

This will remove all configurations and re-run the setup.

---

## How It Works

### X-Ray VLESS + Reality

Reality is an advanced protocol that makes VPN traffic indistinguishable from legitimate HTTPS traffic:

```
┌──────────┐     HTTPS (TLS 1.3)      ┌──────────┐
│  Client  │ ◄──────────────────────► │  Server  │
│          │   Looks like traffic     │          │
│ v2rayNG  │   to www.google.com      │  X-Ray   │
└──────────┘                          └──────────┘
                     │
                     ▼
            DPI can't distinguish
            from real Google traffic
```

- Uses TLS 1.3 with real certificate validation
- Spoofs Chrome browser fingerprint
- SNI points to legitimate domain (google.com)
- No detectable patterns for censorship systems

### AmneziaWG

Amnezia modifies WireGuard packets to defeat DPI:

```
┌──────────┐    Modified WireGuard    ┌──────────┐
│  Client  │ ◄──────────────────────► │  Server  │
│          │   With junk packets &    │          │
│ Amnezia  │   header modifications   │ Amnezia  │
└──────────┘                          └──────────┘
                     │
                     ▼
            DPI can't identify as
            WireGuard protocol
```

- Adds random junk packets
- Modifies packet headers
- Makes traffic pattern unrecognizable
- Maintains WireGuard performance benefits

---

## System Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| OS | Ubuntu 20.04 / Debian 10 | Ubuntu 22.04+ |
| RAM | 512 MB | 1 GB+ |
| Disk | 2 GB | 5 GB+ |
| CPU | 1 vCPU | 2 vCPU |
| Network | 100 Mbps | 1 Gbps |

---

## Uninstallation

To completely remove VPN Host from your server:

```bash
./vpn.sh uninstall
```

This will:
- Stop and remove all containers
- Remove Docker images
- Delete configuration files
- Clean up credentials

---

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

---

## License

This project is provided as-is for personal use. Please ensure you comply with your local laws and regulations when using VPN services.

---

## Disclaimer

This software is provided for legitimate privacy and security purposes. Users are responsible for ensuring their use complies with applicable laws and terms of service. The authors are not responsible for any misuse of this software.
