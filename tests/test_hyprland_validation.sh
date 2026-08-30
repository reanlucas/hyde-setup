#!/usr/bin/env bash
# Uma configuracao invalida nunca pode substituir o override que ja funcionava.
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin" "$WORK/config/hypr"
printf '%s\n' '-- configuracao anterior valida' >"$WORK/config/hypr/hyprland.lua"
cat >"$WORK/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$WORK/bin/hyprctl"

cat >"$WORK/valid.conf" <<'EOF'
MONITOR_SAIDA="DP-2"
MONITOR_MODO="2560x1440@360"
MONITOR_POSICAO="0x0"
MONITOR_ESCALA="1.25"
MONITOR_BITDEPTH="10"
MONITOR_CM="srgb"
KB_LAYOUT="us"
KB_VARIANT="intl"
HYDEAI_TECLA1="SUPER, I"
HYDEAI_TECLA2="SUPER, dead_grave"
WIDGETS_TECLA="SUPER, D"
FULLSCREEN_TECLA="SHIFT, F11"
SPOTIFY_TRAY=0
EOF

# Aspas e dois-pontos sao texto, nao devem quebrar a geracao de Lua.
sed "s|^MONITOR_SAIDA=.*|MONITOR_SAIDA='DP-2\" : literal'|" \
    "$WORK/valid.conf" >"$WORK/quoted.conf"
XDG_CONFIG_HOME="$WORK/config" PATH="$WORK/bin:$PATH" \
HYDE_SETUP_CONF="$WORK/quoted.conf" bash "$BASE/scripts/20-hyprland.sh"
luac -p "$WORK/config/hypr/hyprland.lua"
cp "$WORK/config/hypr/hyprland.lua" "$WORK/after-valid.lua"

# Valores numericos sao validados e o arquivo anterior permanece intacto.
sed 's/^MONITOR_ESCALA=.*/MONITOR_ESCALA="1.25; invalido"/' \
    "$WORK/valid.conf" >"$WORK/invalid.conf"
if XDG_CONFIG_HOME="$WORK/config" PATH="$WORK/bin:$PATH" \
   HYDE_SETUP_CONF="$WORK/invalid.conf" bash "$BASE/scripts/20-hyprland.sh"; then
    echo "a etapa aceitou numero invalido" >&2
    exit 1
fi
cmp -s "$WORK/after-valid.lua" "$WORK/config/hypr/hyprland.lua"

printf 'ok: hyprland validation\n'
