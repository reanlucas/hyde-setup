#!/usr/bin/env bash
# Jogos: faz o borderless se comportar como fullscreen exclusivo.
#
# Em Wayland nao existe fullscreen exclusivo para um cliente X: o CS2 roda em
# XWayland (o launcher da Valve, game/cs2.sh, forca SDL_VIDEO_DRIVER=x11) e
# XWayland nao troca modo de video -- o proprio xrandr avisa isso. Sem modeset
# nao ha o que "exclusivo" signifique, e o menu do jogo fica so com Windowed e
# Fullscreen Windowed.
#
# O que da para recuperar e o efeito: janela em fullscreen de verdade, sem
# barra por cima, com direct scanout e tearing liberado. Quem faz isso e o
# compositor, nao o jogo.
set -uo pipefail
CONF="${HYDE_SETUP_CONF:-$(dirname "${BASH_SOURCE[0]}")/../setup.conf}"
# shellcheck disable=SC1090
if ! . "$CONF"; then
    echo "ERRO: nao foi possivel ler $CONF" >&2
    exit 1
fi

[ "${JOGOS:-1}" = "1" ] || { echo "==> JOGOS=0, nada a fazer"; exit 0; }

ALVO="$HOME/.config/hypr/hyprland.lua"
[ -f "$ALVO" ] || { echo "$ALVO nao existe -- o HyDE foi instalado?" >&2; exit 1; }
BAK="$ALVO.bak-jogos-$(date +%Y%m%d-%H%M%S)"
cp "$ALVO" "$BAK"

python3 - "$ALVO" \
    "${JOGOS_CLASSES:-cs2}" \
    "${JOGOS_FULLSCREEN:-1}" \
    "${JOGOS_TEARING:-1}" <<'PYLUA'
import re, sys, pathlib

p, classes, tela, tearing = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
s = re.sub(r"-- >>> hyde-setup:jogos.*?-- <<< hyde-setup:jogos\n?", "",
           p.read_text(encoding="utf-8"), flags=re.S)

cfg = 'hl.config({ general = { allow_tearing = true } })\n\n' if tearing == "1" else ""

campos = [
    ('name',  '"jogos"'),
    ('match', '{ class = [[^(%s)$]] }' % classes),
]
if tela == "1":
    campos.append(("fullscreen", "true"))
campos.append(("content", '"game"'))
if tearing == "1":
    campos.append(("immediate", "true"))
campos += [
    ("idle_inhibit", '"fullscreen"'),
    ("no_blur",   "true"),
    ("no_anim",   "true"),
    ("no_shadow", "true"),
    ("no_dim",    "true"),
    ("rounding",     "0"),
    ("border_size",  "0"),
]
larg = max(len(k) for k, _ in campos)
corpo = "\n".join("    %-*s = %s," % (larg, k, v) for k, v in campos)

bloco = """-- >>> hyde-setup:jogos
-- Gerado por hyde-setup (etapa 65). Editar setup.conf e rodar de novo reescreve.
--
-- Nao existe fullscreen exclusivo para um cliente X em Wayland: o CS2 forca
-- SDL_VIDEO_DRIVER=x11 no proprio launcher, e XWayland nao troca modo de
-- video. O menu do jogo fica so com Windowed e Fullscreen Windowed -- e o
-- Fullscreen Windowed e o modo certo aqui.
--
-- O que falta e o borderless render igual ao exclusivo. Com a janela em
-- fullscreen e sozinha na workspace, o Hyprland faz direct scanout: o buffer
-- do jogo vai direto para a tela, sem passar pelo compositor.
--
-- content = "game" marca o tipo de conteudo; immediate libera tearing (vsync
-- off de verdade, que e o ponto num painel de alta taxa) e so funciona porque
-- general.allow_tearing esta ligado logo acima.
--
-- idle_inhibit = "fullscreen" cobre a lacuna da etapa 55: com a tela apagando
-- por inatividade, um round parado no bombsite apagaria o monitor.

%shl.window_rule({
%s
})
-- <<< hyde-setup:jogos
""" % (cfg, corpo)

p.write_text(s.rstrip() + "\n\n" + bloco, encoding="utf-8")
PYLUA

# O Hyprland rejeita o arquivo inteiro quando o Lua nao compila -- e ai vao
# junto todos os binds do usuario. Validar antes da recarga atribui o erro a
# etapa que o produziu; sem isso um configerror antigo parecia ser do jogo.
if command -v luac >/dev/null 2>&1 && ! luac -p "$ALVO"; then
    echo "!!  o bloco de jogos nao e Lua valido -- restaurando $BAK" >&2
    cp "$BAK" "$ALVO"
    exit 1
fi

# Se a sintaxe passou mas o Hyprland rejeitar uma chave da DSL, volta o backup.
hyprctl reload >/dev/null 2>&1 || true
sleep 1
ERROS="$(hyprctl configerrors 2>/dev/null | tr -d '[:space:]')"
if [ -n "$ERROS" ]; then
    echo "!!  o Hyprland recusou o bloco -- restaurando $BAK" >&2
    hyprctl configerrors >&2
    cp "$BAK" "$ALVO"
    hyprctl reload >/dev/null 2>&1 || true
    exit 1
fi

echo "==> Regra de jogo aplicada para: ${JOGOS_CLASSES:-cs2}"
[ "${JOGOS_TEARING:-1}" = "1" ] && echo "    tearing liberado (allow_tearing + immediate)"
echo "    no jogo, deixe o Display Mode em Fullscreen Windowed"
