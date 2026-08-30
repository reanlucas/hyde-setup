#!/usr/bin/env bash
# Exercita a etapa sem tocar em pacotes, boot real ou sessao grafica.
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin" "$WORK/config/hypr"
cat >"$WORK/setup.conf" <<EOF
GPU_VENDOR="amd"
CORECTRL=1
CORECTRL_START_DELAY=7
CORECTRL_RESTORE_PROFILE=1
CORECTRL_POLKIT=1
CORECTRL_POLKIT_RULE="$WORK/corectrl.rules"
CORECTRL_CMDLINE="$WORK/kernel.cmdline"
EOF
printf 'root=UUID=test quiet\n' >"$WORK/kernel.cmdline"
printf '%s\n' '-- user override' >"$WORK/config/hypr/hyprland.lua"

cat >"$WORK/bin/sudo" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "install" ]; then
    shift
    args=()
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -o|-g|-m) shift 2 ;;
            -D) args+=("$1"); shift ;;
            *) args+=("$1"); shift ;;
        esac
    done
    exec install -m 0644 "${args[@]}"
fi
exec "$@"
EOF
cat >"$WORK/bin/pacman" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$WORK/bin/mkinitcpio" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$WORK/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$WORK/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "list-unit-files" ]; then
    printf '%s enabled\n' "$2"
fi
exit 0
EOF
chmod +x "$WORK/bin/"*

XDG_CONFIG_HOME="$WORK/config" \
PATH="$WORK/bin:$PATH" \
HYDE_SETUP_CONF="$WORK/setup.conf" \
bash "$BASE/scripts/60-corectrl.sh"

grep -qw 'amdgpu.ppfeaturemask=0xffffffff' "$WORK/kernel.cmdline"
grep -Fq -- 'corectrl --minimize-systray' "$WORK/config/hypr/hyprland.lua"
grep -Fq -- 'sleep 7' "$WORK/config/hypr/hyprland.lua"
grep -Fq -- '_G.__corectrl_autostart' "$WORK/config/hypr/hyprland.lua"
grep -Fq 'org.corectrl.helper.init' "$WORK/corectrl.rules"
grep -Fq 'org.corectrl.helperkiller.init' "$WORK/corectrl.rules"
grep -Fq 'subject.user == "'"$(id -un)"'"' "$WORK/corectrl.rules"
unzip -p "$WORK/config/corectrl/profiles/_global_.ccpro" profile.xml | \
    grep -Fq 'AMD_PM_POWERCAP active="true" value="255"'

# A segunda execucao nao duplica o bloco, o parametro ou o perfil.
XDG_CONFIG_HOME="$WORK/config" \
PATH="$WORK/bin:$PATH" \
HYDE_SETUP_CONF="$WORK/setup.conf" \
bash "$BASE/scripts/60-corectrl.sh"
[ "$(grep -c '^-- >>> hyde-setup:corectrl$' "$WORK/config/hypr/hyprland.lua")" -eq 1 ]
[ "$(grep -o 'amdgpu.ppfeaturemask=0xffffffff' "$WORK/kernel.cmdline" | wc -l)" -eq 1 ]

printf 'ok: corectrl\n'
