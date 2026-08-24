#!/usr/bin/env python3
"""Ponte entre os temas GTK do HyDE e o libadwaita.

O HyDE ja tema o GTK4: no theme.switch.sh ele apaga ~/.config/gtk-4.0 e
aponta um symlink para <tema>/gtk-4.0. Isso funciona porque o GTK carrega
esse gtk.css como CSS do usuario, por cima da folha de estilo ativa.

So que o libadwaita 1.6 trocou as cores nomeadas (@define-color window_bg_color)
por variaveis CSS (--window-bg-color). Os temas do HyDE sao ports antigos: so
tem as cores nomeadas. Resultado: um app libadwaita puro -- nautilus, por
exemplo -- ignora quase tudo e aparece no Adwaita padrao, destoando do resto
do desktop.

Este script refaz ~/.config/gtk-4.0 como diretorio de verdade contendo um
gtk.css que:

  1. importa o gtk.css do tema ativo (tudo que ja funcionava continua igual);
  2. declara as variaveis do libadwaita a partir das cores nomeadas do tema.

Roda como exec_command de um template wallbash em always/, ou seja, depois de
cada troca de tema ou de wallpaper -- justamente quando o HyDE acabou de
recriar o symlink. Se algum dia o script sumir, o symlink volta sozinho na
proxima troca e nada quebra: perde-se a ponte, nao o tema.
"""
import os
import re
import sys
from pathlib import Path

CONF = Path(os.environ.get("confDir") or Path.home() / ".config")
TEMAS = Path(os.environ.get("themesDir") or Path.home() / ".local/share/themes")

MARCA = "hyde-setup:gtk4-adw"

# variavel do libadwaita  ->  cores nomeadas do tema, na ordem de preferencia
MAPA = [
    ("--window-bg-color",                ["window_bg_color", "theme_bg_color"]),
    ("--window-fg-color",                ["window_fg_color", "theme_fg_color"]),
    ("--view-bg-color",                  ["view_bg_color", "theme_base_color"]),
    ("--view-fg-color",                  ["view_fg_color", "theme_text_color"]),
    ("--headerbar-bg-color",             ["headerbar_bg_color", "theme_bg_color"]),
    ("--headerbar-fg-color",             ["headerbar_fg_color", "theme_fg_color"]),
    ("--headerbar-border-color",         ["headerbar_border_color", "theme_fg_color"]),
    ("--headerbar-backdrop-color",       ["headerbar_backdrop_color", "theme_unfocused_bg_color", "theme_bg_color"]),
    ("--headerbar-shade-color",          ["headerbar_shade_color", "borders"]),
    ("--headerbar-darker-shade-color",   ["headerbar_darker_shade_color", "borders"]),
    ("--sidebar-bg-color",               ["sidebar_bg_color", "theme_bg_color"]),
    ("--sidebar-fg-color",               ["sidebar_fg_color", "theme_fg_color"]),
    ("--sidebar-backdrop-color",         ["sidebar_backdrop_color", "theme_unfocused_bg_color", "theme_bg_color"]),
    ("--sidebar-border-color",           ["sidebar_border_color", "borders"]),
    ("--sidebar-shade-color",            ["sidebar_shade_color", "borders"]),
    ("--secondary-sidebar-bg-color",     ["secondary_sidebar_bg_color", "sidebar_bg_color", "theme_bg_color"]),
    ("--secondary-sidebar-fg-color",     ["secondary_sidebar_fg_color", "sidebar_fg_color", "theme_fg_color"]),
    ("--secondary-sidebar-backdrop-color", ["secondary_sidebar_backdrop_color", "theme_unfocused_bg_color", "theme_bg_color"]),
    ("--secondary-sidebar-border-color", ["secondary_sidebar_border_color", "borders"]),
    ("--secondary-sidebar-shade-color",  ["secondary_sidebar_shade_color", "borders"]),
    ("--card-bg-color",                  ["card_bg_color", "theme_base_color"]),
    ("--card-fg-color",                  ["card_fg_color", "theme_fg_color"]),
    ("--card-shade-color",               ["card_shade_color", "borders"]),
    ("--dialog-bg-color",                ["dialog_bg_color", "theme_bg_color"]),
    ("--dialog-fg-color",                ["dialog_fg_color", "theme_fg_color"]),
    ("--popover-bg-color",               ["popover_bg_color", "theme_bg_color"]),
    ("--popover-fg-color",               ["popover_fg_color", "theme_fg_color"]),
    ("--popover-shade-color",            ["popover_shade_color", "borders"]),
    ("--thumbnail-bg-color",             ["thumbnail_bg_color", "theme_base_color"]),
    ("--thumbnail-fg-color",             ["thumbnail_fg_color", "theme_text_color"]),
    ("--shade-color",                    ["shade_color", "borders"]),
    ("--scrollbar-outline-color",        ["scrollbar_outline_color", "borders"]),
    ("--accent-bg-color",                ["accent_bg_color", "theme_selected_bg_color"]),
    ("--accent-fg-color",                ["accent_fg_color", "theme_selected_fg_color"]),
    ("--destructive-bg-color",           ["destructive_bg_color", "error_color"]),
    ("--destructive-fg-color",           ["destructive_fg_color", "theme_selected_fg_color"]),
    ("--success-bg-color",               ["success_bg_color", "success_color"]),
    ("--success-fg-color",               ["success_fg_color", "theme_selected_fg_color"]),
    ("--warning-bg-color",               ["warning_bg_color", "warning_color"]),
    ("--warning-fg-color",               ["warning_fg_color", "theme_selected_fg_color"]),
    ("--error-bg-color",                 ["error_bg_color", "error_color"]),
    ("--error-fg-color",                 ["error_fg_color", "theme_selected_fg_color"]),
]

DEFINE = re.compile(r"^\s*@define-color\s+([A-Za-z0-9_-]+)\s+(.+?);\s*$", re.M)


def ler_cores(css: Path) -> dict:
    """Le os @define-color do tema e resolve as referencias @outra-cor."""
    cores = dict(DEFINE.findall(css.read_text(encoding="utf-8", errors="replace")))
    for _ in range(6):  # cadeias de referencia sao curtas; 6 passadas sobram
        mudou = False
        for nome, valor in list(cores.items()):
            v = valor.strip()
            if v.startswith("@"):
                alvo = cores.get(v[1:].strip())
                if alvo and alvo.strip() != v:
                    cores[nome] = alvo
                    mudou = True
        if not mudou:
            break
    return cores


def tema_ativo() -> str:
    nome = os.environ.get("GTK_THEME", "").strip()
    if not nome:
        ini = CONF / "gtk-3.0/settings.ini"
        if ini.is_file():
            m = re.search(r"^gtk-theme-name\s*=\s*\"?([^\"\n]+)\"?", ini.read_text(), re.M)
            if m:
                nome = m.group(1).strip()
    if not (TEMAS / nome / "gtk-4.0/gtk.css").is_file():
        nome = "Wallbash-Gtk"
    return nome


CACHE = Path(os.environ.get("cacheDir") or Path.home() / ".cache/hyde") / "wallbash"


def materializar() -> Path:
    """~/.config/gtk-4.0 precisa ser diretorio nosso, nao o symlink do HyDE."""
    alvo = CONF / "gtk-4.0"
    if alvo.is_symlink():
        alvo.unlink()
    alvo.mkdir(parents=True, exist_ok=True)
    return alvo


def modo_macos() -> bool:
    """Folha do MacOS ja recolorida pelo wallbash, se o template estiver posto."""
    pronta = CACHE / "gtk4-macos.css"
    if not pronta.is_file():
        return False
    alvo = materializar()
    (alvo / "gtk.css").write_text(
        f"/* {MARCA} -- gerado pelo wallbash; editar aqui nao adianta.\n"
        "   Tema MacOS recolorido com a paleta do papel de parede. */\n\n"
        + pronta.read_text(encoding="utf-8"),
        encoding="utf-8")
    print(f"gtk4-adw: MacOS + wallbash -> {alvo/'gtk.css'}")
    return True


def main() -> int:
    if modo_macos():
        return 0
    nome = tema_ativo()
    origem = TEMAS / nome / "gtk-4.0/gtk.css"
    if not origem.is_file():
        print(f"gtk4-adw: tema '{nome}' sem gtk-4.0 -- nada a fazer", file=sys.stderr)
        return 0

    cores = ler_cores(origem)
    linhas = []
    for var, candidatas in MAPA:
        for c in candidatas:
            if c in cores:
                linhas.append(f"  {var}: {cores[c].strip()};")
                break

    alvo = CONF / "gtk-4.0"
    if alvo.is_symlink():
        alvo.unlink()
    alvo.mkdir(parents=True, exist_ok=True)

    css = f"""/* {MARCA} -- gerado; editar aqui nao adianta, o tema reescreve.
   Tema: {nome}
   O @import mantem tudo que o HyDE ja fazia com o symlink.
   O :root preenche as variaveis do libadwaita que este tema deixou de fora --
   sem isso elas caem no cinza do Adwaita ao lado de uma janela tematizada,
   coisa que se ve na hora na barra lateral do nautilus. */

@import url("file://{origem}");

:root {{
{chr(10).join(linhas)}
}}
"""
    (alvo / "gtk.css").write_text(css, encoding="utf-8")
    print(f"gtk4-adw: {nome} -> {alvo/'gtk.css'} ({len(linhas)} variaveis)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
