#!/bin/bash
# Debian Minimal KDE Plasma Installation - Part 2
# IdeaPad 530S-14IKB - Continuing After Reboot

set -e  # Exit on error

echo "================================================"
echo "Debian 13 Trixie KDE Plasma Installation - Part 2"
echo "================================================"
echo ""

# ============================================
# 1. PIPEWIRE + CODECS
# ============================================

echo "[1/6] Installing PipeWire and media codecs..."

sudo apt install -y \
    pipewire-audio gstreamer1.0-pipewire gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav \
    ffmpeg flac x264 x265 libavcodec-extra

# ============================================
# 2. BLUETOOTH + VPN TOOLS
# ============================================

echo "[2/6] Installing Bluetooth and VPN tools..."

sudo apt install -y \
    network-manager-openconnect network-manager-openvpn \
    wireguard-tools bluez

# ============================================
# 3. KDE PLASMA + APPS + POWER MANAGEMENT
# ============================================

echo "[3/6] Installing KDE Plasma desktop..."

sudo apt install -y \
    kde-plasma-desktop polkit-kde-agent-1 plasma-workspace-wallpapers \
    xdg-desktop-portal qml6-module-org-kde-notifications \
    kdegraphics-thumbnailers kate kcalc ark gwenview \
    plymouth-themes powerdevil xdg-desktop-portal-kde

# Fonts and Source Code Pro Integration
echo "Installing fonts..."

sudo apt install -y \
    fonts-noto fonts-noto-color-emoji fonts-dejavu fonts-liberation \
    fonts-inter fonts-roboto fonts-ubuntu fonts-cantarell fonts-noto-cjk \
    unzip fontconfig wget

echo "Downloading and configuring Source Code Pro (via Adobe GitHub)..."
mkdir -p ~/.local/share/fonts/SourceCodePro
wget -qO /tmp/scp.zip "https://github.com/adobe-fonts/source-code-pro/archive/refs/heads/release.zip"
unzip -qo /tmp/scp.zip -d /tmp/scp_extracted
find /tmp/scp_extracted -name "*.ttf" -exec mv {} ~/.local/share/fonts/SourceCodePro/ \;
rm -rf /tmp/scp.zip /tmp/scp_extracted
fc-cache -fv ~/.local/share/fonts > /dev/null

# Media players
echo "Installing media players..."

sudo apt install -y mpv vlc

echo "Configuring MPV hardware acceleration (Zero-Copy)..."
mkdir -p ~/.config/mpv
cat > ~/.config/mpv/mpv.conf << 'EOF'
hwdec=vaapi
vo=gpu
gpu-context=wayland
EOF

# ============================================
# 4. FIREFOX INSTALLATION
# ============================================

echo "[4/6] Installing Firefox..."

# Install gnupg if missing
sudo apt install -y gnupg

sudo install -d -m 0755 /etc/apt/keyrings

wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | \
    sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null

gpg -n -q --import --import-options import-show \
    /etc/apt/keyrings/packages.mozilla.org.asc 2>&1 | grep -A 1 "^pub" || true

cat << 'EOF' | sudo tee /etc/apt/sources.list.d/mozilla.sources
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF

cat << 'EOF' | sudo tee /etc/apt/preferences.d/mozilla
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

sudo apt update
sudo apt install -y firefox

# ============================================
# 5. FONT RENDERING AND KDE PLASMA SIZING
# ============================================

echo "[5/6] Configuring openSUSE-style font rendering and font families..."

mkdir -p ~/.config/fontconfig

cat > ~/.config/fontconfig/fonts.conf << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
    <edit name="hinting" mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
    <edit name="rgba" mode="assign"><const>rgb</const></edit>
    <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
  </match>

  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Roboto</family>
      <family>Noto Sans</family>
    </prefer>
  </alias>
  <alias>
    <family>serif</family>
    <prefer>
      <family>Liberation Serif</family>
      <family>Noto Serif</family>
    </prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <prefer>
      <family>Source Code Pro</family>
    </prefer>
  </alias>
</fontconfig>
EOF

echo "Applying font sizes to KDE Plasma interface..."
# Qt6 format: Family,Size,-1,5,Weight(400=Normal),0,0,0,0,0,0,0,0,0,0,1
kwriteconfig6 --file kdeglobals --group General --key font "Roboto,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file kdeglobals --group General --key fixed "Source Code Pro,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file kdeglobals --group General --key smallestReadableFont "Roboto,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file kdeglobals --group General --key toolBarFont "Roboto,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file kdeglobals --group General --key menuFont "Roboto,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key font "Roboto,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"

# ============================================
# 6. DISABLE WIFI AND BLUETOOTH POWER SAVING
# ============================================

echo "[6/6] Disabling WiFi and Bluetooth power saving..."

cat << 'EOF' | sudo tee /etc/modprobe.d/iwlwifi-power.conf
options iwlwifi power_save=0
EOF

cat << 'EOF' | sudo tee /etc/NetworkManager/conf.d/wifi-powersave-off.conf
[connection]
wifi.powersave = 2
EOF

cat << 'EOF' | sudo tee /etc/udev/rules.d/50-bluetooth-power.rules
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{power/control}="on"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger
sudo systemctl restart NetworkManager

echo ""
echo "✓ WiFi and Bluetooth power saving DISABLED"
echo "✓ Connection stability maximized"
echo "✓ Changes will be fully active after reboot"
echo ""

sudo apt update
sudo apt autoremove -y

# ============================================
# INSTALLATION COMPLETED
# ============================================

echo ""
echo "================================================"
echo "Installation Completed!"
echo "================================================"
echo ""
echo "System Information:"
echo "----------------"
echo "• Desktop Environment: KDE Plasma 6"
echo "• Audio System: PipeWire"
echo "• Font Architecture: openSUSE Profile (Roboto & Source Code Pro)"
echo "• Graphics: Intel + NVIDIA (Intel iHD enforced)"
echo "• Video Acceleration: VA-API Active (GuC/HuC Mode)"
echo ""
echo "Performing final reboot..."
sleep 10

sudo reboot
