#!/usr/bin/env bash
# Debian 13 Trixie Minimal KDE Plasma Kurulumu - Bölüm 2
# IdeaPad 530S-14IKB - Reboot Sonrası Devam
# Hedef: KDE Plasma + PipeWire + Emby beta + medya/GPU hızlandırma

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

section() {
    echo ""
    echo "================================================"
    echo "$1"
    echo "================================================"
}

section "Debian 13 Trixie KDE Plasma Kurulumu - Bölüm 2"

# ============================================
# 1. PİPEWIRE + KODEKLER
# ============================================

section "[1/8] PipeWire ve medya kodekleri"

apt_update
apt_install \
    pipewire-audio wireplumber gstreamer1.0-pipewire \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav gstreamer1.0-tools gstreamer1.0-vaapi \
    ffmpeg ffmpegthumbnailer flac x264 x265 libavcodec-extra

# ============================================
# 2. GÖRÜNTÜ FORMAT KÜTÜPHANELERİ
# ============================================

section "[2/8] Görüntü format kütüphaneleri"

apt_install \
    libjpeg62-turbo libpng16-16t64 libtiff6 libwebp7 libjxl0.11 \
    libopenjp2-7 libopenexr-3-1-30 libgif7 libgdk-pixbuf-2.0-0 \
    libraw23t64 libimlib2t64

# ============================================
# 3. 2D GRAFİK / RENK YÖNETİMİ / V4L
# ============================================

section "[3/8] 2D grafik, renk yönetimi ve V4L"

apt_install \
    libpixman-1-0 libcairo2 libpango-1.0-0 libharfbuzz0b \
    libfreetype6 liblcms2-2 libcolord2 colord \
    libgraphene-1.0-0 v4l-utils libv4l-0

# ============================================
# 4. VPN / AĞ ARAÇLARI
# ============================================

section "[4/8] VPN ve ağ araçları"

apt_install \
    network-manager network-manager-openconnect network-manager-openvpn \
    wireguard-tools plasma-nm

sudo systemctl enable --now NetworkManager

# ============================================
# 5. KDE PLASMA + LAPTOP UYGULAMALARI
# ============================================

section "[5/8] KDE Plasma masaüstü"

apt_install \
    kde-plasma-desktop sddm \
    plasma-workspace-wallpapers powerdevil plasma-pa plasma-nm bluedevil \
    polkit-kde-agent-1 xdg-desktop-portal xdg-desktop-portal-kde \
    qml6-module-org-kde-notifications \
    kdegraphics-thumbnailers kde-config-screenlocker kde-config-sddm kscreen \
    dolphin konsole kate kcalc ark gwenview okular spectacle kdeconnect \
    plymouth-themes

sudo apt-get purge -y plasma-thunderbolt || true

# Locale ayarı.
sudo locale-gen tr_TR.UTF-8
sudo update-locale LANG=tr_TR.UTF-8 LC_ALL=tr_TR.UTF-8

sudo systemctl enable sddm

# SDDM'in GPU hazır olmadan başlamasını engelle.
sudo mkdir -p /etc/systemd/system/sddm.service.d
write_root_file /etc/systemd/system/sddm.service.d/override.conf 0644 <<'EOF_SDDM_OVERRIDE'
[Unit]
Wants=systemd-logind.service
After=systemd-logind.service
ConditionPathExistsGlob=/dev/dri/card*
EOF_SDDM_OVERRIDE

# Plasma Wayland oturumu varsayılan olsun. SDDM greeter'ı Wayland'a zorlamıyoruz;
# hibrit Intel+NVIDIA dizüstünde giriş ekranı kararlılığı için daha güvenli.
sudo mkdir -p /etc/sddm.conf.d
write_root_file /etc/sddm.conf.d/10-plasma-session.conf 0644 <<'EOF_SDDM_SESSION'
[General]
DefaultSession=plasmawayland.desktop
EOF_SDDM_SESSION

sudo systemctl daemon-reload

# Bluetooth servisleri.
sudo systemctl enable --now bluetooth
sudo rfkill unblock all || true

# ============================================
# 6. MEDYA OYNATICILAR + EMBY BETA
# ============================================

section "[6/8] Medya oynatıcılar ve Emby beta"

apt_install mpv vlc yt-dlp

# Emby beta tercihi korunuyor: stabil sürüm eski olduğu için donanım hızlandırma hedefiyle beta kullanılıyor.
sudo install -d -m 0755 /etc/apt/keyrings
sudo curl -fsSL https://pkg.emby.media/keys/emby-public.gpg -o /etc/apt/keyrings/emby-public.gpg
sudo chmod 0644 /etc/apt/keyrings/emby-public.gpg
sudo curl -fsSL https://pkg.emby.media/apt/emby-beta.sources -o /etc/apt/sources.list.d/emby-beta.sources
apt_update
apt_install media.emby.client.beta

# mpv: VA-API ana yol; Vulkan açık bırakıldı çünkü hedef akıcı video ve GPU path.
sudo -u "$ADMIN_USER" mkdir -p "$ADMIN_HOME/.config/mpv"
sudo -u "$ADMIN_USER" tee "$ADMIN_HOME/.config/mpv/mpv.conf" >/dev/null <<'EOF_MPV'
vo=gpu-next
gpu-api=vulkan
hwdec=vaapi
hwdec-codecs=all
vd-lavc-dr=yes
profile=gpu-hq
dscale=mitchell
correct-downscaling=yes
linear-downscaling=yes
tone-mapping=bt.2446a
hdr-compute-peak=yes
sub-auto=fuzzy
EOF_MPV

# ============================================
# 7. FIREFOX KURULUMU
# ============================================

section "[7/8] Firefox"

apt_install gnupg ca-certificates
sudo install -d -m 0755 /etc/apt/keyrings
sudo curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg \
    -o /etc/apt/keyrings/packages.mozilla.org.asc
sudo chmod 0644 /etc/apt/keyrings/packages.mozilla.org.asc

gpg -n -q --import --import-options import-show \
    /etc/apt/keyrings/packages.mozilla.org.asc 2>&1 | grep -A 1 '^pub' || true

write_root_file /etc/apt/sources.list.d/mozilla.sources 0644 <<'EOF_MOZILLA_SRC'
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF_MOZILLA_SRC

# Sadece Firefox paketlerini Mozilla deposundan tercih et; tüm paketleri pinleme.
write_root_file /etc/apt/preferences.d/mozilla 0644 <<'EOF_MOZILLA_PREF'
Package: firefox firefox-l10n-* firefox-locale-*
Pin: origin packages.mozilla.org
Pin-Priority: 700
EOF_MOZILLA_PREF

apt_update
apt_install firefox firefox-l10n-tr
sudo apt-get purge -y firefox-esr || true

# ============================================
# 8. ENGPLAYER + NFS STORAGE
# ============================================

section "[8/8] EngPlayer ve Thinkserver NFS"

apt_install \
    python3-dev python3-venv python3-pip python3-gi python3-gi-cairo \
    gcc make pkg-config libcairo2-dev libgirepository-2.0-dev \
    gir1.2-gtk-4.0 gir1.2-adw-1 gettext \
    gir1.2-gstreamer-1.0 gstreamer1.0-gtk4 gstreamer1.0-vaapi

sudo -u "$ADMIN_USER" mkdir -p "$ADMIN_HOME/src"
if [[ -d "$ADMIN_HOME/src/EngPlayer/.git" ]]; then
    sudo -u "$ADMIN_USER" git -C "$ADMIN_HOME/src/EngPlayer" pull --ff-only
else
    sudo -u "$ADMIN_USER" git clone https://github.com/Falldaemon/EngPlayer.git "$ADMIN_HOME/src/EngPlayer"
fi

sudo -u "$ADMIN_USER" make -C "$ADMIN_HOME/src/EngPlayer" install-manual

apt_install nfs-common wsdd2
sudo systemctl enable --now wsdd2 || true

sudo -u "$ADMIN_USER" mkdir -p "$ADMIN_HOME/storage"
NFS_LINE="192.168.1.3:/srv/storage $ADMIN_HOME/storage nfs defaults,_netdev,noauto,x-systemd.automount,x-systemd.requires=network-online.target,x-systemd.mount-timeout=5,x-systemd.idle-timeout=1min,soft,timeo=10,retrans=1 0 0"
append_line_once /etc/fstab "$NFS_LINE"

sudo systemctl daemon-reload
sudo systemctl disable --now nfs-blkmap.service || true

apt_update
sudo apt-get autoremove --purge -y

section "Kurulum tamamlandı"
echo "Sistem Bilgileri:"
echo "• Masaüstü: KDE Plasma Wayland oturumu"
echo "• Giriş yöneticisi: SDDM, greeter Wayland'a zorlanmadı"
echo "• Ses Sistemi: PipeWire / WirePlumber"
echo "• Grafik: Intel UHD 620 + NVIDIA MX130 proprietary"
echo "• Video: Intel VA-API + mpv gpu-next/Vulkan + Emby beta"
echo "• Bluetooth: BlueZ + Bluedevil"
echo "• NFS: $ADMIN_HOME/storage"
echo ""
echo "Son reboot yapılıyor..."
sleep 10
sudo reboot
