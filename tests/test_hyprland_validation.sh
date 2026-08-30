#!/usr/bin/env bash
# Uma configuracao invalida nunca pode substituir o override que ja funcionava.
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin" "$WORK/config/hypr"
cat >"$WORK/config/hypr/hyprland.lua" <<'EOF'
-- configuracao anterior valida

-- >>> hyde-setup:nautilus
hl.window_rule({ name = "nautilus-test", match = { class = "Nautilus" } })
-- <<< hyde-setup:nautilus

-- ── Spotify na bandeja ────────────────────────────────────────────────
hl.on("hyprland.start", function()
    hl.exec_cmd("spotify --ozone-platform=wayland")
end)

-- ── Fullscreen ────────────────────────────────────────────────────────
EOF
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
SPOTIFY_TRAY=1
EOF

# Aspas e dois-pontos sao texto, nao devem quebrar a geracao de Lua.
sed "s|^MONITOR_SAIDA=.*|MONITOR_SAIDA='DP-2\" : literal'|" \
    "$WORK/valid.conf" >"$WORK/quoted.conf"
XDG_CONFIG_HOME="$WORK/config" PATH="$WORK/bin:$PATH" \
HYDE_SETUP_CONF="$WORK/quoted.conf" bash "$BASE/scripts/20-hyprland.sh"
luac -p "$WORK/config/hypr/hyprland.lua"
grep -Fq -- '-- >>> hyde-setup:nautilus' "$WORK/config/hypr/hyprland.lua"
grep -Fq 'nautilus-test' "$WORK/config/hypr/hyprland.lua"
grep -Fq '$HOME/.local/bin/hyde-spotify --background' \
    "$WORK/config/hypr/hyprland.lua"
if grep -Fq 'hl.exec_cmd("spotify --ozone-platform=wayland")' \
   "$WORK/config/hypr/hyprland.lua"; then
    echo "autostart Spotify legado nao foi removido" >&2
    exit 1
fi
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

# Reproduz a falha observada: o arquivo ja chega invalido, antes do bloco do
# setup. A etapa precisa preservar esse original e reconstruir o entrypoint.
cat >"$WORK/config/hypr/hyprland.lua" <<'EOF'
-- configuracao corrompida recebida da migracao anterior
monitor: DP-2, 2560x1440@360
EOF
HYDE_DIR="$WORK/HyDE-ausente" XDG_CONFIG_HOME="$WORK/config" PATH="$WORK/bin:$PATH" \
HYDE_SETUP_CONF="$WORK/valid.conf" bash "$BASE/scripts/20-hyprland.sh"
luac -p "$WORK/config/hypr/hyprland.lua"
grep -Fq 'dofile(entry)' "$WORK/config/hypr/hyprland.lua"
grep -Fq -- '-- >>> hyde-setup' "$WORK/config/hypr/hyprland.lua"
find "$WORK/config/hypr" -maxdepth 1 -name 'hyprland.lua.bak-*' \
    -exec grep -lF 'monitor: DP-2' {} + | grep -q .

printf 'ok: hyprland validation\n'
