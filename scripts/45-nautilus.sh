#!/usr/bin/env bash
# Nautilus no HyDE: instala, integra e faz o tema pegar nele de verdade.
set -uo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$BASE/setup.conf"

[ "${NAUTILUS:-0}" = "1" ] || exit 0

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"

echo "==> Nautilus"
PKGS=(nautilus gvfs-mtp gvfs-gphoto2 gvfs-smb ffmpegthumbnailer)
faltando=()
for p in "${PKGS[@]}"; do pacman -Qq "$p" &>/dev/null || faltando+=("$p"); done
if [ ${#faltando[@]} -gt 0 ]; then
    echo "    instalando: ${faltando[*]}"
    sudo pacman -S --needed --noconfirm "${faltando[@]}" || {
        echo "    ERRO: instale manualmente e rode de novo" >&2; exit 1; }
fi

# Entrada "abrir no terminal" no menu de contexto. So existe no AUR, e depende
# do nautilus-python -- por isso fica atras de um if, e nao na lista acima.
if [ -n "${NAUTILUS_TERMINAL:-}" ] && command -v paru >/dev/null 2>&1; then
    pacman -Qq nautilus-open-any-terminal &>/dev/null \
        || paru -S --needed --noconfirm nautilus-open-any-terminal >/dev/null 2>&1 || true
    if pacman -Qq nautilus-open-any-terminal &>/dev/null; then
        gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal \
            "$NAUTILUS_TERMINAL" 2>/dev/null || true
        gsettings set com.github.stunkymonkey.nautilus-open-any-terminal new-tab \
            true 2>/dev/null || true
        echo "    menu de contexto abre o $NAUTILUS_TERMINAL"
    fi
fi

echo "==> Ponte GTK4 / libadwaita"
# O HyDE ja tema o GTK4: na troca de tema ele aponta ~/.config/gtk-4.0 para
# <tema>/gtk-4.0, e o GTK carrega esse gtk.css como CSS do usuario. O
# libadwaita 1.6 trocou as cores nomeadas por variaveis CSS, mas deixou uma
# camada de compatibilidade (--window-bg-color: @window_bg_color), entao o
# @define-color do tema ainda chega la: o nautilus ja nasce quase tematizado.
#
# O buraco esta nas cores que os temas nunca declararam. Dos 48 temas com
# gtk-4.0 aqui, 44 nao definem a familia @sidebar_* -- e num gerenciador de
# arquivos a barra lateral e metade da janela, que fica no cinza do Adwaita
# encostada numa janela tematizada. Metade dos temas nao define nenhuma das
# 42, e ai o app inteiro cai no padrao.
#
# O gancho abaixo roda no fim de cada troca de tema (e de wallpaper) e refaz
# ~/.config/gtk-4.0 como diretorio de verdade: importa o gtk.css do tema, do
# jeitinho que o symlink fazia, e preenche as 42 variaveis com a cor mais
# proxima que o tema tenha declarado.
mkdir -p "$CFG/hyde/wallbash/always" "$CFG/hyde/wallbash/scripts"
cp -f "$BASE/wallbash/gtk4-adw.py" "$CFG/hyde/wallbash/scripts/"
chmod +x "$CFG/hyde/wallbash/scripts/gtk4-adw.py"
cp -f "$BASE/wallbash/gtk4-adw.dcol" "$CFG/hyde/wallbash/always/"
"$CFG/hyde/wallbash/scripts/gtk4-adw.py" || true

if [ "${NAUTILUS_PADRAO:-0}" = "1" ]; then
    echo "==> Gerenciador de arquivos padrao"
    # O SUPER+E do HyDE e "hyde-shell open --fall dolphin file-manager": ele
    # abre o handler XDG de diretorio. Trocando o handler, a tecla segue junto
    # -- nao ha keybind para reescrever.
    xdg-mime default org.gnome.Nautilus.desktop inode/directory 2>/dev/null || true
    xdg-mime default org.gnome.Nautilus.desktop application/x-gnome-saved-search 2>/dev/null || true
    echo "    SUPER+E abre o $(xdg-mime query default inode/directory)"
fi

echo "==> Preferencias"
gsettings set org.gnome.nautilus.preferences show-hidden-files false 2>/dev/null || true
gsettings set org.gnome.nautilus.preferences show-delete-permanently true 2>/dev/null || true
gsettings set org.gnome.nautilus.icon-view default-zoom-level 'small' 2>/dev/null || true
# O nautilus le fonte, icones e claro/escuro do portal, que por sua vez le o
# gsettings -- nao o gtk-3.0/settings.ini que o HyDE escreve. Espelhar aqui e
# o que mantem a fonte igual a dos outros apps.
if [ -f "$CFG/gtk-3.0/settings.ini" ]; then
    ler() { sed -n "s/^$1=\"\?\([^\"]*\)\"\?$/\1/p" "$CFG/gtk-3.0/settings.ini" | head -1; }
    [ -n "$(ler gtk-font-name)" ]        && gsettings set org.gnome.desktop.interface font-name "$(ler gtk-font-name)"
    [ -n "$(ler gtk-icon-theme-name)" ]  && gsettings set org.gnome.desktop.interface icon-theme "$(ler gtk-icon-theme-name)"
    [ -n "$(ler gtk-cursor-theme-name)" ]&& gsettings set org.gnome.desktop.interface cursor-theme "$(ler gtk-cursor-theme-name)"
fi

echo "    pronto"
