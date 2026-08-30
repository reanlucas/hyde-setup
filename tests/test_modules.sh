#!/usr/bin/env bash
# Exercita a etapa 50 ate a verificacao final do Hypr-IA/Ollama.
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin" "$WORK/home/.local/bin" "$WORK/src" \
    "$WORK/hypr-ia/.venv/bin"
cat >"$WORK/setup.conf" <<EOF
HYPRIA_DIR="$WORK/hypr-ia"
OLLAMA_MODELO="qwen3.5:9b"
SPOTIFY_TRAY=1
EOF
printf '[project]\nname="hypr-ia-test"\n' >"$WORK/hypr-ia/pyproject.toml"
ln -s "$(command -v python3)" "$WORK/hypr-ia/.venv/bin/python"

for repo in hyde-widgets hyde-ai; do
    mkdir -p "$WORK/src/$repo/.git"
    cat >"$WORK/src/$repo/install.sh" <<EOF
#!/usr/bin/env bash
printf 'install $repo\n' >>"\$MODULE_TEST_LOG"
if [ "$repo" = "hyde-widgets" ]; then
    mkdir -p "\${XDG_CONFIG_HOME:-\$HOME/.config}/waybar" \
        "\$HOME/.local/lib/hyde-widgets"
    printf '{"modules-center":[]}\n' \
        >"\${XDG_CONFIG_HOME:-\$HOME/.config}/waybar/config.jsonc"
    touch "\$HOME/.local/lib/hyde-widgets/waybar-player"
    chmod +x "\$HOME/.local/lib/hyde-widgets/waybar-player"
fi
EOF
    chmod +x "$WORK/src/$repo/install.sh"
done

mkdir -p "$WORK/src/hyde-widgets/waybar"
cat >"$WORK/src/hyde-widgets/waybar/instalar.py" <<'PY'
import json, os
CASA = os.path.expanduser("~")
MODULOS = os.path.join(os.path.dirname(__file__), "modules.json")
def carregar(caminho):
    with open(caminho, encoding="utf-8") as arquivo:
        return json.load(arquivo)
def injetar(cfg, modulos):
    cfg.update(modulos)
    cfg["modules-center"].append("group/hyde-spotify")
    return True
PY
printf '{"group/hyde-spotify":{"modules":[]}}\n' \
    >"$WORK/src/hyde-widgets/waybar/modules.json"

cat >"$WORK/home/.local/bin/hyde-ai" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "--doctor" ]
grep -Fq 'provider: ollama' "$HOME/.hypr-ia/config.yaml"
grep -Fq 'default: qwen3.5:9b' "$HOME/.hypr-ia/config.yaml"
EOF
cat >"$WORK/bin/git" <<'EOF'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >>"$MODULE_TEST_LOG"
exit 0
EOF
cat >"$WORK/bin/ollama" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "show" ] && [ "$2" = "qwen3.5:9b" ]
EOF
chmod +x "$WORK/home/.local/bin/hyde-ai" "$WORK/bin/"*

HOME="$WORK/home" \
XDG_CONFIG_HOME="$WORK/home/.config" \
HYDE_SETUP_CONF="$WORK/setup.conf" \
HYDE_SETUP_MODULOS="$WORK/src" \
MODULE_TEST_LOG="$WORK/calls.log" \
PATH="$WORK/bin:$PATH" \
bash "$BASE/scripts/50-modulos.sh"

grep -Fq 'install hyde-widgets' "$WORK/calls.log"
grep -Fq 'install hyde-ai' "$WORK/calls.log"
grep -Fq 'provider: ollama' "$WORK/home/.hypr-ia/config.yaml"
grep -Fq 'default: qwen3.5:9b' "$WORK/home/.hypr-ia/config.yaml"
grep -Fq 'group/hyde-spotify' "$WORK/home/.config/waybar/config.jsonc"

printf 'ok: modules + Hypr-IA/Ollama\n'
