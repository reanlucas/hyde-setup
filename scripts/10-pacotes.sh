#!/usr/bin/env bash
# Pacotes: extras do HyDE, ferramentas e o stack de LLM local.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../setup.conf"

echo "==> Rede: forca https no lugar de http"
# Alguns PKGBUILDs clonam por http://, que e bloqueado em varias redes
# corporativas e trava o paru sem mensagem de erro.
git config --global url."https://github.com/".insteadOf "http://github.com/"

echo "==> Extras do HyDE"
if [ -f "$HOME/HyDE/Scripts/pkg_extra.lst" ]; then
    "$HOME/HyDE/Scripts/install_pkg.sh" "$HOME/HyDE/Scripts/pkg_extra.lst" || true
else
    echo "    HyDE nao encontrado em ~/HyDE -- pulando os extras"
fi

echo "==> Ferramentas"
sudo pacman -S --needed --noconfirm \
    ddcutil lm_sensors playerctl cava jq socat github-cli || true

echo "==> LLM local ($OLLAMA_PACOTE)"
sudo pacman -S --needed --noconfirm "$OLLAMA_PACOTE" aichat gemini-cli || true
sudo systemctl enable --now ollama

echo "==> Ajuste do ollama para a GPU"
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/gpu-tuning.conf >/dev/null <<CONF
[Service]
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_KV_CACHE_TYPE=q8_0"
Environment="OLLAMA_CONTEXT_LENGTH=${OLLAMA_CONTEXTO}"
Environment="OLLAMA_KEEP_ALIVE=${OLLAMA_KEEP_ALIVE}"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_GPU_OVERHEAD=0"
CONF
sudo systemctl daemon-reload
sudo systemctl restart ollama

echo "==> Modelo ${OLLAMA_MODELO}"
for _ in $(seq 1 30); do            # o daemon leva alguns segundos
    curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && break
    sleep 1
done
ollama pull "$OLLAMA_MODELO" || echo "    falhou; rode depois: ollama pull $OLLAMA_MODELO"
