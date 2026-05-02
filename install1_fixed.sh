#!/usr/bin/env bash
# Debian 13 Trixie Minimal KDE Plasma Kurulumu - Bölüm 1
# IdeaPad 530S-14IKB - İlk Kurulum
# Hedef: kişisel laptop/masaüstü + KDE + NVIDIA + Intel VA-API + medya odaklı kullanım

set -Eeuo pipefail

ADMIN_USER="${ADMIN_USER:-can}"
ADMIN_HOME="$(getent passwd "$ADMIN_USER" | cut -d: -f6 || true)"

trap 'rc=$?; echo "HATA: satır=${LINENO} komut=${BASH_COMMAND} çıkış=${rc}" >&2; exit "$rc"' ERR

sudo -v

if [[ -z "$ADMIN_HOME" ]]; then
    echo "HATA: $ADMIN_USER kullanıcısı bulunamadı. ADMIN_USER=... ile çalıştır." >&2
    exit 1
fi

apt_update() {
    sudo apt-get update -o Acquire::Retries=3
}

apt_install() {
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

write_root_file() {
    local path="$1"
    local mode="${2:-0644}"
    local tmp
    tmp="$(mktemp)"
    cat > "$tmp"
    sudo install -m "$mode" "$tmp" "$path"
    rm -f "$tmp"
}

append_line_once() {
    local file="$1"
    local line="$2"
    sudo touch "$file"
    if ! grep -qxF -- "$line" "$file"; then
        printf '%s\n' "$line" | sudo tee -a "$file" >/dev/null
    fi
}

append_user_block_once() {
    local marker="$1"
    local file="$2"
    local tmp
    tmp="$(mktemp)"
    cat > "$tmp"
    sudo -u "$ADMIN_USER" touch "$file"
    if ! sudo -u "$ADMIN_USER" grep -q "$marker" "$file"; then
        sudo -u "$ADMIN_USER" sh -c "cat '$tmp' >> '$file'"
    fi
    rm -f "$tmp"
}

section() {
    echo ""
    echo "================================================"
    echo "$1"
    echo "================================================"
}

section "Debian 13 Trixie KDE Plasma Kurulumu - Bölüm 1"

# ============================================
# 1. TEMEL SİSTEM AYARLARI
# ============================================

section "[1/5] Temel sistem ayarları"

# Kişisel laptop tercihi: root şifresi aktif kalsın.
echo "Root şifresi ayarlanacak."
sudo passwd root

# Kişisel laptop tercihi: NOPASSWD kalsın; dosya visudo ile doğrulansın.
echo "$ADMIN_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee "/etc/sudoers.d/$ADMIN_USER" >/dev/null
sudo chmod 0440 "/etc/sudoers.d/$ADMIN_USER"
sudo visudo -cf "/etc/sudoers.d/$ADMIN_USER"

sudo usermod -aG sudo,adm,systemd-journal "$ADMIN_USER"

apt_update
apt_install \
    apt-file command-not-found ca-certificates gnupg lsb-release apt-transport-https

sudo apt-file update
if command -v update-command-not-found >/dev/null 2>&1; then
    sudo update-command-not-found || true
fi

append_user_block_once "IDEAPAD_CUSTOM_PROMPT_START" "$ADMIN_HOME/.bashrc" <<'PROMPT_EOF'

# IDEAPAD_CUSTOM_PROMPT_START
RESET="\[\e[0m\]"
NEON_ORANGE="\[\e[38;5;208m\]"
NEON_GREEN="\[\e[38;5;118m\]"
NEON_BLUE="\[\e[38;5;39m\]"
NEON_PINK="\[\e[38;5;205m\]"

if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    ssh_message="-ssh_session"
else
    ssh_message=""
fi

PS1="${NEON_ORANGE}\u${RESET}@${NEON_GREEN}\h${RESET}${ssh_message:+${NEON_PINK}${ssh_message}}${RESET}:${NEON_BLUE}\w${RESET}\$ "
# IDEAPAD_CUSTOM_PROMPT_END
PROMPT_EOF

# ============================================
# 2. ZRAM KURULUMU VE OPTİMİZASYONU
# ============================================

section "[2/5] ZRAM yapılandırması"

apt_install zram-tools

write_root_file /etc/default/zramswap 0644 <<'EOF_ZRAM'
ALGO=zstd
PERCENT=60
PRIORITY=100
EOF_ZRAM

sudo systemctl restart zramswap || true

write_root_file /etc/sysctl.d/99-ideapad-zram-tweaks.conf 0644 <<'EOF_SYSCTL'
vm.swappiness=50
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=10
kernel.sysrq=1
EOF_SYSCTL

sudo sysctl --system

# ============================================
# 3. TEMEL SİSTEM ARAÇLARI
# ============================================

section "[3/5] Temel sistem araçları"

apt_install \
    network-manager wireless-tools rfkill \
    dnsutils iproute2 usbutils pciutils dosfstools mtools exfatprogs ntfs-3g \
    p7zip-full unrar zip unzip rsync btop glances dmidecode upower \
    lm-sensors avahi-daemon curl wget git fwupd \
    nfs-common cifs-utils smartmontools ethtool powertop

sudo systemctl enable --now NetworkManager
sudo systemctl enable --now avahi-daemon || true

# ============================================
# 4. KERNEL, FIRMWARE VE SÜRÜCÜLER
# ============================================

section "[4/5] Kernel, firmware ve sürücüler"

apt_install \
    linux-headers-amd64 firmware-intel-graphics firmware-intel-misc \
    intel-microcode firmware-intel-sound firmware-iwlwifi firmware-misc-nonfree intel-microcode

# NVIDIA tercihi korunuyor.
echo "NVIDIA sürücü adayları:"
apt-cache policy nvidia-driver || true

apt_install \
    nvidia-kernel-dkms nvidia-driver nvidia-settings nvidia-smi

# Intel GPU / VA-API
apt_install \
    intel-media-va-driver-non-free \
    intel-gpu-tools \
    libigdgmm12

# Mesa / Vulkan / OpenGL
apt_install \
    libgl1-mesa-dri libglx-mesa0 libegl-mesa0 \
    mesa-vulkan-drivers mesa-va-drivers mesa-utils mesa-utils-bin libgbm1 \
    libvulkan1 vulkan-tools vulkan-validationlayers \
    libegl1 libgl1 libgles2 libglx0 libopengl0 \
    libglfw3 libepoxy0 libglu1-mesa libglew2.2 libglut3.12 \
    libdrm2 libdrm-common libdrm-intel1

# VA-API / VDPAU
apt_install \
    libva2 libva-drm2 libva-glx2 libva-wayland2 libva-x11-2 vainfo \
    libvdpau-va-gl1 vdpauinfo gstreamer1.0-vaapi

# Ekran / DDC / sensör
apt_install \
    libdisplay-info2 ddcutil i2c-tools

# Bluetooth - Logitech M241 için temel paketler + KDE entegrasyonu ikinci betikte de kurulacak.
apt_install \
    bluez bluez-tools bluez-hcidump bluez-firmware \
    libbluetooth3 libsbc1 sbc-tools

sudo systemctl enable --now bluetooth
sudo rfkill unblock all || true

# ============================================
# 5. MODPROBE & BLACKLIST AYARLARI
# ============================================

section "[5/5] Modprobe, GRUB ve initramfs ayarları"

# Intel iGPU donanımsal hızlandırma ve güç tasarrufu.
write_root_file /etc/modprobe.d/i915.conf 0644 <<'EOF_I915'
options i915 enable_guc=3 enable_fbc=1
EOF_I915

# NVIDIA DRM modeset - Wayland için korunuyor.
write_root_file /etc/modprobe.d/nvidia-drm.conf 0644 <<'EOF_NVIDIA_DRM'
options nvidia-drm modeset=1
EOF_NVIDIA_DRM

# Nouveau blacklist - NVIDIA proprietary sürücü tercihi korunuyor.
write_root_file /etc/modprobe.d/blacklist-gpu.conf 0644 <<'EOF_BLACKLIST'
blacklist nouveau
options nouveau modeset=0
EOF_BLACKLIST

# GRUB parametrelerini tekrarsız ekle.
if ! grep -q 'nvidia-drm.modeset=1' /etc/default/grub; then
    sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 splash nvidia-drm.modeset=1"/' /etc/default/grub
fi
sudo sed -i 's/quiet quiet/quiet/g; s/splash splash/splash/g; s/  */ /g' /etc/default/grub
sudo update-grub

# Early KMS modülleri initramfs'e tekrarsız ekle.
for mod in i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm; do
    append_line_once /etc/initramfs-tools/modules "$mod"
done

sudo sensors-detect --auto || true
sudo update-initramfs -u

section "Bölüm 1 tamamlandı"
echo "Önerilen sonraki adım: sudo reboot"
echo "Reboot sonrası: bash install2_fixed.sh"
