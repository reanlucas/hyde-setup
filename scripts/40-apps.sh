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

if [ "${KITTY_COPIA_COLA:-0}" = "1" ] && command -v kitty >/dev/null 2>&1; then
    echo "==> kitty com Ctrl+C / Ctrl+V"
    CONF="$HOME/.config/kitty/kitty.conf"
    mkdir -p "$(dirname "$CONF")"
    touch "$CONF"
    if ! grep -q "hyde-setup: copia e cola" "$CONF"; then
        cat >> "$CONF" <<'KITTY'

# >>> hyde-setup: copia e cola
# copy_or_interrupt (e nao copy_to_clipboard): havendo selecao, copia; sem
# selecao, manda o SIGINT normal. Sem isso Ctrl+C deixaria de interromper
# processos, que e o uso mais frequente da tecla num terminal.
map ctrl+c  copy_or_interrupt
map ctrl+v  paste_from_clipboard
# os originais continuam valendo, para quem tem o dedo acostumado
map ctrl+shift+c  copy_to_clipboard
map ctrl+shift+v  paste_from_clipboard
# <<< hyde-setup
KITTY
    fi
    pkill -USR1 -x kitty 2>/dev/null || true    # recarrega sem fechar
fi

if [ "${VSCODE_WALLBASH:-0}" = "1" ]; then
    echo "==> VS Code com o tema do wallbash"
    for dir in "$HOME/.config/Code/User" "$HOME/.config/VSCodium/User"; do
        [ -d "$(dirname "$dir")" ] || continue
        mkdir -p "$dir"
        [ -f "$dir/settings.json" ] || echo '{}' > "$dir/settings.json"
        python3 - "$dir/settings.json" <<'PY'
import json, sys
alvo = sys.argv[1]
try:
    with open(alvo) as f:
        d = json.load(f)
except Exception:
    d = {}
d["workbench.colorTheme"] = "Wallbash"
with open(alvo, "w") as f:
    json.dump(d, f, indent=2)
PY
    done
    hyde-shell wallbash code >/dev/null 2>&1 || true
fi

if [ -n "${WAYBAR_ESCALA:-}" ]; then
    echo "==> Escala do waybar: ${WAYBAR_ESCALA}px"
    # WAYBAR_SCALE e a fonte de maior prioridade que o waybar.py consulta;
    # o padrao do HyDE (10px) fica pequeno em monitor grande com escala 1.25.
    ESTADO="${XDG_STATE_HOME:-$HOME/.local/state}/hyde/config"
    mkdir -p "$(dirname "$ESTADO")"; touch "$ESTADO"
    if grep -q "^WAYBAR_SCALE=" "$ESTADO"; then
        sed -i "s/^WAYBAR_SCALE=.*/WAYBAR_SCALE=${WAYBAR_ESCALA}/" "$ESTADO"
    else
        echo "WAYBAR_SCALE=${WAYBAR_ESCALA}" >> "$ESTADO"
    fi
    [ -x "$HOME/.local/lib/hyde/waybar.py" ] \
        && "$HOME/.local/lib/hyde/waybar.py" -g >/dev/null 2>&1 || true
fi

if [ "$GPU_VENDOR" = "amd" ]; then
    echo "==> Vulkan AMD"
    sudo pacman -S --needed --noconfirm vulkan-radeon lib32-vulkan-radeon || true
fi
