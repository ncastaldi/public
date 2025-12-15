#!/bin/bash

# 1. Define the Download URL (Linux x64)
URL="https://code.visualstudio.com/sha/download?build=stable&os=cli-linux-x64"

echo "--- 1. Downloading VS Code CLI ---"
# -L follows redirects, -k is useful if certs are missing on old VMs
curl -Lk "$URL" --output vscode_cli.tar.gz

echo "--- 2. Extracting and Installing ---"
tar -xf vscode_cli.tar.gz
# Move to /usr/local/bin so it can be run from anywhere
sudo mv code /usr/local/bin/
rm vscode_cli.tar.gz

echo "--- 3. Enabling Systemd Linger ---"
# This ensures the service starts on boot even if you aren't logged in
sudo loginctl enable-linger $USER

echo "--- Installation Complete! ---"
echo ""
echo "To finish the setup, you must authenticate once manually:"
echo "1. Run this command:    code tunnel"
echo "2. Follow the login instructions (GitHub/Microsoft)."
echo "3. Once connected, press Ctrl+C to stop it."
echo "4. Finally, install the permanent service by running:"
echo "   ./code tunnel service install"