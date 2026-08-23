#!/usr/bin/env bash
# Escreve as personalizacoes no override do usuario (~/.config/hypr/hyprland.lua),
# que o HyDE nunca sobrescreve. Trecho delimitado para poder reescrever.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../setup.conf"

ALVO="$HOME/.config/hypr/hyprland.lua"
INI="-- >>> hyde-setup"
FIM="-- <<< hyde-setup"

[ -f "$ALVO" ] || { echo "$ALVO nao existe -- o HyDE foi instalado?" >&2; exit 1; }
cp "$ALVO" "$ALVO.bak-$(date +%Y%m%d-%H%M%S)"

# remove um bloco anterior, para o script ser idempotente
python3 - "$ALVO" "$INI" "$FIM" <<'PY'
import sys, re
alvo, ini, fim = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(alvo).read()
s = re.sub(re.escape(ini) + r".*?" + re.escape(fim) + r"\n?", "", s, flags=re.S)
open(alvo, "w").write(s.rstrip() + "\n")
PY

# Spotify na bandeja: regra de janela + autostart, montados aqui para que o
# bloco continue sendo escrito de uma vez so.
SPOTIFY_LUA=""
SPOTIFY_EXEC=""
if [ "${SPOTIFY_TRAY:-0}" = "1" ]; then
    SPOTIFY_LUA='
-- Spotify sobe com a sessao e vai direto para o scratchpad: sem roubar foco,
-- sem ocupar workspace. A bandeja do waybar e o widget de player controlam a
-- reproducao; SUPER + S (bind do HyDE) mostra a janela.
--
-- "--minimized" nao serve: o proprio "spotify --help" diz que so vale no
-- Windows. No Hyprland quem minimiza e a regra de janela.
hl.window_rule({
    name             = "spotify-bandeja",
    match            = { class = "^([Ss]potify)$" },
    workspace        = "special silent",
    no_initial_focus = true,
})
'
    SPOTIFY_EXEC='
    hl.exec_cmd("spotify --ozone-platform=wayland")'
fi

cat >> "$ALVO" <<LUA

$INI
-- Gerado por hyde-setup. Editar setup.conf e rodar de novo reescreve isto.

hl.monitor({
    output   = "${MONITOR_SAIDA}",
    mode     = "${MONITOR_MODO}",
    position = "${MONITOR_POSICAO}",
    scale    = ${MONITOR_ESCALA},
    bitdepth = ${MONITOR_BITDEPTH},
    cm       = "${MONITOR_CM}",
})

hl.config({
    input = {
        kb_layout  = "${KB_LAYOUT}",
        kb_variant = "${KB_VARIANT}",
    },
})

hl.bind("${HYDEAI_TECLA1/, / + }", hl.dsp.exec_cmd("\$HOME/.local/bin/hyde-ai --toggle"), {
    description = "[Launcher|Apps] AI sidebar",
})
hl.bind("${HYDEAI_TECLA2/, / + }", hl.dsp.exec_cmd("\$HOME/.local/bin/hyde-ai --toggle"), {
    description = "[Launcher|Apps] AI sidebar",
})
hl.bind("${WIDGETS_TECLA/, / + }", hl.dsp.exec_cmd("\$HOME/.local/bin/hyde-widgets --toggle"), {
    description = "[Launcher|Apps] widgets do desktop",
})

-- Vidro real nas superficies dos widgets
hl.layer_rule({ "blur", "ignorealpha 0.2" }, "hyde-widgets")
${SPOTIFY_LUA}
hl.on("hyprland.start", function()
    hl.exec_cmd("\$HOME/.local/bin/hyde-widgets --show")
    hl.exec_cmd("\$HOME/.local/bin/hyde-ai --daemon")${SPOTIFY_EXEC}
end)
$FIM
LUA

command -v luac >/dev/null && luac -p "$ALVO" || true
hyprctl reload >/dev/null 2>&1 || true
echo "==> hyprland.lua atualizado"
