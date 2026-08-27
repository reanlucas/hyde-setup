#!/usr/bin/env bash
# Clona (ou atualiza) e instala hyde-widgets e hyde-ai — e o hermes-agent,
# que e o backend do hyde-ai (modelos, tools e loop agentico; o painel so
# spawna o gateway dele).
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../setup.conf"

DEST="${HYDE_SETUP_MODULOS:-$HOME/.local/src}"
mkdir -p "$DEST"
USUARIO="${HYDE_SETUP_GITHUB:-reanlucas}"

# ── hermes-agent (backend do hyde-ai) ────────────────────────────────────
# O install.sh do hyde-ai cuida do venv (uv + Python 3.11); aqui so
# garantimos o checkout e dizemos a ele onde fica.
HERMES="${HERMES_DIR:-$HOME/Projetos/hermes-agent}"
if [ -d "$HERMES/.git" ]; then
    echo "==> Atualizando hermes-agent"
    git -C "$HERMES" pull --ff-only || true
elif [ ! -f "$HERMES/pyproject.toml" ]; then
    echo "==> Clonando hermes-agent"
    git clone --depth 1 https://github.com/NousResearch/hermes-agent \
        "$HERMES" || echo "    falhou o clone do hermes-agent" >&2
fi
export HYDE_AI_HERMES_DIR="$HERMES"

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
