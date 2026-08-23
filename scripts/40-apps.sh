#!/usr/bin/env bash
# Spotify na bandeja, spicetify com as cores do tema, e o Vulkan certo.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../setup.conf"

if [ "${SPOTIFY_TRAY:-0}" = "1" ] && command -v spotify >/dev/null 2>&1; then
    echo "==> Spotify na bandeja"
    # O autostart e a regra de janela ficam no bloco lua (etapa 20). Aqui so
    # as flags do cliente. Um .desktop em ~/.config/autostart nao serviria:
    # o Hyprland nao dispara o xdg-desktop-autostart por conta propria.
    printf -- '--ozone-platform=wayland\n' > "$HOME/.config/spotify-flags.conf"
    rm -f "$HOME/.config/autostart/spotify-tray.desktop"   # de versoes antigas
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
