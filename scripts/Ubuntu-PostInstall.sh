#!/bin/bash
set -e

# --- Configuration Variables ---
NFS_HOST="10.0.0.250"
NFS_REMOTE_PATH="/Volume1/appdata"
LOCAL_MOUNT_POINT="/mnt/thelab"

echo "Starting Post-Install Script..."

# --- 1. NVIDIA & Docker Setup ---
echo "Setting up NVIDIA Container Toolkit..."
# Add the package repositories (standard NVIDIA setup)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

echo "Configuring Docker runtime for NVIDIA..."
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# --- 2. NFS Mount Setup ---
echo "Configuring NFS Mount..."

# Create mount point if it doesn't exist
if [ ! -d "$LOCAL_MOUNT_POINT" ]; then
    sudo mkdir -p "$LOCAL_MOUNT_POINT"
    echo "Created mount point at $LOCAL_MOUNT_POINT"
fi

# Check if fstab already has the entry to prevent duplicates
if grep -q "$LOCAL_MOUNT_POINT" /etc/fstab; then
    echo "Entry already exists in /etc/fstab. Removing old entry..."
    # Backup fstab just in case
    sudo cp /etc/fstab /etc/fstab.bak
    # Remove lines containing the mount point
    sudo sed -i "\|$LOCAL_MOUNT_POINT|d" /etc/fstab
fi

# Add the new, correct line
echo "Adding NFS share to /etc/fstab..."
echo "$NFS_HOST:$NFS_REMOTE_PATH $LOCAL_MOUNT_POINT nfs defaults 0 0" | sudo tee -a /etc/fstab

# Reload and mount
sudo systemctl daemon-reload
sudo mount "$LOCAL_MOUNT_POINT"

echo "Success! NFS share mounted."
echo "Note: A system reboot is recommended to ensure all NVIDIA drivers are loaded."
