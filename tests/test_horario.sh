#!/usr/bin/env bash
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"

printf 'TIMEZONE="America/Sao_Paulo"\n' >"$WORK/setup.conf"
cat >"$WORK/bin/timedatectl" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    list-timezones) printf 'America/Sao_Paulo\nUTC\n' ;;
    show) printf '%s\n' "${TEST_TIMEZONE:-UTC}" ;;
    set-timezone|set-ntp) printf '%s\n' "$*" >>"$TEST_LOG" ;;
    *) exit 2 ;;
esac
EOF
cat >"$WORK/bin/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
chmod +x "$WORK/bin/"*

TEST_LOG="$WORK/calls.log" TEST_TIMEZONE=UTC \
HYDE_SETUP_CONF="$WORK/setup.conf" PATH="$WORK/bin:$PATH" \
    bash "$BASE/scripts/05-horario.sh"
grep -Fxq 'set-timezone America/Sao_Paulo' "$WORK/calls.log"
grep -Fxq 'set-ntp true' "$WORK/calls.log"

: >"$WORK/calls.log"
TEST_LOG="$WORK/calls.log" TEST_TIMEZONE=America/Sao_Paulo \
HYDE_SETUP_CONF="$WORK/setup.conf" PATH="$WORK/bin:$PATH" \
    bash "$BASE/scripts/05-horario.sh"
! grep -q '^set-timezone ' "$WORK/calls.log"
grep -Fxq 'set-ntp true' "$WORK/calls.log"

printf 'ok: horario\n'
