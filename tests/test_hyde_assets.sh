#!/usr/bin/env bash
# Confere que a etapa pede os extras e a galeria inteira ao CLI oficial.
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin" "$WORK/HyDE/Scripts" "$WORK/config" \
    "$WORK/home/.local/lib/hyde"
cat >"$WORK/setup.conf" <<EOF
HYDE_DIR="$WORK/HyDE"
HYDE_EXTRAS=1
HYDE_TEMAS="galeria"
HYDE_TEMAS_MINIMO=2
HYDE_TEMAS_CATALOGO_URL="file://$WORK/catalog.json"
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
cat >"$WORK/catalog.json" <<'JSON'
[
  {"THEME": "Um", "LINK": "https://github.com/test/um"},
  {"THEME": "Dois", "LINK": "https://github.com/test/dois/tree/stable"},
  {"THEME": "Tres", "LINK": "https://github.com/test/tres"},
  {"THEME": "Nightbrew", "LINK": "https://github.com/test/nightbrew"},
  {"THEME": "Indisponivel", "LINK": "https://github.com/test/indisponivel"}
]
JSON
cat >"$WORK/bin/theme.patch.sh" <<'EOF'
#!/usr/bin/env bash
[ "${render_failures:-}" = "0" ] || exit 20
[ -f "$XDG_STATE_HOME/hyde/hyprland.conf" ] || exit 21
if [ "$1" = "Nightbrew" ]; then
    repo="$XDG_CACHE_HOME/hyde/themepatcher/test-Nightbrew"
    tema="$repo/Configs/.config/hyde/themes/Nightbrew"
    mkdir -p "$tema" "$repo/Source/arcs"
    printf '$CURSOR_THEME = Bibata-Modern-Ice\n' >"$tema/hypr.theme"
    [ -f "$repo/Source/arcs/Cursor_Bibata-Modern-Ice.tar.gz" ] || exit 24
fi
printf 'patch\t%s\t%s\t%s\n' "$1" "$2" "$3" >>"$ASSET_TEST_LOG"
mkdir -p "$XDG_CONFIG_HOME/hyde/themes/$1"
printf '# theme\n' >"$XDG_CONFIG_HOME/hyde/themes/$1/hypr.theme"
EOF
cat >"$WORK/bin/hyde-shell" <<'EOF'
#!/usr/bin/env bash
printf 'hyde-shell\t%s\n' "$*" >>"$ASSET_TEST_LOG"
EOF
cat >"$WORK/bin/git" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "ls-remote" ] && [ "$2" = "--symref" ]; then
    [ "${GIT_TERMINAL_PROMPT:-}" = "0" ] || exit 25
    [[ "$3" != *indisponivel* ]] || exit 128
    printf 'ref: refs/heads/main\tHEAD\n'
    exit 0
fi
exit 23
EOF
cat >"$WORK/home/.local/lib/hyde/color.set.sh" <<'EOF'
render_failed=0
if [ "$render_failures" -ne 0 ]; then
    exit 1
fi
EOF
chmod +x "$WORK/HyDE/Scripts/install_pkg.sh" "$WORK/bin/"*
mkdir -p "$WORK/home/.local/share/icons/Bibata-Modern-Ice"
printf 'cursor\n' >"$WORK/home/.local/share/icons/Bibata-Modern-Ice/index.theme"

ASSET_TEST_LOG="$WORK/calls.log" \
HOME="$WORK/home" \
HYDE_SETUP_CONF="$WORK/setup.conf" \
HYDE_THEME_PATCHER="$WORK/bin/theme.patch.sh" \
XDG_CACHE_HOME="$WORK/cache" \
XDG_CONFIG_HOME="$WORK/config" \
XDG_STATE_HOME="$WORK/state" \
PATH="$WORK/bin:$PATH" \
bash "$BASE/scripts/15-hyde-assets.sh"

grep -Fq -- "$WORK/HyDE/Scripts/pkg_extra.lst" "$WORK/calls.log"
grep -Fq $'patch\tUm\thttps://github.com/test/um/tree/main\t--skipcaching' "$WORK/calls.log"
grep -Fq $'patch\tDois\thttps://github.com/test/dois/tree/stable\t--skipcaching' "$WORK/calls.log"
grep -Fq $'patch\tNightbrew\thttps://github.com/test/nightbrew/tree/main\t--skipcaching' "$WORK/calls.log"
grep -Fxq $'hyde-shell\treload' "$WORK/calls.log"
[ -f "$WORK/state/hyde/hyprland.conf" ]
grep -Fxq 'render_failures=0' "$WORK/home/.local/lib/hyde/color.set.sh"
[ -f "$WORK/home/.local/lib/hyde/color.set.sh.bak-hyde-setup" ]

# Configuracoes antigas com "oficiais" tambem recebem hoje a galeria inteira.
sed -i 's/HYDE_TEMAS="galeria"/HYDE_TEMAS="oficiais"/' "$WORK/setup.conf"
: >"$WORK/calls.log"
ASSET_TEST_LOG="$WORK/calls.log" \
HOME="$WORK/home" \
HYDE_SETUP_CONF="$WORK/setup.conf" \
HYDE_THEME_PATCHER="$WORK/bin/theme.patch.sh" \
XDG_CACHE_HOME="$WORK/cache" \
XDG_CONFIG_HOME="$WORK/config" \
XDG_STATE_HOME="$WORK/state" \
PATH="$WORK/bin:$PATH" \
bash "$BASE/scripts/15-hyde-assets.sh"
grep -Fxq $'hyde-shell\treload' "$WORK/calls.log"

# Um catalogo no limite minimo e tratado como truncado, nunca como sucesso.
sed -i 's/HYDE_TEMAS_MINIMO=2/HYDE_TEMAS_MINIMO=5/' "$WORK/setup.conf"
if ASSET_TEST_LOG="$WORK/calls.log" \
   HOME="$WORK/home" \
   HYDE_SETUP_CONF="$WORK/setup.conf" \
   HYDE_THEME_PATCHER="$WORK/bin/theme.patch.sh" \
   XDG_CACHE_HOME="$WORK/cache" \
   XDG_CONFIG_HOME="$WORK/config" \
   XDG_STATE_HOME="$WORK/state" \
   PATH="$WORK/bin:$PATH" \
   bash "$BASE/scripts/15-hyde-assets.sh"; then
    echo "catalogo truncado foi aceito" >&2
    exit 1
fi

# Reproduz o caso real: o provedor do catalogo devolve sucesso, mas zero bytes.
: >"$WORK/catalog.json"
sed -i 's/HYDE_TEMAS_MINIMO=5/HYDE_TEMAS_MINIMO=2/' "$WORK/setup.conf"
if ASSET_TEST_LOG="$WORK/calls.log" \
   HOME="$WORK/home" \
   HYDE_SETUP_CONF="$WORK/setup.conf" \
   HYDE_THEME_PATCHER="$WORK/bin/theme.patch.sh" \
   XDG_CACHE_HOME="$WORK/cache" \
   XDG_CONFIG_HOME="$WORK/config" \
   XDG_STATE_HOME="$WORK/state" \
   PATH="$WORK/bin:$PATH" \
   bash "$BASE/scripts/15-hyde-assets.sh"; then
    echo "catalogo vazio foi aceito" >&2
    exit 1
fi

printf 'ok: hyde assets\n'
