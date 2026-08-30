#!/usr/bin/env bash
# Clona (ou atualiza) e instala hyde-widgets e hyde-ai — e o hypr-ia,
# que e o backend do hyde-ai (modelos, tools e loop agentico; o painel so
# spawna o gateway dele).
set -euo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="${HYDE_SETUP_CONF:-$BASE/setup.conf}"
# shellcheck disable=SC1090
. "$CONF"

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

if [ "${SPOTIFY_TRAY:-0}" = "1" ]; then
    waybar_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/config.jsonc"
    [ -f "$waybar_cfg" ] || {
        echo "    ERRO: configuracao ativa do Waybar nao existe: $waybar_cfg" >&2
        exit 1
    }
    grep -Fq 'group/hyde-spotify' "$waybar_cfg" || {
        echo "    ERRO: widget do Spotify nao entrou na configuracao ativa do Waybar" >&2
        exit 1
    }
    [ -x "$HOME/.local/lib/hyde-widgets/waybar-player" ] || {
        echo "    ERRO: coletor do widget Spotify nao foi instalado" >&2
        exit 1
    }
    echo "    Waybar confirmado: widget do Spotify no layout ativo"
fi

# O backend pode subir e responder ao ping sem ter um modelo configurado. A
# restauracao desta maquina so esta pronta quando o Hypr-IA aponta para o
# Ollama e para o mesmo modelo que a etapa 10 baixou.
echo "==> Hypr-IA com Ollama (${OLLAMA_MODELO})"
HPY="$HYPRIA/.venv/bin/python"
[ -x "$HPY" ] || {
    echo "    ERRO: Python do venv ausente em $HPY" >&2
    exit 1
}
HYPRIA_HOME="${HERMES_HOME:-$HOME/.hypr-ia}"
"$HPY" "$BASE/scripts/configurar-hypria-ollama.py" \
    "$HYPRIA_HOME/config.yaml" "$OLLAMA_MODELO"
ollama show "$OLLAMA_MODELO" >/dev/null || {
    echo "    ERRO: modelo $OLLAMA_MODELO nao esta disponivel no Ollama" >&2
    exit 1
}
"$HOME/.local/bin/hyde-ai" --doctor >/dev/null || {
    echo "    ERRO: hyde-ai/Hypr-IA falhou na verificacao final" >&2
    "$HOME/.local/bin/hyde-ai" --doctor >&2 || true
    exit 1
}
echo "    backend pronto: provider=ollama, model=$OLLAMA_MODELO"
