#!/usr/bin/env bash
# Confere que a etapa pede os extras e a galeria inteira ao CLI oficial.
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin" "$WORK/HyDE/Scripts" "$WORK/config"
cat >"$WORK/setup.conf" <<EOF
HYDE_DIR="$WORK/HyDE"
HYDE_EXTRAS=1
HYDE_TEMAS="galeria"
EOF
cat >"$WORK/HyDE/Scripts/pkg_extra.lst" <<'EOF'
foo
bar|foo
trash-cli-git
EOF
cat >"$WORK/HyDE/Scripts/install_pkg.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$ASSET_TEST_LOG"
EOF
cat >"$WORK/bin/pacman" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    -Qq)
        [ "$2" = "trash-cli-git" ] && exit 1
        exit 0
        ;;
    -S) exit 0 ;;
    *) exit 1 ;;
esac
EOF
cat >"$WORK/bin/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
cat >"$WORK/bin/hydectl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$ASSET_TEST_LOG"
mkdir -p "$XDG_CONFIG_HOME/hyde/themes/Test"
EOF
chmod +x "$WORK/HyDE/Scripts/install_pkg.sh" "$WORK/bin/"*

ASSET_TEST_LOG="$WORK/calls.log" \
HYDE_SETUP_CONF="$WORK/setup.conf" \
HYDECTL="$WORK/bin/hydectl" \
XDG_CONFIG_HOME="$WORK/config" \
PATH="$WORK/bin:$PATH" \
bash "$BASE/scripts/15-hyde-assets.sh"

grep -Fq -- "$WORK/HyDE/Scripts/pkg_extra.lst" "$WORK/calls.log"
grep -Fxq -- 'theme import --fetch all' "$WORK/calls.log"

printf 'ok: hyde assets\n'
