#!/bin/bash
# Frank Meadows - Pi Bootstrap Script v1.0
# Usage: sudo bash pi-bootstrap.sh

set -e # Exit on error

echo "🚀 Starting Raspberry Pi Bootstrap..."

# 1. System Self-Update
echo "🔄 Updating system packages..."
apt update && apt full-upgrade -y

# 2. Install Essentials
echo "🛠️ Installing essential tools..."
apt install -y vim git curl htop build-essential ca-certificates python3-pip

# 3. Docker Installation (Official Script)
if ! [ -x "$(command -v docker)" ]; then
    echo "🐳 Installing Docker..."
    curl -sSL https://get.docker.com | sh
    usermod -aG docker $USER
    echo "✅ Docker installed. User added to docker group."
else
    echo "🐳 Docker already installed, skipping..."
fi

# 4. Docker Compose Setup (Plugin)
echo "📦 Ensuring Docker Compose is ready..."
apt install -y docker-compose-plugin

# 5. Application Stack Initialization
# We'll create a default directory for your services
STACK_DIR="/opt/stacks/initial-apps"
mkdir -p "$STACK_DIR"

cat <<EOF > "$STACK_DIR/docker-compose.yml"
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    command: -H unix:///var/run/docker.sock
    restart: always
    ports:
      - 9443:9443
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_POLL_INTERVAL=86400 # Check daily

volumes:
  portainer_data:
EOF

echo "🚢 Spinning up initial container stack (Portainer + Watchtower)..."
docker compose -f "$STACK_DIR/docker-compose.yml" up -d

# 6. Cleanup & Finalize
echo "🧹 Cleaning up..."
apt autoremove -y

echo "------------------------------------------------"
echo "✅ BOOTSTRAP COMPLETE"
echo "Next steps: "
echo "1. Reboot the Pi: 'sudo reboot'"
echo "2. Access Portainer at https://<PI-IP>:9443"
echo "------------------------------------------------"