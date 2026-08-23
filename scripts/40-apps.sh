#!/usr/bin/env bash
# Spotify na bandeja, spicetify com as cores do tema, e o Vulkan certo.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../setup.conf"

if [ "${SPOTIFY_TRAY:-0}" = "1" ] && command -v spotify >/dev/null 2>&1; then
    echo "==> Spotify inicia na bandeja"
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/spotify-tray.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Name=Spotify (bandeja)
Exec=spotify --ozone-platform=wayland --minimized
X-GNOME-Autostart-enabled=true
NoDisplay=true
DESK
    # spotify-flags.conf: o HyDE ja usa este arquivo para as flags do cliente
    printf -- '--ozone-platform=wayland\n' > "$HOME/.config/spotify-flags.conf"
fi

if [ "${SPICETIFY:-0}" = "1" ] && command -v spicetify >/dev/null 2>&1; then
    echo "==> Spicetify com as cores do wallbash"
    # spicetify altera arquivos em /opt/spotify, que pertencem ao root
    sudo chmod a+wr /opt/spotify 2>/dev/null || true
    sudo chmod a+wr -R /opt/spotify/Apps 2>/dev/null || true
    pkill -x spotify 2>/dev/null || true
    hyde-shell wallbash spotify >/dev/null 2>&1 || true
    echo "    obs: atualizacoes do pacote spotify desfazem isto; rode de novo"
fi

if [ "$GPU_VENDOR" = "amd" ]; then
    echo "==> Vulkan AMD"
    sudo pacman -S --needed --noconfirm vulkan-radeon lib32-vulkan-radeon || true
fi
