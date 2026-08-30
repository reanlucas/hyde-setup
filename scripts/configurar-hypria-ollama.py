#!/usr/bin/env python3
"""Configura atomicamente o modelo Ollama padrao do Hypr-IA."""

from __future__ import annotations

import os
import stat
import sys
from pathlib import Path

import yaml


def main() -> int:
    if len(sys.argv) != 3:
        print("uso: configurar-hypria-ollama.py CONFIG_YAML MODELO", file=sys.stderr)
        return 2

    caminho = Path(sys.argv[1]).expanduser()
    modelo = sys.argv[2].strip()
    if not modelo or any(char.isspace() for char in modelo):
        print("modelo Ollama vazio ou invalido", file=sys.stderr)
        return 2

    dados = {}
    if caminho.exists():
        with caminho.open(encoding="utf-8") as arquivo:
            dados = yaml.safe_load(arquivo) or {}
    if not isinstance(dados, dict):
        print("config do Hypr-IA nao e um mapa YAML", file=sys.stderr)
        return 1

    config_modelo = dados.get("model")
    if not isinstance(config_modelo, dict):
        config_modelo = {}
        dados["model"] = config_modelo
    config_modelo.update({
        "default": modelo,
        "provider": "ollama",
        "base_url": "http://localhost:11434/v1",
        "api_key": "ollama",
    })

    caminho.parent.mkdir(parents=True, exist_ok=True)
    temporario = caminho.with_name(f".{caminho.name}.tmp.{os.getpid()}")
    with temporario.open("w", encoding="utf-8") as arquivo:
        yaml.safe_dump(dados, arquivo, sort_keys=False, allow_unicode=True)
        arquivo.flush()
        os.fsync(arquivo.fileno())
    temporario.chmod(stat.S_IRUSR | stat.S_IWUSR)
    os.replace(temporario, caminho)
    print(f"    {caminho}: ollama/{modelo}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
