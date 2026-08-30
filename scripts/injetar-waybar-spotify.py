#!/usr/bin/env python3
"""Injeta os modulos do hyde-widgets em um config ativo do Waybar."""

import importlib.util
import json
import os
import sys
import tempfile


def main():
    instalador, caminho = sys.argv[1:]
    spec = importlib.util.spec_from_file_location("hyde_widgets_waybar", instalador)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    cfg = mod.carregar(caminho)
    widgets = mod.carregar(mod.MODULOS)
    widgets = json.loads(json.dumps(widgets).replace("$HOME", mod.CASA))
    if not mod.injetar(cfg, widgets):
        raise SystemExit("config ativo nao possui uma lista modules-* valida")

    diretorio = os.path.dirname(caminho)
    fd, temporario = tempfile.mkstemp(
        prefix=".config.jsonc.", dir=diretorio, text=True
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as arquivo:
            json.dump(cfg, arquivo, indent=2, ensure_ascii=False)
            arquivo.write("\n")
        os.replace(temporario, caminho)
    except BaseException:
        try:
            os.unlink(temporario)
        except FileNotFoundError:
            pass
        raise


if __name__ == "__main__":
    main()
