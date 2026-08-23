#!/usr/bin/env bash
# Clona (ou atualiza) e instala hyde-widgets e hyde-ai.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../setup.conf"

DEST="${HYDE_SETUP_MODULOS:-$HOME/.local/src}"
mkdir -p "$DEST"
USUARIO="${HYDE_SETUP_GITHUB:-reanlucas}"

for repo in hyde-widgets hyde-ai; do
    alvo="$DEST/$repo"
    if [ -d "$alvo/.git" ]; then
        echo "==> Atualizando $repo"
        git -C "$alvo" pull --ff-only || true
    else
        echo "==> Clonando $repo"
        git clone "https://github.com/$USUARIO/$repo.git" "$alvo" || {
            echo "    falhou o clone de $repo" >&2; continue; }
    fi
    [ -x "$alvo/install.sh" ] && "$alvo/install.sh"
done
