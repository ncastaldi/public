#!/bin/bash

# ================= CONFIGURATION =================
# The user the service runs as (keep as root or change to 'chester')
SERVICE_USER="chester"

# The directory VS Code will open by default
WORK_DIR="/home/chester"

# The installation path
INSTALL_PATH="/usr/bin/code"
# =================================================

echo ">>> 1. Cleaning up old files..."
rm -f vscode_cli.tar.gz
# Stop service if it's already running
sudo systemctl stop code-tunnel 2>/dev/null

echo ">>> 2. Downloading VS Code CLI (Alpine/Static Build)..."
# We use the Alpine build because it is statically linked and works on all Linux distros
curl -Lk 'https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64' -o vscode_cli.tar.gz

# Check if download succeeded (size check)
FILE_SIZE=$(stat -c%s "vscode_cli.tar.gz")
if [ "$FILE_SIZE" -lt 1000000 ]; then
    echo "Error: Download failed (File is too small). Check your internet connection."
    exit 1
fi

echo ">>> 3. Extracting and Installing..."
tar -xf vscode_cli.tar.gz
chmod +x code
sudo mv code "$INSTALL_PATH"

echo ">>> 4. Creating Systemd Service File..."
sudo tee /etc/systemd/system/code-tunnel.service > /dev/null <<EOF
[Unit]
Description=Visual Studio Code Tunnel
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$WORK_DIR
Restart=always
RestartSec=10
ExecStart=$INSTALL_PATH tunnel --accept-server-license-terms
Environment=VSCODE_CLI_DISABLE_KEYCHAIN_ENCRYPT=1

[Install]
WantedBy=multi-user.target
EOF

echo ">>> 5. Reloading Systemd..."
sudo systemctl daemon-reload
sudo systemctl enable code-tunnel

echo ""
echo "========================================================"
echo "   INSTALLATION SUCCESSFUL"
echo "========================================================"
echo "The service is installed, BUT you must authenticate first."
echo ""
echo "STEP 1: Run the tunnel manually to log in:"
echo "   sudo $INSTALL_PATH tunnel"
echo ""
echo "STEP 2: Go to https://github.com/login/device and enter the code shown."
echo "STEP 3: After success, press CTRL+C to stop the manual tunnel."
echo "STEP 4: Start the background service:"
echo "   sudo systemctl start code-tunnel"
echo "========================================================"
