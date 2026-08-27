#!/usr/bin/env bash
# GPU AMD: instala o LACT (controle de tensao, clock, power limit e fan)
# e libera o overdrive do driver amdgpu para o controle de tensao valer.
# So faz algo quando ha GPU AMD; desligue com GPU_LACT="0" no setup.conf.
set -uo pipefail
CONF="$(dirname "${BASH_SOURCE[0]}")/../setup.conf"
[ -f "$CONF" ] && . "$CONF"

[ "${GPU_LACT:-1}" = "0" ] && { echo "GPU_LACT=0 -- pulando"; exit 0; }

# grep -q num pipe com pipefail derruba o lspci via SIGPIPE e "falha" o
# pipeline mesmo com match; capturar a saida primeiro evita o falso negativo.
GPUS="$(lspci | grep -iE "vga|display|3d" || true)"
if ! printf '%s' "$GPUS" | grep -qi "AMD"; then
    echo "sem GPU AMD -- nada a fazer"
    exit 0
fi

echo "==> LACT (controle da GPU AMD)"
if ! pacman -Qq lact &>/dev/null; then
    sudo pacman -S --needed --noconfirm lact \
        || { echo "    ERRO: instale o lact manualmente" >&2; exit 1; }
fi
# O daemon e quem fala com o sysfs da GPU; a GUI (lact) e so cliente.
sudo systemctl enable --now lactd.service \
    || echo "    AVISO: nao consegui habilitar o lactd" >&2

# amdgpu.ppfeaturemask=0xffffffff destrava o overdrive (tensao/clock
# manuais). Sem ele o LACT mostra os sensores mas nao deixa ajustar a
# tensao. Este sistema usa UKI do mkinitcpio: a cmdline vem de
# /etc/kernel/cmdline e o parametro so vale depois de regerar a imagem
# e reiniciar.
PARAM="amdgpu.ppfeaturemask=0xffffffff"
CMDLINE="/etc/kernel/cmdline"
if grep -q "amdgpu.ppfeaturemask" /proc/cmdline; then
    echo "    overdrive ja ativo na cmdline do boot atual"
elif [ -f "$CMDLINE" ]; then
    if grep -q "amdgpu.ppfeaturemask" "$CMDLINE"; then
        echo "    $PARAM ja esta em $CMDLINE -- reinicie para valer"
    else
        echo "    adicionando $PARAM em $CMDLINE"
        sudo sed -i "s/\$/ $PARAM/" "$CMDLINE"
        echo "    regenerando a UKI (mkinitcpio -P)"
        sudo mkinitcpio -P >/dev/null 2>&1 \
            || echo "    AVISO: mkinitcpio falhou; rode 'sudo mkinitcpio -P'" >&2
        echo "    REINICIE para o controle de tensao ficar disponivel"
    fi
else
    echo "    AVISO: $CMDLINE nao existe (bootloader diferente?);" \
         "adicione '$PARAM' na cmdline do kernel manualmente" >&2
fi
echo "    abra 'lact' para tensao, clocks, power limit e curva de fan"
