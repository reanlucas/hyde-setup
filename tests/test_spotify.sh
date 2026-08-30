#!/usr/bin/env bash
# Confere instalacao, entrada desktop e fallback do launcher do Spotify.
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin" "$WORK/home"
cat >"$WORK/setup.conf" <<'EOF'
SPOTIFY_TRAY=1
SPICETIFY=0
KITTY_COPIA_COLA=0
VSCODE_WALLBASH=0
WAYBAR_ESCALA=""
GPU_VENDOR="intel"
EOF
cat >"$WORK/bin/spotify" <<'EOF'
#!/usr/bin/env bash
printf 'spotify\t%s\n' "$*" >>"$SPOTIFY_TEST_LOG"
EOF
cat >"$WORK/bin/update-desktop-database" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$WORK/bin/"*

HOME="$WORK/home" \
XDG_STATE_HOME="$WORK/state" \
HYPRLAND_INSTANCE_SIGNATURE="" \
HYDE_SETUP_CONF="$WORK/setup.conf" \
PATH="$WORK/bin:$PATH" \
bash "$BASE/scripts/40-apps.sh"

[ -x "$WORK/home/.local/bin/hyde-spotify" ]
grep -Fxq -- '--ozone-platform=wayland' "$WORK/home/.config/spotify-flags.conf"
grep -Fq "$WORK/home/.local/bin/hyde-spotify --show --uri=%u" \
    "$WORK/home/.local/share/applications/spotify.desktop"

# Sem uma sessao Hyprland, o wrapper deve continuar funcionando como um
# launcher normal e preservar URIs recebidas da entrada desktop.
SPOTIFY_TEST_LOG="$WORK/calls.log" \
HYDE_SPOTIFY_BIN="$WORK/bin/spotify" \
HYPRLAND_INSTANCE_SIGNATURE="" \
XDG_STATE_HOME="$WORK/state" \
HOME="$WORK/home" \
"$WORK/home/.local/bin/hyde-spotify" --show --uri=spotify:test
grep -Fxq $'spotify\t--uri=spotify:test' "$WORK/calls.log"

printf 'ok: spotify launcher\n'
