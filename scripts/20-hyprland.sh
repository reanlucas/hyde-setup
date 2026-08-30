#!/usr/bin/env bash
# Escreve as personalizacoes no override do usuario (~/.config/hypr/hyprland.lua),
# que o HyDE nunca sobrescreve. Trecho delimitado para poder reescrever.
set -uo pipefail
CONF="${HYDE_SETUP_CONF:-$(dirname "${BASH_SOURCE[0]}")/../setup.conf}"
# shellcheck disable=SC1090
if ! . "$CONF"; then
    echo "ERRO: nao foi possivel ler $CONF" >&2
    exit 1
fi

ALVO="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
INI="-- >>> hyde-setup"
FIM="-- <<< hyde-setup"

[ -f "$ALVO" ] || { echo "$ALVO nao existe -- o HyDE foi instalado?" >&2; exit 1; }
BAK="$ALVO.bak-$(date +%Y%m%d-%H%M%S)"
cp "$ALVO" "$BAK"

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

-- O bind do HyDE cicla tres estados: 0 -> 1 (maximizar) -> 2 (fullscreen).
-- Num layout de tiles o estado 1 e visualmente identico a janela ja
-- ladrilhada, entao a primeira tecla nao muda nada na tela e o atalho parece
-- quebrado -- so na segunda vem o fullscreen. Aqui vira alternancia direta.
hl.bind("${FULLSCREEN_TECLA/, / + }", hl.dsp.window.fullscreen(), {
    description = "[Window Management] toggle fullscreen",
})
${SPOTIFY_LUA}
hl.on("hyprland.start", function()
    hl.exec_cmd("\$HOME/.local/bin/hyde-widgets --show")
    hl.exec_cmd("\$HOME/.local/bin/hyde-ai --daemon")${SPOTIFY_EXEC}
end)
$FIM
LUA

if command -v luac >/dev/null 2>&1 && ! luac -p "$ALVO"; then
    echo "ERRO: o bloco gerado nao e Lua valido; restaurando $BAK" >&2
    cp "$BAK" "$ALVO"
    exit 1
fi
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
    ERROS="$(hyprctl configerrors 2>/dev/null | tr -d '[:space:]')"
    if [ -n "$ERROS" ]; then
        echo "ERRO: o Hyprland recusou o bloco; restaurando $BAK" >&2
        hyprctl configerrors >&2
        cp "$BAK" "$ALVO"
        hyprctl reload >/dev/null 2>&1 || true
        exit 1
    fi
fi
echo "==> hyprland.lua atualizado"
