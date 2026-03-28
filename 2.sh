#!/bin/bash
# Debian Minimal KDE Plasma Kurulumu - Bölüm 2
# IdeaPad 530S-14IKB - Reboot Sonrası Devam

set -e  # Hata durumunda scripti durdur

echo "================================================"
echo "Debian 13 Trixie KDE Plasma Kurulumu - Bölüm 2"
echo "================================================"
echo ""

# ============================================
# 1. PİPEWİRE + KODEKLER
# ============================================

echo "[1/6] PipeWire ve medya kodekleri kuruluyor..."

sudo apt install -y \
    pipewire-audio gstreamer1.0-pipewire gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav \
    ffmpeg flac x264 x265 libavcodec-extra

# ============================================
# 2. BLUETOOTH + VPN ARAÇLARI
# ============================================

echo "[2/6] Bluetooth ve VPN araçları kuruluyor..."

sudo apt install -y \
    network-manager-openconnect network-manager-openvpn \
    wireguard-tools bluez

# ============================================
# 3. KDE PLASMA + UYGULAMALAR + GÜÇ YÖNETİMİ
# ============================================

echo "[3/6] KDE Plasma masaüstü kuruluyor..."

sudo apt install -y \
    kde-plasma-desktop polkit-kde-agent-1 plasma-workspace-wallpapers \
    xdg-desktop-portal qml6-module-org-kde-notifications \
    kdegraphics-thumbnailers kate kcalc ark gwenview \
    plymouth-themes powerdevil xdg-desktop-portal-kde

# Fontlar ve Source Code Pro Entegrasyonu
echo "Fontlar kuruluyor..."

sudo apt install -y \
    fonts-noto fonts-noto-color-emoji fonts-dejavu fonts-liberation \
    fonts-inter fonts-roboto fonts-ubuntu fonts-cantarell fonts-noto-cjk \
    unzip fontconfig wget

echo "Source Code Pro (Adobe GitHub üzerinden) indirilip yapılandırılıyor..."
mkdir -p ~/.local/share/fonts/SourceCodePro
wget -qO /tmp/scp.zip "https://github.com/adobe-fonts/source-code-pro/archive/refs/heads/release.zip"
unzip -qo /tmp/scp.zip -d /tmp/scp_extracted
find /tmp/scp_extracted -name "*.ttf" -exec mv {} ~/.local/share/fonts/SourceCodePro/ \;
rm -rf /tmp/scp.zip /tmp/scp_extracted
fc-cache -fv ~/.local/share/fonts > /dev/null

# Medya oynatıcılar
echo "Medya oynatıcılar kuruluyor..."

sudo apt install -y mpv vlc

echo "MPV donanım hızlandırma (Zero-Copy) ayarlanıyor..."
mkdir -p ~/.config/mpv
cat > ~/.config/mpv/mpv.conf << 'EOF'
hwdec=vaapi
vo=gpu
gpu-context=wayland
EOF

# ============================================
# 4. FIREFOX KURULUMU
# ============================================

echo "[4/6] Firefox kuruluyor..."

# gnupg eksikse kur
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
# 5. FONT RENDERİNG VE KDE PLASMA BOYUT AYARLARI
# ============================================

echo "[5/6] openSUSE tarzı Font rendering ve Font aileleri ayarlanıyor..."

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

echo "KDE Plasma arayüzüne font boyutları işleniyor..."
# Qt6 formatı: Family,Size,-1,5,Weight(400=Normal),0,0,0,0,0,0,0,0,0,0,1
kwriteconfig6 --file kdeglobals --group General --key font "Roboto,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file kdeglobals --group General --key fixed "Source Code Pro,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file kdeglobals --group General --key smallestReadableFont "Roboto,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file kdeglobals --group General --key toolBarFont "Roboto,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file kdeglobals --group General --key menuFont "Roboto,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key font "Roboto,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"

# ============================================
# 6. WiFi VE BLUETOOTH GÜÇ TASARRUFU KAPATMA
# ============================================

echo "[6/6] WiFi ve Bluetooth güç tasarrufu kapatılıyor..."

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
echo "✓ WiFi ve Bluetooth güç tasarrufu KAPATILDI"
echo "✓ Bağlantı stabilitesi maksimum"
echo "✓ Reboot sonrası ayarlar tam aktif olur"
echo ""

sudo apt update
sudo apt autoremove -y

# ============================================
# KURULUM TAMAMLANDI
# ============================================

echo ""
echo "================================================"
echo "Kurulum Tamamlandı!"
echo "================================================"
echo ""
echo "Sistem Bilgileri:"
echo "----------------"
echo "• Masaüstü: KDE Plasma 6"
echo "• Ses Sistemi: PipeWire"
echo "• Font Mimarisi: openSUSE Profili (Roboto & Source Code Pro)"
echo "• Grafik: Intel + NVIDIA (Intel iHD zorunlu kılındı)"
echo "• Video İvmelendirme: VA-API Aktif (GuC/HuC Modu)"
echo ""
echo "Son reboot yapılıyor..."
sleep 10

sudo reboot
