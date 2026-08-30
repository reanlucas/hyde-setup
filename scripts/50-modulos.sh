#!/usr/bin/env bash
# Clona (ou atualiza) e instala hyde-widgets e hyde-ai — e o hypr-ia,
# que e o backend do hyde-ai (modelos, tools e loop agentico; o painel so
# spawna o gateway dele).
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../setup.conf"

DEST="${HYDE_SETUP_MODULOS:-$HOME/.local/src}"
mkdir -p "$DEST"
USUARIO="${HYDE_SETUP_GITHUB:-reanlucas}"

# ── hypr-ia (backend do hyde-ai) ─────────────────────────────────────────
# Base propria em cima do hermes-agent (Nous Research): o clone do upstream
# e so o bootstrap — sem pull automatico, a base local e que manda. O
# install.sh do hyde-ai cuida do venv (uv + Python 3.11), da migracao de
# ~/Projetos/hermes-agent e do plugin hypr-arch; aqui so garantimos o
# checkout e dizemos a ele onde fica.
HYPRIA="${HYPRIA_DIR:-${HERMES_DIR:-$HOME/Projetos/hypr-ia}}"
if [ ! -e "$HYPRIA" ] && [ -f "$HOME/Projetos/hermes-agent/pyproject.toml" ]; then
    echo "==> Migrando ~/Projetos/hermes-agent -> $HYPRIA"
    mv "$HOME/Projetos/hermes-agent" "$HYPRIA"
fi
if [ ! -f "$HYPRIA/pyproject.toml" ]; then
    echo "==> Clonando a base do hypr-ia"
    git clone --depth 1 https://github.com/NousResearch/hermes-agent \
        "$HYPRIA" || { echo "    ERRO: falhou o clone da base do hypr-ia" >&2; exit 1; }
else
    echo "==> hypr-ia presente em $HYPRIA"
fi
export HYDE_AI_HYPRIA_DIR="$HYPRIA"

for repo in hyde-widgets hyde-ai; do
    alvo="$DEST/$repo"
    if [ -d "$alvo/.git" ]; then
        echo "==> Atualizando $repo"
        git -C "$alvo" pull --ff-only
    else
        echo "==> Clonando $repo"
        git clone "https://github.com/$USUARIO/$repo.git" "$alvo" || {
            echo "    ERRO: falhou o clone de $repo" >&2; exit 1; }
    fi
    [ -x "$alvo/install.sh" ] || {
        echo "    ERRO: $repo nao possui install.sh executavel" >&2; exit 1; }
    "$alvo/install.sh"
done
