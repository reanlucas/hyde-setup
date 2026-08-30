#!/usr/bin/env bash
# Fuso horario e sincronizacao automatica do relogio do sistema.
set -euo pipefail
CONF="${HYDE_SETUP_CONF:-$(dirname "${BASH_SOURCE[0]}")/../setup.conf}"
# shellcheck disable=SC1090
. "$CONF"

FUSO="${TIMEZONE:-America/Sao_Paulo}"
command -v timedatectl >/dev/null 2>&1 || {
    echo "ERRO: timedatectl nao encontrado" >&2
    exit 1
}

# Recusa erro de digitacao antes de alterar /etc/localtime.
timedatectl list-timezones | grep -Fxq "$FUSO" || {
    echo "ERRO: fuso horario invalido: $FUSO" >&2
    exit 1
}

ATUAL="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
if [ "$ATUAL" != "$FUSO" ]; then
    sudo timedatectl set-timezone "$FUSO"
    echo "==> Fuso horario: $FUSO"
else
    echo "==> Fuso horario ja configurado: $FUSO"
fi

sudo timedatectl set-ntp true
echo "    sincronizacao NTP ativada"
