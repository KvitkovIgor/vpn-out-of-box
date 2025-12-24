#!/bin/bash

#===============================================================================
#
#   VPN SETUP SCRIPT - X-Ray + AmneziaWG Easy
#   
#   This script sets up two VPN servers:
#   1. X-Ray (VLESS + Reality) - Port 443
#   2. AmneziaWG Easy - Port 51820 (VPN) + 51821 (Web UI)
#
#   Usage: ./setup-vpn.sh
#
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Config directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

#-------------------------------------------------------------------------------
# Banner
#-------------------------------------------------------------------------------
print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║     ██╗   ██╗██████╗ ███╗   ██╗    ███████╗███████╗████████╗      ║"
    echo "║     ██║   ██║██╔══██╗████╗  ██║    ██╔════╝██╔════╝╚══██╔══╝      ║"
    echo "║     ██║   ██║██████╔╝██╔██╗ ██║    ███████╗█████╗     ██║         ║"
    echo "║     ╚██╗ ██╔╝██╔═══╝ ██║╚██╗██║    ╚════██║██╔══╝     ██║         ║"
    echo "║      ╚████╔╝ ██║     ██║ ╚████║    ███████║███████╗   ██║         ║"
    echo "║       ╚═══╝  ╚═╝     ╚═╝  ╚═══╝    ╚══════╝╚══════╝   ╚═╝         ║"
    echo "║                                                                   ║"
    echo "║           X-Ray (VLESS+Reality) + AmneziaWG Easy                  ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

#-------------------------------------------------------------------------------
# Check if running as root
#-------------------------------------------------------------------------------
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run as root (sudo ./setup-vpn.sh)${NC}"
        exit 1
    fi
}

#-------------------------------------------------------------------------------
# Check OS compatibility
#-------------------------------------------------------------------------------
check_os() {
    echo -e "${YELLOW}[0/9] Checking OS compatibility...${NC}"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        CODENAME=${UBUNTU_CODENAME:-$VERSION_CODENAME}
    else
        echo -e "${YELLOW}Warning: Cannot detect OS. Assuming Debian-based system.${NC}"
        OS="debian"
        CODENAME="bookworm"
    fi
    
    case $OS in
        ubuntu|debian)
            echo -e "${GREEN}✓ Detected: $PRETTY_NAME${NC}"
            ;;
        *)
            echo -e "${YELLOW}Warning: Untested OS ($OS). Proceeding anyway...${NC}"
            ;;
    esac
}

#-------------------------------------------------------------------------------
# Check and install Docker
#-------------------------------------------------------------------------------
check_docker() {
    echo -e "${YELLOW}[1/9] Checking Docker...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${BLUE}  Docker not found. Installing Docker Engine...${NC}"
        
        # Detect OS for correct repository URL
        . /etc/os-release
        OS=$ID
        CODENAME=${UBUNTU_CODENAME:-$VERSION_CODENAME}
        
        # Remove old/conflicting packages
        echo -e "${BLUE}  Removing conflicting packages...${NC}"
        for pkg in docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc; do
            apt remove -y $pkg 2>/dev/null || true
        done
        
        # Install prerequisites
        echo -e "${BLUE}  Installing prerequisites...${NC}"
        apt update
        apt install -y ca-certificates curl gnupg
        
        # Add Docker's official GPG key
        echo -e "${BLUE}  Adding Docker GPG key...${NC}"
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/$OS/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        
        # Add the repository to Apt sources
        echo -e "${BLUE}  Adding Docker repository for $OS ($CODENAME)...${NC}"
        tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/$OS
Suites: $CODENAME
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
        
        # Install Docker packages
        echo -e "${BLUE}  Installing Docker Engine...${NC}"
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # Enable and start Docker
        systemctl enable docker
        systemctl start docker
        
        echo -e "${GREEN}✓ Docker installed successfully${NC}"
    else
        echo -e "${GREEN}✓ Docker already installed${NC}"
    fi
    
    # Verify Docker Compose
    if ! docker compose version &> /dev/null; then
        echo -e "${YELLOW}  Docker Compose not found. Installing...${NC}"
        apt update
        apt install -y docker-compose-plugin
    fi
    
    # Verify Docker is running
    if ! systemctl is-active --quiet docker; then
        echo -e "${YELLOW}  Starting Docker service...${NC}"
        systemctl start docker
    fi
    
    echo -e "${GREEN}✓ Docker is ready${NC}"
}

#-------------------------------------------------------------------------------
# Get server IP (automatic, no prompts)
#-------------------------------------------------------------------------------
get_server_ip() {
    echo -e "${YELLOW}[2/9] Detecting server IP...${NC}"
    
    # Get public IPv4 from ipify API
    SERVER_IP=$(curl -4 -s --max-time 10 https://api.ipify.org 2>/dev/null || \
                curl -4 -s --max-time 10 https://ifconfig.me 2>/dev/null || \
                curl -4 -s --max-time 10 https://icanhazip.com 2>/dev/null || echo "")
    
    if [ -z "$SERVER_IP" ]; then
        echo -e "${RED}Failed to detect public IP. Please check your internet connection.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Server IP: ${SERVER_IP}${NC}"
}

#-------------------------------------------------------------------------------
# Generate Amnezia password (automatic, no prompts)
#-------------------------------------------------------------------------------
get_amnezia_password() {
    echo -e "${YELLOW}[3/9] Generating Amnezia Web UI password...${NC}"
    
    # Generate strong random password (16 chars, alphanumeric + special)
    AMNEZIA_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9@#%&' | head -c 16)
    
    # Fallback if openssl fails
    if [ -z "$AMNEZIA_PASSWORD" ]; then
        AMNEZIA_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 16)
    fi
    
    echo -e "${GREEN}✓ Password generated${NC}"
}

#-------------------------------------------------------------------------------
# Create directories
#-------------------------------------------------------------------------------
create_directories() {
    echo -e "${YELLOW}[4/9] Creating directories...${NC}"
    
    mkdir -p xray
    mkdir -p ~/.amnezia-wg-easy
    
    echo -e "${GREEN}✓ Directories created${NC}"
}

#-------------------------------------------------------------------------------
# Generate X-Ray credentials
#-------------------------------------------------------------------------------
generate_xray_credentials() {
    echo -e "${YELLOW}[5/9] Generating X-Ray credentials...${NC}"
    
    # Generate UUID
    XRAY_UUID=$(cat /proc/sys/kernel/random/uuid)
    echo -e "${BLUE}  UUID: ${XRAY_UUID}${NC}"
    
    # Generate Reality keypair using xray
    echo -e "${BLUE}  Generating Reality keypair...${NC}"
    KEYS=$(docker run --rm ghcr.io/xtls/xray-core:latest x25519 2>/dev/null || true)
    
    if [ -n "$KEYS" ]; then
        REALITY_PRIVATE_KEY=$(echo "$KEYS" | grep "Private key:" | awk '{print $3}')
        REALITY_PUBLIC_KEY=$(echo "$KEYS" | grep "Public key:" | awk '{print $3}')
    fi
    
    # Fallback to openssl if xray method failed
    if [ -z "$REALITY_PRIVATE_KEY" ]; then
        echo -e "${BLUE}  Using OpenSSL fallback...${NC}"
        TEMP_PRIV=$(mktemp)
        openssl genpkey -algorithm X25519 -out "$TEMP_PRIV" 2>/dev/null
        REALITY_PRIVATE_KEY=$(openssl pkey -in "$TEMP_PRIV" -outform DER 2>/dev/null | tail -c 32 | base64 | tr '+/' '-_' | tr -d '=')
        REALITY_PUBLIC_KEY=$(openssl pkey -in "$TEMP_PRIV" -pubout -outform DER 2>/dev/null | tail -c 32 | base64 | tr '+/' '-_' | tr -d '=')
        rm -f "$TEMP_PRIV"
    fi
    
    # Generate short ID
    SHORT_ID=$(openssl rand -hex 8)
    
    # Save credentials
    cat > .vpn_credentials << EOF
# VPN Credentials - Generated $(date)
# Keep this file safe!

SERVER_IP="${SERVER_IP}"

# X-Ray VLESS + Reality
XRAY_UUID="${XRAY_UUID}"
REALITY_PRIVATE_KEY="${REALITY_PRIVATE_KEY}"
REALITY_PUBLIC_KEY="${REALITY_PUBLIC_KEY}"
SHORT_ID="${SHORT_ID}"

# Amnezia WG
AMNEZIA_PASSWORD="${AMNEZIA_PASSWORD}"
EOF
    chmod 600 .vpn_credentials
    
    echo -e "${GREEN}✓ X-Ray credentials generated${NC}"
}

#-------------------------------------------------------------------------------
# Generate Amnezia password hash
#-------------------------------------------------------------------------------
generate_amnezia_hash() {
    echo -e "${YELLOW}[6/9] Generating Amnezia password hash...${NC}"
    
    AMNEZIA_HASH=$(docker run --rm ghcr.io/w0rng/amnezia-wg-easy wgpw "$AMNEZIA_PASSWORD" 2>/dev/null | grep -oP "'\K[^']+" || echo "")
    
    if [ -z "$AMNEZIA_HASH" ]; then
        echo -e "${RED}Failed to generate password hash${NC}"
        exit 1
    fi
    
    AMNEZIA_HASH_ESCAPED=$(echo "$AMNEZIA_HASH" | sed 's/\$/\$\$/g')
    
    echo -e "${GREEN}✓ Password hash generated${NC}"
}

#-------------------------------------------------------------------------------
# Create configuration files
#-------------------------------------------------------------------------------
create_configs() {
    echo -e "${YELLOW}[7/9] Creating configuration files...${NC}"
    
    # X-Ray config
    cat > xray/config.json << EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${XRAY_UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "www.google.com:443",
          "serverNames": ["www.google.com"],
          "privateKey": "${REALITY_PRIVATE_KEY}",
          "shortIds": ["${SHORT_ID}"]
        }
      }
    }
  ],
  "outbounds": [
    {"protocol": "freedom"}
  ]
}
EOF

    # Docker Compose
    cat > docker-compose.yml << EOF
services:
  xray:
    image: ghcr.io/xtls/xray-core:latest
    container_name: xray-proxy
    restart: unless-stopped
    command: run -c /etc/xray/config.json
    ports:
      - "443:443"
    volumes:
      - ./xray/config.json:/etc/xray/config.json:ro

  amnezia-wg-easy:
    image: ghcr.io/w0rng/amnezia-wg-easy
    container_name: amnezia-wg-easy
    restart: unless-stopped
    environment:
      - LANG=en
      - WG_HOST=${SERVER_IP}
      - PASSWORD_HASH=${AMNEZIA_HASH_ESCAPED}
      - PORT=51821
      - WG_PORT=51820
    volumes:
      - ~/.amnezia-wg-easy:/etc/wireguard
    ports:
      - "51820:51820/udp"
      - "51821:51821/tcp"
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv4.ip_forward=1
    devices:
      - /dev/net/tun:/dev/net/tun
EOF

    echo -e "${GREEN}✓ Configuration files created${NC}"
}

#-------------------------------------------------------------------------------
# Start services
#-------------------------------------------------------------------------------
start_services() {
    echo -e "${YELLOW}[8/9] Starting VPN services...${NC}"
    
    docker compose down 2>/dev/null || true
    docker compose up -d
    
    sleep 5
    
    if docker ps | grep -q "xray-proxy" && docker ps | grep -q "amnezia-wg-easy"; then
        echo -e "${GREEN}✓ All services started successfully${NC}"
    else
        echo -e "${RED}Some services failed to start. Check: docker compose logs${NC}"
    fi
}

#-------------------------------------------------------------------------------
# Print connection info
#-------------------------------------------------------------------------------
print_info() {
    echo -e "${YELLOW}[9/9] Setup complete! Generating connection info...${NC}"
    
    source .vpn_credentials
    
    XRAY_LINK="vless://${XRAY_UUID}@${SERVER_IP}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.google.com&fp=chrome&pbk=${REALITY_PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp#XRay-${SERVER_IP}"
    
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                     SETUP COMPLETE!                               ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    X-RAY (VLESS + Reality)                        ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${YELLOW}Address:${NC}     ${SERVER_IP}"
    echo -e "  ${YELLOW}Port:${NC}        443"
    echo -e "  ${YELLOW}UUID:${NC}        ${XRAY_UUID}"
    echo -e "  ${YELLOW}Flow:${NC}        xtls-rprx-vision"
    echo -e "  ${YELLOW}Public Key:${NC}  ${REALITY_PUBLIC_KEY}"
    echo -e "  ${YELLOW}Short ID:${NC}    ${SHORT_ID}"
    echo -e "  ${YELLOW}SNI:${NC}         www.google.com"
    echo -e "  ${YELLOW}Fingerprint:${NC} chrome"
    echo ""
    echo -e "  ${YELLOW}Import Link (copy all):${NC}"
    echo -e "  ${BLUE}${XRAY_LINK}${NC}"
    echo ""
    echo -e "  ${YELLOW}Apps:${NC} v2rayN (Win), v2rayNG (Android), Shadowrocket (iOS)"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                      AMNEZIA WG EASY                              ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${YELLOW}Web UI:${NC}      http://${SERVER_IP}:51821"
    echo -e "  ${YELLOW}Password:${NC}    ${AMNEZIA_PASSWORD}"
    echo -e "  ${YELLOW}VPN Port:${NC}    51820/UDP"
    echo ""
    echo -e "  ${YELLOW}App:${NC} AmneziaVPN (iOS/Android/Win/Mac)"
    echo -e "  ${YELLOW}How to connect:${NC}"
    echo -e "    1. Open http://${SERVER_IP}:51821"
    echo -e "    2. Create a new client"
    echo -e "    3. Scan QR or download config"
    echo -e "    4. Import to AmneziaVPN app"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                       USEFUL COMMANDS                             ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${YELLOW}Status:${NC}      docker compose ps"
    echo -e "  ${YELLOW}Logs:${NC}        docker compose logs -f"
    echo -e "  ${YELLOW}Restart:${NC}     docker compose restart"
    echo -e "  ${YELLOW}Stop:${NC}        docker compose down"
    echo -e "  ${YELLOW}Credentials:${NC} cat .vpn_credentials"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Save connection info to file
    cat > CONNECTION_INFO.txt << EOF
VPN CONNECTION INFO
Generated: $(date)
Server: ${SERVER_IP}

================================================================================
X-RAY (VLESS + Reality) - Port 443
================================================================================
Address:     ${SERVER_IP}
Port:        443
UUID:        ${XRAY_UUID}
Flow:        xtls-rprx-vision
Public Key:  ${REALITY_PUBLIC_KEY}
Short ID:    ${SHORT_ID}
SNI:         www.google.com
Fingerprint: chrome

Import Link:
${XRAY_LINK}

Apps: v2rayN (Win), v2rayNG (Android), Shadowrocket (iOS)

================================================================================
AMNEZIA WG EASY - Port 51820
================================================================================
Web UI:      http://${SERVER_IP}:51821
Password:    ${AMNEZIA_PASSWORD}

App: AmneziaVPN (iOS/Android/Win/Mac)

================================================================================
EOF
    
    echo -e "${GREEN}Connection info saved to: CONNECTION_INFO.txt${NC}"
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    print_banner
    check_root
    check_os
    check_docker
    get_server_ip
    get_amnezia_password
    create_directories
    generate_xray_credentials
    generate_amnezia_hash
    create_configs
    start_services
    print_info
}

main "$@"