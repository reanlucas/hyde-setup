#!/usr/bin/env bash
# CoreCtrl e o unico controlador de perfil AMD deste setup. Ele precisa de
# amdgpu.ppfeaturemask na cmdline do kernel e deve ficar rodando na bandeja
# para que o perfil global continue aplicado durante a sessao.
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="${HYDE_SETUP_CONF:-$BASE/setup.conf}"
# shellcheck disable=SC1090
. "$CONF"

[ "${CORECTRL:-1}" = "1" ] || { echo "CORECTRL=0 -- pulando"; exit 0; }
[ "${GPU_VENDOR:-}" = "amd" ] || {
    echo "GPU_VENDOR=${GPU_VENDOR:-indefinido} -- CoreCtrl AMD nao sera configurado"
    exit 0
}

DELAY="${CORECTRL_START_DELAY:-5}"
[[ "$DELAY" =~ ^[0-9]+$ ]] || {
    echo "ERRO: CORECTRL_START_DELAY deve ser um inteiro em segundos" >&2
    exit 1
}

echo "==> CoreCtrl"
sudo pacman -S --needed --noconfirm corectrl

desativar_controladores_conflitantes() {
    # Nao removemos pacotes preexistentes: apenas deixamos de iniciar os dois
    # servicos que podem reescrever governor, clocks ou limites por baixo do
    # perfil do CoreCtrl. Em uma instalacao limpa eles simplesmente nao existem.
    local unidade
    for unidade in lactd.service power-profiles-daemon.service; do
        if systemctl list-unit-files "$unidade" --no-legend 2>/dev/null | grep -q "^$unidade"; then
            sudo systemctl disable --now "$unidade"
            echo "    $unidade desativado; CoreCtrl e o unico controlador"
        fi
    done
}

instalar_perfil() {
    [ "${CORECTRL_RESTORE_PROFILE:-1}" = "1" ] || return 0

    local origem="$BASE/profiles/corectrl/global.xml"
    local destino="${XDG_CONFIG_HOME:-$HOME/.config}/corectrl/profiles/_global_.ccpro"
    [ -f "$origem" ] || { echo "ERRO: perfil CoreCtrl ausente: $origem" >&2; return 1; }
    mkdir -p "$(dirname "$destino")"

    local atual
    atual="$(mktemp)"
    trap 'rm -f "$atual"' RETURN
    if [ -f "$destino" ] && unzip -p "$destino" profile.xml >"$atual" 2>/dev/null \
       && cmp -s "$origem" "$atual"; then
        echo "    perfil global ja corresponde a este ambiente"
        return 0
    fi

    if [ -f "$destino" ]; then
        cp -f "$destino" "$destino.bak-$(date +%Y%m%d-%H%M%S)"
        echo "    perfil global anterior preservado em backup"
    fi
    python3 - "$origem" "$destino" <<'PY'
import os
import sys
import zipfile

source, target = sys.argv[1:]
temporary = target + ".tmp"
with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED) as archive:
    archive.write(source, "profile.xml")
os.replace(temporary, target)
os.chmod(target, 0o600)
PY
    echo "    perfil global desta maquina restaurado"
}

configurar_boot() {
    local parametro="amdgpu.ppfeaturemask=0xffffffff"
    local cmdline="${CORECTRL_CMDLINE:-/etc/kernel/cmdline}"
    local mudou=0

    [ -f "$cmdline" ] || {
        echo "ERRO: cmdline UKI nao encontrada em $cmdline" >&2
        echo "      defina CORECTRL_CMDLINE para a cmdline do seu bootloader" >&2
        return 1
    }
    if grep -qw -- "$parametro" "$cmdline"; then
        echo "    $parametro ja esta na cmdline persistente"
    else
        echo "    adicionando $parametro em $cmdline"
        sudo sed -i "s/[[:space:]]*\$/ $parametro/" "$cmdline"
        mudou=1
    fi

    if [ "$mudou" -eq 1 ]; then
        command -v mkinitcpio >/dev/null 2>&1 || {
            echo "ERRO: mkinitcpio nao encontrado para regerar a UKI" >&2
            return 1
        }
        echo "    regenerando a UKI (mkinitcpio -P)"
        sudo mkinitcpio -P
    fi

    if grep -qw -- "$parametro" /proc/cmdline; then
        echo "    overdrive AMD ativo neste boot"
    else
        echo "    REINICIE para o parametro de boot entrar em vigor"
    fi
}

configurar_hyprland() {
    local alvo="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
    local ini="-- >>> hyde-setup:corectrl"
    local fim="-- <<< hyde-setup:corectrl"
    [ -f "$alvo" ] || { echo "ERRO: $alvo nao existe -- o HyDE foi instalado?" >&2; return 1; }

    python3 - "$alvo" "$ini" "$fim" "$DELAY" <<'PY'
import pathlib
import re
import sys

path, begin, end, delay = map(str, sys.argv[1:])
text = pathlib.Path(path).read_text(encoding="utf-8")
text = re.sub(re.escape(begin) + r".*?" + re.escape(end) + r"\n?", "", text, flags=re.S)
block = f'''{begin}
-- Gerado por hyde-setup (etapa 60). CoreCtrl e o unico controlador AMD.
-- O perfil so permanece aplicado enquanto o processo esta vivo; por isso ele
-- inicia na bandeja depois que a tray da waybar esta disponivel.
hl.window_rule({{
    name   = "corectrl",
    match  = {{ class = [[^(corectrl)$]] }},
    float  = true,
    center = true,
    size   = "1100 880",
}})

-- hyprland.lua pode ser avaliado duas vezes pelo proprio HyDE. O guard evita
-- registrar dois handlers de inicio e o pgrep evita uma segunda instancia.
if not _G.__corectrl_autostart then
    _G.__corectrl_autostart = true
    hl.on("hyprland.start", function()
        hl.exec_cmd([[sh -c 'sleep {delay}; pgrep -x corectrl >/dev/null || exec corectrl --minimize-systray']])
    end)
end
{end}
'''
pathlib.Path(path).write_text(text.rstrip() + "\n\n" + block, encoding="utf-8")
PY
    command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true
    echo "    autostart do CoreCtrl configurado no Hyprland"
}

desativar_controladores_conflitantes
instalar_perfil
configurar_boot
configurar_hyprland
