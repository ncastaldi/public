#!/bin/bash
set -e

echo "--- 1. Downloading VS Code CLI ---"
# Fixed: Added -L to follow redirects and output to a specific filename
curl -Lk 'https://code.visualstudio.com/sha/download?build=stable&os=cli-linux-x64' -o vscode_cli.tar.gz

echo "--- 2. Extracting and Installing ---"
# Extract the archive
tar -xf vscode_cli.tar.gz
rm vscode_cli.tar.gz

# Move binary to global path (requires sudo)
echo "Installing 'code' binary to /usr/local/bin..."
sudo mv code /usr/local/bin/

echo "--- 3. Enabling Systemd Linger ---"
# Ensures the service keeps running when you disconnect
sudo loginctl enable-linger $USER

echo "--- Installation Complete! ---"
echo "Initializing the Tunnel..."
echo "1. Copy the 8-digit code shown below."
echo "2. Go to https://github.com/login/device in your browser."
echo "3. After you authenticate, press Ctrl+C to stop this, then run:"
echo "   code tunnel service install"
echo "-----------------------------------------------------"

# Automatically run the initial command to start the auth flow
code tunnel
