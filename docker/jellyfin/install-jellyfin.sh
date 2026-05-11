#!/usr/bin/env bash

set -e

# =========================
# Configuration
# =========================

JELLYFIN_CONFIG_DIR="/opt/jellyfin/config"
JELLYFIN_CACHE_DIR="/opt/jellyfin/cache"
MEDIA_DIR="/mnt/media"

JELLYFIN_HTTP_PORT="8096"
JELLYFIN_HTTPS_PORT="8920"

TZ="America/New_York"

# =========================
# Helpers
# =========================

log() {
    echo
    echo "=================================================="
    echo "$1"
    echo "=================================================="
}

# =========================
# Update System
# =========================

log "Updating Ubuntu packages"

apt update
apt upgrade -y

# =========================
# Install Required Packages
# =========================

log "Installing prerequisites"

apt install -y \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    ufw \
    cifs-utils

# =========================
# Install Docker
# =========================

if ! command -v docker &> /dev/null
then
    log "Installing Docker"

    install -m 0755 -d /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) \
      signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt update

    apt install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    systemctl enable docker
    systemctl start docker
fi

# =========================
# Create Directories
# =========================

log "Creating Jellyfin directories"

mkdir -p "$JELLYFIN_CONFIG_DIR"
mkdir -p "$JELLYFIN_CACHE_DIR"
mkdir -p "$MEDIA_DIR"

# =========================
# Create Docker Compose File
# =========================

log "Creating docker-compose.yml"

mkdir -p /opt/jellyfin

cat > /opt/jellyfin/docker-compose.yml <<EOF
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin

    network_mode: host

    environment:
      - TZ=${TZ}

    volumes:
      - ${JELLYFIN_CONFIG_DIR}:/config
      - ${JELLYFIN_CACHE_DIR}:/cache
      - ${MEDIA_DIR}:/media

    restart: unless-stopped

    devices:
      - /dev/dri:/dev/dri
EOF

# =========================
# Start Jellyfin
# =========================

log "Starting Jellyfin"

cd /opt/jellyfin

docker compose up -d

# =========================
# Configure Firewall
# =========================

if command -v ufw &> /dev/null
then
    log "Opening firewall ports"

    ufw allow ${JELLYFIN_HTTP_PORT}/tcp || true
    ufw allow ${JELLYFIN_HTTPS_PORT}/tcp || true
fi

# =========================
# Done
# =========================

IP_ADDRESS=$(hostname -I | awk '{print $1}')

log "Jellyfin installation complete"

echo "Open your browser to:"
echo
echo "    http://${IP_ADDRESS}:${JELLYFIN_HTTP_PORT}"
echo
echo "Media directory:"
echo "    ${MEDIA_DIR}"
echo
echo "Docker compose file:"
echo "    /opt/jellyfin/docker-compose.yml"
echo
echo "To update Jellyfin later:"
echo
echo "    cd /opt/jellyfin"
echo "    docker compose pull"
echo "    docker compose up -d"
echo
