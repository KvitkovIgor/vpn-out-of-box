#!/bin/bash

#===============================================================================
#   VPN Management Script
#===============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Parse flags
FORCE=false
for arg in "$@"; do
    case $arg in
        -y|--yes|--force)
            FORCE=true
            shift
            ;;
    esac
done

show_help() {
    echo -e "${CYAN}VPN Management Script${NC}"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  start       Start all VPN services"
    echo "  stop        Stop all VPN services"
    echo "  restart     Restart all VPN services"
    echo "  status      Show service status"
    echo "  logs        Show all logs (follow mode)"
    echo "  logs-xray   Show X-Ray logs"
    echo "  logs-amnezia Show Amnezia logs"
    echo "  info        Show connection information"
    echo "  link        Show X-Ray import link"
    echo "  reset       Reset everything and reconfigure"
    echo "  uninstall   Remove all containers and configs"
    echo "  help        Show this help"
    echo ""
    echo "Options:"
    echo "  -y, --yes   Skip confirmation prompts (for reset/uninstall)"
}

cmd_start() {
    echo -e "${YELLOW}Starting VPN services...${NC}"
    docker compose up -d
    sleep 3
    docker compose ps
    echo -e "${GREEN}✓ Services started${NC}"
}

cmd_stop() {
    echo -e "${YELLOW}Stopping VPN services...${NC}"
    docker compose down
    echo -e "${GREEN}✓ Services stopped${NC}"
}

cmd_restart() {
    echo -e "${YELLOW}Restarting VPN services...${NC}"
    docker compose restart
    sleep 3
    docker compose ps
    echo -e "${GREEN}✓ Services restarted${NC}"
}

cmd_status() {
    echo -e "${CYAN}Service Status:${NC}"
    docker compose ps
    echo ""
    echo -e "${CYAN}Container Health:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "xray|amnezia|NAME"
}

cmd_logs() {
    docker compose logs -f
}

cmd_logs_xray() {
    docker logs -f xray-proxy
}

cmd_logs_amnezia() {
    docker logs -f amnezia-wg-easy
}

cmd_info() {
    if [ ! -f ".vpn_credentials" ]; then
        echo -e "${RED}Credentials not found. Run setup-vpn.sh first.${NC}"
        exit 1
    fi
    
    source .vpn_credentials
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    X-RAY (VLESS + Reality)                        ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${YELLOW}Address:${NC}     ${SERVER_IP}"
    echo -e "  ${YELLOW}Port:${NC}        443"
    echo -e "  ${YELLOW}UUID:${NC}        ${XRAY_UUID}"
    echo -e "  ${YELLOW}Public Key:${NC}  ${REALITY_PUBLIC_KEY}"
    echo -e "  ${YELLOW}Short ID:${NC}    ${SHORT_ID}"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                      AMNEZIA WG EASY                              ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${YELLOW}Web UI:${NC}      http://${SERVER_IP}:51821"
    echo -e "  ${YELLOW}Password:${NC}    ${AMNEZIA_PASSWORD}"
    echo ""
}

cmd_link() {
    if [ ! -f ".vpn_credentials" ]; then
        echo -e "${RED}Credentials not found. Run setup-vpn.sh first.${NC}"
        exit 1
    fi
    
    source .vpn_credentials
    
    XRAY_LINK="vless://${XRAY_UUID}@${SERVER_IP}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.google.com&fp=chrome&pbk=${REALITY_PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp#XRay-${SERVER_IP}"
    
    echo ""
    echo -e "${YELLOW}X-Ray Import Link:${NC}"
    echo ""
    echo "$XRAY_LINK"
    echo ""
}

cmd_reset() {
    if [ "$FORCE" = "true" ]; then
        docker compose down 2>/dev/null || true
        rm -f .vpn_credentials docker-compose.yml CONNECTION_INFO.txt
        rm -rf xray ~/.amnezia-wg-easy
        echo -e "${GREEN}✓ Reset complete. Run ./setup-vpn.sh to reconfigure.${NC}"
    else
        echo -e "${YELLOW}This will delete all configs and credentials.${NC}"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            docker compose down 2>/dev/null || true
            rm -f .vpn_credentials docker-compose.yml CONNECTION_INFO.txt
            rm -rf xray ~/.amnezia-wg-easy
            echo -e "${GREEN}✓ Reset complete. Run ./setup-vpn.sh to reconfigure.${NC}"
        else
            echo "Cancelled."
        fi
    fi
}

cmd_uninstall() {
    if [ "$FORCE" = "true" ]; then
        docker compose down 2>/dev/null || true
        docker rmi ghcr.io/xtls/xray-core:latest 2>/dev/null || true
        docker rmi ghcr.io/w0rng/amnezia-wg-easy 2>/dev/null || true
        rm -f .vpn_credentials docker-compose.yml CONNECTION_INFO.txt
        rm -rf xray ~/.amnezia-wg-easy
        echo -e "${GREEN}✓ Uninstall complete.${NC}"
    else
        echo -e "${RED}This will remove all VPN containers, images, and configs.${NC}"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            docker compose down 2>/dev/null || true
            docker rmi ghcr.io/xtls/xray-core:latest 2>/dev/null || true
            docker rmi ghcr.io/w0rng/amnezia-wg-easy 2>/dev/null || true
            rm -f .vpn_credentials docker-compose.yml CONNECTION_INFO.txt
            rm -rf xray ~/.amnezia-wg-easy
            echo -e "${GREEN}✓ Uninstall complete.${NC}"
        else
            echo "Cancelled."
        fi
    fi
}

# Main
case "${1:-help}" in
    start)       cmd_start ;;
    stop)        cmd_stop ;;
    restart)     cmd_restart ;;
    status)      cmd_status ;;
    logs)        cmd_logs ;;
    logs-xray)   cmd_logs_xray ;;
    logs-amnezia) cmd_logs_amnezia ;;
    info)        cmd_info ;;
    link)        cmd_link ;;
    reset)       cmd_reset ;;
    uninstall)   cmd_uninstall ;;
    help|*)      show_help ;;
esac