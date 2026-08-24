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

echo "==> Tema GTK4"
# O HyDE ja tema o GTK4: na troca de tema ele aponta ~/.config/gtk-4.0 para
# <tema>/gtk-4.0, e o GTK carrega esse gtk.css como CSS do usuario. O
# libadwaita 1.6 trocou as cores nomeadas por variaveis CSS mas deixou uma
# camada de compatibilidade (--window-bg-color: @window_bg_color), entao o
# @define-color do tema ainda chega la.
#
# Duas coisas nao chegam:
#
#   1. as cores que os temas nunca declararam. Dos 48 temas com gtk-4.0, 44
#      nao definem a familia @sidebar_* -- e num gerenciador de arquivos a
#      lateral e metade da janela;
#   2. a forma. Nenhum tema do HyDE tem o painel lateral destacado do conteudo
#      que caracteriza o Finder.
#
# Com NAUTILUS_MACOS=1 a gente reescreve o tema MacOS (que tem a forma) trocando
# as 1203 cores cravadas dele por tokens do wallbash, e entrega isso como um
# template em always/ -- o HyDE re-renderiza a cada troca de tema. Sem ele,
# cai no modo simples: importa o tema ativo e so preenche as 42 variaveis.
mkdir -p "$CFG/hyde/wallbash/always" "$CFG/hyde/wallbash/scripts"
cp -f "$BASE/wallbash/gtk4-adw.py" "$CFG/hyde/wallbash/scripts/"
chmod +x "$CFG/hyde/wallbash/scripts/gtk4-adw.py"

TEMA_MACOS="${XDG_DATA_HOME:-$HOME/.local/share}/themes/MacOS"
if [ "${NAUTILUS_MACOS:-0}" = "1" ] && [ -f "$TEMA_MACOS/gtk-4.0/gtk.gresource" ]; then
    python3 "$BASE/wallbash/gerar-macos-dcol.py" \
        --tema "$TEMA_MACOS" \
        --alpha-janela "${NAUTILUS_ALPHA_JANELA:-0.88}" \
        --alpha-lateral "${NAUTILUS_ALPHA_LATERAL:-0.62}" \
        --saida "$CFG/hyde/wallbash/always/gtk4-macos.dcol" \
        && rm -f "$CFG/hyde/wallbash/always/gtk4-adw.dcol"
else
    [ "${NAUTILUS_MACOS:-0}" = "1" ] \
        && echo "    tema MacOS nao encontrado -- usando o modo simples"
    cp -f "$BASE/wallbash/gtk4-adw.dcol" "$CFG/hyde/wallbash/always/"
    rm -f "$CFG/hyde/wallbash/always/gtk4-macos.dcol"
fi
hyde-shell reload >/dev/null 2>&1 || true
"$CFG/hyde/wallbash/scripts/gtk4-adw.py" || true

if [ "${NAUTILUS_FLOAT:-0}" = "1" ]; then
    echo "==> Janela flutuante"
    # O HyDE ja faz o gerenciador de arquivos flutuar: "org.kde.dolphin" esta
    # na lista de classes flutuantes dele. Isto so da ao nautilus o mesmo
    # tratamento, num bloco proprio para nao depender da etapa 20.
    LUA="$HOME/.config/hypr/hyprland.lua"
    if [ -f "$LUA" ]; then
        python3 - "$LUA" "${NAUTILUS_OPACIDADE:-0.82}" <<'PYLUA'
import re, sys, pathlib
p, op = pathlib.Path(sys.argv[1]), sys.argv[2]
s = re.sub(r"-- >>> hyde-setup:nautilus.*?-- <<< hyde-setup:nautilus\n?", "",
           p.read_text(encoding="utf-8"), flags=re.S)
bloco = """-- >>> hyde-setup:nautilus
-- O HyDE tem uma regra "filemanagers-fullscreen" que casa com .*Nautilus.* e
-- marca opaque = true, o que faz o Hyprland pular opacidade E blur nesta
-- janela. Enquanto isso valer, nenhuma transparencia aparece -- nem do
-- compositor, nem alfa no CSS. Desligar o opaque e o que destrava.
--
-- float pelo mesmo motivo: a regra do HyDE tambem forca float = false. O
-- dolphin escapa porque esta na lista de classes flutuantes dela.
--
-- Sem "size": o nautilus lembra o proprio tamanho.
hl.window_rule({
    name    = "nautilus-flutuante",
    match   = { class = [[^(org\\.gnome\\.Nautilus)$]] },
    float   = true,
    center  = true,
    opaque  = false,
    opacity = %s,
})
-- <<< hyde-setup:nautilus
""" % op
p.write_text(s.rstrip() + "\n\n" + bloco, encoding="utf-8")
PYLUA
        hyprctl reload >/dev/null 2>&1 || true
    fi
fi

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
