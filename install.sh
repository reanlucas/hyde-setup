#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────
#  hyde-setup -- pos-instalacao pessoal do HyDE.
#
#  Ciclo:  Arch minimal  ->  HyDE  ->  este script
#
#  Idempotente: rodar de novo reaplica sem duplicar. Cada etapa vive em
#  scripts/, e da para rodar uma isolada passando o numero:
#      ./install.sh 20
# ─────────────────────────────────────────────────────────────────────────
set -uo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE"

if [ ! -f setup.conf ]; then
    cp setup.conf.example setup.conf
    echo "setup.conf criado a partir do exemplo."
    echo "Revise-o (monitor, teclado, GPU) e rode de novo:"
    echo "    \$EDITOR $BASE/setup.conf && $BASE/install.sh"
    exit 0
fi

# shellcheck disable=SC1091
if ! . ./setup.conf; then
    echo "setup.conf invalido; corrija-o antes de instalar." >&2
    exit 1
fi

command -v hyprctl >/dev/null || { echo "Hyprland nao encontrado." >&2; exit 1; }
[ -d "$HOME/.config/hypr" ] || { echo "HyDE nao instalado." >&2; exit 1; }

echo "Mantendo o sudo vivo durante a instalacao."
sudo -v || exit 1
( while true; do sudo -n true; sleep 50; done ) 2>/dev/null &
KEEP=$!; trap 'kill $KEEP 2>/dev/null' EXIT

filtro="${1:-}"
falhou=0
for etapa in scripts/*.sh; do
    nome="$(basename "$etapa")"
    [ -n "$filtro" ] && [[ "$nome" != "$filtro"* ]] && continue
    echo
    echo "════ $nome ════"
    if ! bash "$etapa"; then
        echo "  (etapa $nome terminou com erro)" >&2
        falhou=1
        break
    fi
done

if [ "$falhou" -ne 0 ]; then
    echo
    echo "════ Instalacao incompleta ════" >&2
    echo "  Corrija as etapas que falharam e rode $BASE/install.sh novamente." >&2
    exit 1
fi

echo
echo "════ Pronto ════"
echo "  hyde-widgets --show     widgets do desktop"
echo "  hyde-spotify --show     mostra o Spotify guardado no scratchpad"
echo "  hyde-ai --doctor        confirma o backend Hypr-IA + Ollama"
echo "                          (outros provedores: /key no painel)"
echo "  ${HYDEAI_TECLA1}  abre o chat   ·   ${WIDGETS_TECLA}  alterna os widgets"
