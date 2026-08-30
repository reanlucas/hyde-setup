#!/usr/bin/env python3
"""Ajusta configs do Waybar usados pelo seletor de layouts do HyDE."""

import importlib.util
import json
import os
import sys
import tempfile


def remover_titulo_janela(valor):
    """Remove o modulo que repete o titulo da janela ativa na barra."""
    if isinstance(valor, list):
        valor[:] = [item for item in valor if item != "hyprland/window"]
        for item in valor:
            remover_titulo_janela(item)
    elif isinstance(valor, dict):
        valor.pop("hyprland/window", None)
        for item in valor.values():
            remover_titulo_janela(item)


def salvar(caminho, cfg):
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


def configs(alvos):
    vistos = set()
    for alvo in alvos:
        if os.path.isdir(alvo):
            for raiz, _dirs, arquivos in os.walk(alvo):
                for nome in arquivos:
                    if nome.endswith((".json", ".jsonc")):
                        caminho = os.path.join(raiz, nome)
                        if caminho not in vistos:
                            vistos.add(caminho)
                            yield caminho
        elif os.path.isfile(alvo) and alvo not in vistos:
            vistos.add(alvo)
            yield alvo


def main():
    instalador, *alvos = sys.argv[1:]
    spec = importlib.util.spec_from_file_location("hyde_widgets_waybar", instalador)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    widgets = mod.carregar(mod.MODULOS)
    widgets = json.loads(json.dumps(widgets).replace("$HOME", mod.CASA))

    feitos = 0
    for caminho in configs(alvos):
        try:
            cfg = mod.carregar(caminho)
        except Exception as exc:
            print(f"  waybar: {caminho} nao pode ser lido ({exc})", file=sys.stderr)
            continue
        if not mod.injetar(cfg, widgets):
            print(f"  waybar: {caminho} nao possui modules-*", file=sys.stderr)
            continue
        remover_titulo_janela(cfg)
        salvar(caminho, cfg)
        feitos += 1
    if not feitos:
        raise SystemExit("nenhum config do Waybar foi ajustado")
    print(f"  waybar: Spotify fixo e titulo removido em {feitos} config(s)")


if __name__ == "__main__":
    main()
