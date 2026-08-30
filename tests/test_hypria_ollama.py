#!/usr/bin/env python3
"""Confere a configuracao idempotente do Hypr-IA para Ollama."""

import os
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml


def main():
    root = Path(__file__).resolve().parents[1]
    helper = root / "scripts" / "configurar-hypria-ollama.py"
    with tempfile.TemporaryDirectory() as temporary:
        config = Path(temporary) / "state" / "config.yaml"
        config.parent.mkdir()
        config.write_text(
            "plugins:\n  enabled:\n    - hypr-arch\nmodel:\n  default: antigo\n",
            encoding="utf-8",
        )
        for _ in range(2):
            subprocess.run([sys.executable, str(helper), str(config), "qwen3.5:9b"],
                           check=True)

        data = yaml.safe_load(config.read_text(encoding="utf-8"))
        assert data["plugins"]["enabled"] == ["hypr-arch"]
        assert data["model"] == {
            "default": "qwen3.5:9b",
            "provider": "ollama",
            "base_url": "http://localhost:11434/v1",
            "api_key": "ollama",
        }
        assert os.stat(config).st_mode & 0o777 == 0o600

    print("ok: Hypr-IA Ollama config")


if __name__ == "__main__":
    main()
