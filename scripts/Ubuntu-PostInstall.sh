#!/bin/bash

# ------------------------------------------------------------------
# Ubuntu Post-Install Setup Script
# ------------------------------------------------------------------

# Stop execution if a command fails
set -e

echo "Starting setup process..."

# 1. Update and Upgrade
echo "Updating package lists and upgrading existing packages..."
sudo apt update && sudo apt upgrade -y

# 2. Install Essential CLI Tools
echo "Installing quality-of-life CLI tools..."
# git/curl/wget: basics
# htop/btop: process monitoring
# ncdu: disk usage analyzer
# tree: directory visualization
# ripgrep: fast search
# bat: syntax highlighting cat
sudo apt install -y git curl wget htop btop ncdu tree ripgrep bat

# Fix for 'bat' command (Ubuntu installs it as 'batcat')
if command -v batcat &> /dev/null && ! command -v bat &> /dev/null; then
    echo "Aliasing 'batcat' to 'bat'..."
    sudo ln -s /usr/bin/batcat /usr/local/bin/bat
fi

# 3. Install Cockpit (Web Console)
echo "Installing Cockpit and plugins..."
. /etc/os-release
sudo apt install -t ${VERSION_CODENAME}-backports cockpit -y
sudo apt install -y cockpit-machines cockpit-storaged cockpit-networkmanager cockpit-packagekit

# 4. Install Docker
echo "Installing Docker via get.docker.com..."
if ! command -v docker &> /dev/null; then
    curl -fsSL get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
else
    echo "Docker is already installed."
fi

# 5. Docker Non-Root Setup
echo "Configuring Docker for non-root user..."
TARGET_USER="${SUDO_USER:-$USER}"
sudo usermod -aG docker "$TARGET_USER"

# 6. Mount NFS Share
echo "Setting up NFS mount..."
sudo apt install -y nfs-common

# Create the local mount point
sudo mkdir -p /mnt/thelab

# Define Variables
NFS_HOST="Volume1"
NFS_REMOTE_PATH="/appdata/.thelab"
LOCAL_MOUNT_POINT="/mnt/thelab"

# Add to /etc/fstab for persistence
if ! grep -qs "$LOCAL_MOUNT_POINT" /etc/fstab; then
    echo "Adding NFS share to /etc/fstab for persistent boot..."
    echo "$NFS_HOST:$NFS_REMOTE_PATH $LOCAL_MOUNT_POINT nfs defaults 0 0" | sudo tee -a /etc/fstab
else
    echo "Entry for $LOCAL_MOUNT_POINT already exists in /etc/fstab."
fi

sudo mount -a
echo "NFS share mounted at $LOCAL_MOUNT_POINT"

# 7. Install NVIDIA Drivers
echo "Checking for NVIDIA hardware..."
sudo apt install -y pciutils ubuntu-drivers-common

if lspci | grep -i nvidia > /dev/null; then
    echo "NVIDIA hardware detected. Installing recommended drivers..."
    sudo ubuntu-drivers autoinstall
    
    # Install NVIDIA Container Toolkit
    echo "Installing NVIDIA Container Toolkit..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
    && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
      sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit

    echo "Configuring Docker runtime for NVIDIA..."
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
else
    echo "No NVIDIA hardware detected. Skipping driver and toolkit installation."
fi

# 8. Install VS Code CLI (Tunnel)
echo "Setting up VS Code CLI..."
VSCODE_URL="https://code.visualstudio.com/sha/download?build=stable&os=cli-linux-x64"

curl -Lk "$VSCODE_URL" --output vscode_cli.tar.gz
tar -xf vscode_cli.tar.gz
rm vscode_cli.tar.gz

echo "Moving 'code' binary to /usr/local/bin..."
sudo mv code /usr/local/bin/

echo "Enabling systemd linger for user: $TARGET_USER"
sudo loginctl enable-linger "$TARGET_USER"

# 9. Configure Automatic Security Updates
echo "Configuring Unattended Upgrades..."
sudo apt install -y unattended-upgrades
# Enable automatic updates in apt configuration
echo 'APT::Periodic::Update-Package-Lists "1";' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Unattended-Upgrade "1";' | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades
echo "Security updates set to install automatically."

# ------------------------------------------------------------------
# End of Script
echo "------------------------------------------------------------------"
echo "Script finished successfully!"
echo "------------------------------------------------------------------"
echo "IMPORTANT POST-INSTALL STEPS:"
echo "1. Reboot your system (Required for NVIDIA drivers)."
echo "2. Log back in as $TARGET_USER."
echo "3. Run 'code tunnel' to authenticate VS Code."
echo "4. Follow the login instructions, press Ctrl+C, then run:"
echo "   code tunnel service install"
echo "------------------------------------------------------------------"
