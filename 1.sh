#!/bin/bash
# Debian Minimal KDE Plasma Kurulumu - Bölüm 1
# IdeaPad 530S-14IKB - İlk Kurulum

set -e  # Hata durumunda scripti durdur

echo "================================================"
echo "Debian 13 Trixie KDE Plasma Kurulumu - Bölüm 1"
echo "================================================"
echo ""

# ============================================
# 1. TEMEL SİSTEM AYARLARI
# ============================================

echo "[1/4] Temel sistem ayarları yapılıyor..."

# Root şifre belirleme
sudo passwd root


# Komut bulunamadı özelliği
sudo apt -y install command-not-found apt-file
sudo apt-file update && sudo update-command-not-found

# Bash özelleştirme
cat << 'EOF' >> ~/.bashrc

# Renkler
RESET="\[\e[0m\]"
NEON_ORANGE="\[\e[38;5;208m\]"
NEON_GREEN="\[\e[38;5;118m\]"
NEON_BLUE="\[\e[38;5;39m\]"
NEON_PINK="\[\e[38;5;205m\]"

# SSH mesajı
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    ssh_message="-ssh_session"
else
    ssh_message=""
fi

# Prompt
PS1="${NEON_ORANGE}\u${RESET}@${NEON_GREEN}\h${RESET}${ssh_message:+${NEON_PINK}${ssh_message}}${RESET}:${NEON_BLUE}\w${RESET}\$ "
EOF

source ~/.bashrc

# 2. ZRAM KURULUMU VE OPTİMİZASYONU
echo "[2/4] ZRAM yapılandırılıyor..."
sudo apt update && sudo apt -y install zram-tools

# Yapılandırma dosyalarını düzenle
echo -e "ALGO=zstd\nPERCENT=60\nPRIORITY=100" | sudo tee /etc/default/zramswap
sudo systemctl restart zramswap

# Sysctl optimizasyonları
cat << 'EOF' | sudo tee /etc/sysctl.d/99-zram-tweaks.conf
vm.swappiness=50
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=10
kernel.sysrq=1
EOF

sudo sysctl --system

# ============================================
# 3. TEMEL SİSTEM ARAÇLARI
# ============================================

echo "[3/4] Temel sistem araçları kuruluyor..."

sudo apt install -y \
    dnsutils iproute2 usbutils dosfstools mtools exfatprogs ntfs-3g \
    p7zip-full unrar zip unzip rsync btop glances dmidecode upower \
    lm-sensors avahi-daemon curl wget git fwupd \
    nfs-common cifs-utils

# ============================================
# 4. KERNEL, FIRMWARE VE SÜRÜCÜLER
# ============================================

echo "[4/4] Kernel, firmware ve sürücüler kuruluyor..."

# Kernel headers ve firmware
sudo apt install -y \
    linux-headers-amd64 firmware-misc-nonfree intel-microcode \
    firmware-intel-graphics firmware-iwlwifi

# Grafik sürücüleri (Intel + NVIDIA Hybrid)
sudo apt install -y \
    intel-media-va-driver-non-free mesa-vulkan-drivers \
    nvidia-driver nvidia-settings intel-gpu-tools \
    vainfo vdpauinfo

# Bluetooth firmware
sudo apt install -y bluez-firmware

# Intel iGPU donanımsal hızlandırma ve güç tasarrufu (GuC/HuC ve FBC)
echo "options i915 enable_guc=3 enable_fbc=1" | sudo tee /etc/modprobe.d/i915.conf

# NVIDIA modeset aktifleştir
echo "options nvidia-drm modeset=1" | sudo tee /etc/modprobe.d/nvidia-options.conf

# Intel WiFi/Bluetooth koeksistans sorunu düzeltmesi
echo "options iwlwifi bt_coex_active=0" | sudo tee /etc/modprobe.d/iwlwifi.conf

# Gereksiz sürücüleri blacklist (AMD + Nouveau)
cat << 'EOF' | sudo tee /etc/modprobe.d/blacklist-gpu.conf
# AMD GPU (donanımda yok)
blacklist amdgpu
blacklist radeon

# Nouveau (NVIDIA proprietary ile çakışır)
blacklist nouveau
EOF

# Global çevresel değişkenler (Donanım hızlandırma ve Wayland için)
cat << 'EOF' | sudo tee -a /etc/environment
LIBVA_DRIVER_NAME=iHD
MOZ_ENABLE_WAYLAND=1
EOF

# Sensör algılama
sudo sensors-detect --auto

# Initramfs güncelleme (tek seferde)
echo "Initramfs güncelleniyor..."
sudo update-initramfs -u

# ============================================
# REBOOT BİLGİLENDİRME
# ============================================

echo ""
echo "================================================"
echo "Bölüm 1 Tamamlandı!"
echo "================================================"
echo ""
echo "Sistem yeniden başlatılacak."
echo "Reboot sonrası ikinci scripti çalıştır:"
echo "  bash install2.sh"
echo ""
echo "10 saniye sonra reboot yapılıyor..."
sleep 10

sudo reboot
