#!/bin/bash
# Frank Meadows - VS Code Tunnel SRE Bootstrap
# Purpose: Automated installation and service setup for VS Code CLI

set -e

# 1. Environment Detection
ARCH=$(uname -m)
case $ARCH in
    x86_64)  PLATFORM="cli-linux-x64" ;;
    aarch64) PLATFORM="cli-linux-arm64" ;;
    *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

TUNNEL_NAME=$(hostname)
URL="https://code.visualstudio.com/sha/download?build=stable&os=$PLATFORM"

echo "--- 1. Downloading VS Code CLI ($ARCH) ---"
curl -L "$URL" --output vscode_cli.tar.gz

echo "--- 2. Installing to /usr/local/bin ---"
tar -xf vscode_cli.tar.gz
sudo mv code /usr/local/bin/
rm vscode_cli.tar.gz

echo "--- 3. Enabling Systemd User Linger ---"
sudo loginctl enable-linger $USER

echo "--- 4. Initializing Tunnel Service ---"
# This registers the service but requires a one-time auth
# We use --accept-server-license-terms to ensure it doesn't hang
code tunnel service install \
    --accept-server-license-terms \
    --name "$TUNNEL_NAME" \
    --provider github

echo ""
echo "------------------------------------------------"
echo "✅ INSTALLATION COMPLETE"
echo "------------------------------------------------"
echo "CRITICAL: You must authenticate once to link GitHub."
echo "Run the following command and follow the link:"
echo ""
echo "    code tunnel user login"
echo ""
echo "After login, the service will manage itself on boot."
echo "Tunnel URL: https://vscode.dev/tunnel/$TUNNEL_NAME"