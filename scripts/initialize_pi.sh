#!/bin/bash
# Frank Meadows - Ultimate Pi Bootstrap v1.4
# Includes: Docker, Monitoring Agents, VS Code Tunnel, and Ansible

set -e
set -o pipefail

echo "🚀 Starting Raspberry Pi SRE Bootstrap..."

# --- 1. SYSTEM REFRESH & ESSENTIALS ---
echo "🔄 Updating system and installing dependencies..."
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y vim git curl htop build-essential ca-certificates python3-pip python3-venv

# --- 2. ANSIBLE INSTALLATION ---
# Installing via apt for stability on Debian-based systems
if ! [ -x "$(command -v ansible)" ]; then
    echo "📜 Installing Ansible..."
    sudo apt install -y ansible
else
    echo "📜 Ansible already installed."
fi

# --- 3. DOCKER ENGINE SETUP ---
if ! [ -x "$(command -v docker)" ]; then
    echo "🐳 Installing Docker Engine..."
    curl -sSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
    sudo apt install -y docker-compose-plugin
fi

# --- 4. VS CODE TUNNEL SETUP (Hardened) ---
ARCH=$(uname -m)
case $ARCH in
    x86_64)  PLAT="cli-linux-x64" ;;
    aarch64) PLAT="cli-linux-arm64" ;;
    *)       echo "❌ Unsupported arch: $ARCH"; exit 1 ;;
esac

echo "💻 Installing VS Code CLI ($ARCH)..."
# Using the specific 'update.code' redirect which is more reliable for curl
URL="https://update.code.visualstudio.com/latest/$PLAT/stable"

curl -Lk "$URL" --output vscode_cli.tar.gz

# SRE Check: Verify file size is > 1MB
FILESIZE=$(stat -c%s "vscode_cli.tar.gz")
if [ "$FILESIZE" -lt 1000000 ]; then
    echo "❌ Error: VS Code download failed or returned invalid file (Size: $FILESIZE bytes)."
    exit 1
fi

tar -xf vscode_cli.tar.gz
sudo mv code /usr/local/bin/
rm vscode_cli.tar.gz

sudo loginctl enable-linger $USER
code tunnel service install --accept-server-license-terms --name "$(hostname)" --provider github
# --- 5. MONITORING STACK (Gatus/Beszel/Dozzle) ---
STACK_DIR="/opt/stacks/monitoring"
sudo mkdir -p "$STACK_DIR/gatus-config"
sudo chown -R "$USER:$USER" /opt/stacks

cat <<EOF > "$STACK_DIR/gatus-config/config.yaml"
endpoints:
  - name: TerraMaster
    url: http://10.0.0.250
    interval: 30s
    conditions: [" [STATUS] == 200 "]
  - name: Synology
    url: http://10.0.0.249
    interval: 30s
    conditions: [" [STATUS] == 200 "]
EOF

cat <<EOF > "$STACK_DIR/docker-compose.yml"
services:
  gatus:
    image: twinproduction/gatus:latest
    container_name: gatus
    restart: unless-stopped
    ports: ["8080:8080"]
    volumes: ["./gatus-config:/config"]
  beszel-agent:
    image: henrygd/beszel-agent:latest
    container_name: beszel-agent
    network_mode: host
    restart: unless-stopped
    volumes: ["/var/run/docker.sock:/var/run/docker.sock:ro"]
    environment: ["PORT=45876"]
  dozzle-agent:
    image: amir20/dozzle:latest
    container_name: dozzle-agent
    command: agent
    ports: ["7007:7007"]
    restart: unless-stopped
    volumes: ["/var/run/docker.sock:/var/run/docker.sock:ro"]
EOF

docker compose -f "$STACK_DIR/docker-compose.yml" up -d

echo "------------------------------------------------"
echo "✅ BOOTSTRAP COMPLETE"
echo "------------------------------------------------"
echo "1. Authenticate VS Code: 'code tunnel user login'"
echo "2. Dashboard: http://$(hostname -I | awk '{print $1}'):8080"
echo "3. Ansible: Ready for local playbooks."