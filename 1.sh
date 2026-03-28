#!/bin/bash
# Debian Minimal KDE Plasma Installation - Part 1
# IdeaPad 530S-14IKB - Initial Setup

set -e  # Exit on error

echo "================================================"
echo "Debian 13 Trixie KDE Plasma Installation - Part 1"
echo "================================================"
echo ""

# ============================================
# 1. BASIC SYSTEM SETTINGS
# ============================================

echo "[1/4] Configuring basic system settings..."

# Set root password
sudo passwd root

# Command not found feature
sudo apt -y install command-not-found apt-file
sudo apt-file update && sudo update-command-not-found

# Bash customization
cat << 'EOF' >> ~/.bashrc

# Colors
RESET="\[\e[0m\]"
NEON_ORANGE="\[\e[38;5;208m\]"
NEON_GREEN="\[\e[38;5;118m\]"
NEON_BLUE="\[\e[38;5;39m\]"
NEON_PINK="\[\e[38;5;205m\]"

# SSH message
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    ssh_message="-ssh_session"
else
    ssh_message=""
fi

# Prompt
PS1="${NEON_ORANGE}\u${RESET}@${NEON_GREEN}\h${RESET}${ssh_message:+${NEON_PINK}${ssh_message}}${RESET}:${NEON_BLUE}\w${RESET}\$ "
EOF

source ~/.bashrc

# 2. ZRAM INSTALLATION AND OPTIMIZATION
echo "[2/4] Configuring ZRAM..."
sudo apt update && sudo apt -y install zram-tools

# Edit configuration files
echo -e "ALGO=zstd\nPERCENT=60\nPRIORITY=100" | sudo tee /etc/default/zramswap
sudo systemctl restart zramswap

# Sysctl optimizations
cat << 'EOF' | sudo tee /etc/sysctl.d/99-zram-tweaks.conf
vm.swappiness=50
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=10
kernel.sysrq=1
EOF

sudo sysctl --system

# ============================================
# 3. BASE SYSTEM TOOLS
# ============================================

echo "[3/4] Installing base system tools..."

sudo apt install -y \
    dnsutils iproute2 usbutils dosfstools mtools exfatprogs ntfs-3g \
    p7zip-full unrar zip unzip rsync btop glances dmidecode upower \
    lm-sensors avahi-daemon curl wget git fwupd \
    nfs-common cifs-utils

# ============================================
# 4. KERNEL, FIRMWARE AND DRIVERS
# ============================================

echo "[4/4] Installing kernel, firmware, and drivers..."

# Kernel headers and firmware
sudo apt install -y \
    linux-headers-amd64 firmware-misc-nonfree intel-microcode \
    firmware-intel-graphics firmware-iwlwifi

# Graphics drivers (Intel + NVIDIA Hybrid)
sudo apt install -y \
    intel-media-va-driver-non-free mesa-vulkan-drivers \
    nvidia-driver nvidia-settings intel-gpu-tools \
    vainfo vdpauinfo

# Bluetooth firmware
sudo apt install -y bluez-firmware

# Intel iGPU hardware acceleration and power saving (GuC/HuC and FBC)
echo "options i915 enable_guc=3 enable_fbc=1" | sudo tee /etc/modprobe.d/i915.conf

# Enable NVIDIA modeset
echo "options nvidia-drm modeset=1" | sudo tee /etc/modprobe.d/nvidia-options.conf

# Intel WiFi/Bluetooth coexistence fix
echo "options iwlwifi bt_coex_active=0" | sudo tee /etc/modprobe.d/iwlwifi.conf

# Blacklist unnecessary drivers (AMD + Nouveau)
cat << 'EOF' | sudo tee /etc/modprobe.d/blacklist-gpu.conf
# AMD GPU (Not present in hardware)
blacklist amdgpu
blacklist radeon

# Nouveau (Conflicts with NVIDIA proprietary)
blacklist nouveau
EOF

# Global environment variables (For Hardware Acceleration and Wayland)
cat << 'EOF' | sudo tee -a /etc/environment
LIBVA_DRIVER_NAME=iHD
MOZ_ENABLE_WAYLAND=1
EOF

# Sensor detection
sudo sensors-detect --auto

# Update Initramfs (Single run)
echo "Updating Initramfs..."
sudo update-initramfs -u

# ============================================
# REBOOT INFORMATION
# ============================================

echo ""
echo "================================================"
echo "Part 1 Completed!"
echo "================================================"
echo ""
echo "The system will reboot."
echo "After reboot, run the second script:"
echo "  bash install2.sh"
echo ""
echo "Rebooting in 10 seconds..."
sleep 10

sudo reboot
