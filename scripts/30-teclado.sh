#!/usr/bin/env bash
# Cedilha no ' + c. O layout em si e aplicado em 20-hyprland.sh.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../setup.conf"

[ "${KB_CEDILHA_COMPOSE:-0}" = "1" ] || { echo "==> XCompose desativado"; exit 0; }

if [ "$KB_VARIANT" != "intl" ]; then
    echo "==> KB_VARIANT=$KB_VARIANT: a cedilha nativa e AltGr + , -- XCompose dispensado"
    exit 0
fi

cat > "$HOME/.XCompose" <<'COMPOSE'
# Cedilha ao digitar  '  seguido de  c.
# O mapa padrao do xkb produz "c com acento agudo", letra inexistente em
# portugues; a cedilha fica so no dead_cedilla, fora de alcance pratico.
include "%L"

<dead_acute> <c> : "ç" ccedilla
<dead_acute> <C> : "Ç" Ccedilla
COMPOSE
echo "==> ~/.XCompose instalado (aplicativos leem no arranque -- reabra-os)"
