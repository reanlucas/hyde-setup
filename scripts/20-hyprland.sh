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
BAK="$ALVO.bak-$(date +%Y%m%d-%H%M%S)-$$"
TMP="$(mktemp "${ALVO}.hyde-setup.XXXXXX")"
trap 'rm -f "$TMP"' EXIT
cp -p "$ALVO" "$BAK"
cp -p "$ALVO" "$TMP"

validar_lua() {
    if command -v luac >/dev/null 2>&1; then
        luac -p "$1"
    elif command -v lua >/dev/null 2>&1; then
        lua - "$1" <<'LUA'
assert(loadfile(arg[1]))
LUA
    else
        echo "ERRO: lua/luac nao encontrado; nao e seguro alterar o Hyprland" >&2
        return 1
    fi
}

remover_bloco_gerenciado() {
    python3 - "$1" "$INI" "$FIM" <<'PY'
import re
import sys

alvo, ini, fim = sys.argv[1], sys.argv[2], sys.argv[3]
with open(alvo, encoding="utf-8") as arquivo:
    conteudo = arquivo.read()
conteudo = re.sub(
    re.escape(ini) + r".*?" + re.escape(fim) + r"\n?",
    "",
    conteudo,
    flags=re.S,
)
with open(alvo, "w", encoding="utf-8") as arquivo:
    arquivo.write(conteudo.rstrip() + "\n")
PY
}

restaurar_base_hyde() {
    local modelo="${HYDE_DIR:-$HOME/HyDE}/Configs/.config/hypr/hyprland.lua"
    if [ -f "$modelo" ] && validar_lua "$modelo" >/dev/null 2>&1; then
        cp "$modelo" "$TMP"
        return 0
    fi

    # Fallback equivalente ao entrypoint oficial da migracao Lua do HyDE. Ele
    # deixa o desktop carregavel mesmo se o checkout nao estiver disponivel.
    cat >"$TMP" <<'LUA'
-- Hyprland loads this file as the user override and entry point for HyDE.
if not hyde then
    local share = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
    local entry = share .. "/hypr/hyde.lua"
    local handle = io.open(entry, "r")
    if not handle then
        error("HyDE is not installed at " .. entry .. ". Run install.sh -r.")
    end
    handle:close()
    dofile(entry)
end

-- User overrides are managed below by hyde-setup.
LUA
}

# setup.conf e shell, mas o destino e Lua. Nunca interpole valores textuais
# diretamente no codigo: uma aspa em nome de monitor, tecla ou variante pode
# fechar a string e transformar o restante em Lua invalido (ou em codigo).
lua_quote() {
    python3 - "$1" <<'PY'
import json
import sys

# JSON usa o mesmo escape basico de strings que Lua e ensure_ascii evita \uXXXX,
# que nao e uma sequencia Lua valida para caracteres UTF-8 comuns.
print(json.dumps(sys.argv[1], ensure_ascii=False))
PY
}
numero() {
    local nome="$1" valor="$2"
    [[ "$valor" =~ ^[0-9]+([.][0-9]+)?$ ]] || {
        echo "ERRO: $nome deve ser numerico (recebido: $valor)" >&2
        return 1
    }
}

MONITOR_SAIDA_LUA="$(lua_quote "$MONITOR_SAIDA")"
MONITOR_MODO_LUA="$(lua_quote "$MONITOR_MODO")"
MONITOR_POSICAO_LUA="$(lua_quote "$MONITOR_POSICAO")"
MONITOR_CM_LUA="$(lua_quote "$MONITOR_CM")"
KB_LAYOUT_LUA="$(lua_quote "$KB_LAYOUT")"
KB_VARIANT_LUA="$(lua_quote "$KB_VARIANT")"
HYDEAI_TECLA1_LUA="$(lua_quote "${HYDEAI_TECLA1/, / + }")"
HYDEAI_TECLA2_LUA="$(lua_quote "${HYDEAI_TECLA2/, / + }")"
WIDGETS_TECLA_LUA="$(lua_quote "${WIDGETS_TECLA/, / + }")"
FULLSCREEN_TECLA_LUA="$(lua_quote "${FULLSCREEN_TECLA/, / + }")"
if ! numero MONITOR_ESCALA "$MONITOR_ESCALA" \
   || ! numero MONITOR_BITDEPTH "$MONITOR_BITDEPTH"; then
    cp "$BAK" "$ALVO"
    exit 1
fi
MONITOR_ESCALA_LUA="$MONITOR_ESCALA"
MONITOR_BITDEPTH_LUA="$MONITOR_BITDEPTH"

# Retira primeiro qualquer bloco antigo. Se isso curar o arquivo, preservamos
# todo o restante. Se a base continuar invalida (o caso observado na maquina
# nova), guardamos o original em BAK e partimos do entrypoint oficial do HyDE.
remover_bloco_gerenciado "$TMP"
if ! validar_lua "$TMP" >/dev/null 2>&1; then
    echo "AVISO: hyprland.lua anterior ja era invalido; preservado em $BAK" >&2
    restaurar_base_hyde
fi
if ! validar_lua "$TMP" >/dev/null 2>&1; then
    echo "ERRO: nao foi possivel recuperar uma base Lua valida" >&2
    exit 1
fi

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

cat >> "$TMP" <<LUA

$INI
-- Gerado por hyde-setup. Editar setup.conf e rodar de novo reescreve isto.

hl.monitor({
    output   = ${MONITOR_SAIDA_LUA},
    mode     = ${MONITOR_MODO_LUA},
    position = ${MONITOR_POSICAO_LUA},
    scale    = ${MONITOR_ESCALA_LUA},
    bitdepth = ${MONITOR_BITDEPTH_LUA},
    cm       = ${MONITOR_CM_LUA},
})

hl.config({
    input = {
        kb_layout  = ${KB_LAYOUT_LUA},
        kb_variant = ${KB_VARIANT_LUA},
    },
})

hl.bind(${HYDEAI_TECLA1_LUA}, hl.dsp.exec_cmd("\$HOME/.local/bin/hyde-ai --toggle"), {
    description = "[Launcher|Apps] AI sidebar",
})
hl.bind(${HYDEAI_TECLA2_LUA}, hl.dsp.exec_cmd("\$HOME/.local/bin/hyde-ai --toggle"), {
    description = "[Launcher|Apps] AI sidebar",
})
hl.bind(${WIDGETS_TECLA_LUA}, hl.dsp.exec_cmd("\$HOME/.local/bin/hyde-widgets --toggle"), {
    description = "[Launcher|Apps] widgets do desktop",
})

-- Vidro real nas superficies dos widgets
hl.layer_rule({ "blur", "ignorealpha 0.2" }, "hyde-widgets")

-- O bind do HyDE cicla tres estados: 0 -> 1 (maximizar) -> 2 (fullscreen).
-- Num layout de tiles o estado 1 e visualmente identico a janela ja
-- ladrilhada, entao a primeira tecla nao muda nada na tela e o atalho parece
-- quebrado -- so na segunda vem o fullscreen. Aqui vira alternancia direta.
hl.bind(${FULLSCREEN_TECLA_LUA}, hl.dsp.window.fullscreen(), {
    description = "[Window Management] toggle fullscreen",
})
${SPOTIFY_LUA}
hl.on("hyprland.start", function()
    hl.exec_cmd("\$HOME/.local/bin/hyde-widgets --show")
    hl.exec_cmd("\$HOME/.local/bin/hyde-ai --daemon")${SPOTIFY_EXEC}
end)
$FIM
LUA

if ! validar_lua "$TMP"; then
    echo "ERRO: o bloco gerado nao e Lua valido; original mantido em $ALVO" >&2
    exit 1
fi
cp "$TMP" "$ALVO"
if command -v hyprctl >/dev/null 2>&1; then
    if ! hyprctl reload >/dev/null 2>&1; then
        echo "ERRO: o Hyprland nao conseguiu recarregar; restaurando $BAK" >&2
        cp "$BAK" "$ALVO"
        hyprctl reload >/dev/null 2>&1 || true
        exit 1
    fi
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
