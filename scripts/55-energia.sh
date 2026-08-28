#!/usr/bin/env bash
# Energia: a maquina nunca bloqueia nem suspende por inatividade -- so a tela
# apaga. Reescreve os listeners do hypridle (~/.config/hypr/hypridle.conf) e
# garante que o logind tambem nao tenha acao de ociosidade.
#
# O bloqueio MANUAL continua valendo: o bloco `general` do hypridle mantem
# lock_cmd/unlock_cmd, entao `loginctl lock-session` e o bind do HyDE seguem
# funcionando. O que sai sao os gatilhos automaticos.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../setup.conf"

ALVO="$HOME/.config/hypr/hypridle.conf"
[ -f "$ALVO" ] || { echo "$ALVO nao existe -- o HyDE foi instalado?" >&2; exit 1; }
cp "$ALVO" "$ALVO.bak-$(date +%Y%m%d-%H%M%S)"

TELA="${ENERGIA_TELA:-1}"
TELA_S="${ENERGIA_TELA_SEGUNDOS:-300}"
DIM="${ENERGIA_DIM:-0}"
DIM_S="${ENERGIA_DIM_SEGUNDOS:-60}"

# Monta o bloco de listeners. Nao ha listener de lock nem de suspend: e essa
# ausencia que atende ao pedido, e nao um valor grande de timeout.
BLOCO="# >>> hyde-setup:energia
# Gerado por hyde-setup (etapa 55). Editar setup.conf e rodar de novo reescreve.
#
# Sem bloqueio e sem suspensao por inatividade: a maquina continua ligada e
# so a tela apaga. Bloqueio manual segue valendo pelo \`general\` acima.
"

if [ "$DIM" = "1" ]; then
    BLOCO="$BLOCO
# Escurece antes de apagar, para o corte nao ser seco.
listener {
    timeout = ${DIM_S}
    on-timeout = brightnessctl -s set 1%
    on-resume = brightnessctl -r
}
"
fi

if [ "$TELA" = "1" ]; then
    BLOCO="$BLOCO
# Apaga a tela (DPMS off). O sistema segue rodando: downloads, builds,
# players e sessoes ssh nao param.
listener {
    timeout = ${TELA_S}
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}
"
fi

BLOCO="$BLOCO# <<< hyde-setup:energia"

# Tira o bloco anterior (para ser idempotente) e TODOS os listeners que o HyDE
# tenha reposto -- incluindo os de lock e suspend, que sao o alvo aqui.
BLOCO="$BLOCO" python3 - "$ALVO" <<'PY'
import os, re, sys

alvo = sys.argv[1]
bloco = os.environ["BLOCO"]
s = open(alvo).read()

s = re.sub(r"# >>> hyde-setup:energia.*?# <<< hyde-setup:energia\n?", "", s, flags=re.S)

# Cada listener e um bloco que termina numa linha com apenas "}"; os
# comentarios que o antecedem descrevem justamente o que estamos removendo.
alvo_re = re.compile(r"(?:^[ \t]*#[^\n]*\n)*^listener[^\n]*\{.*?^\}[ \t]*\n", re.S | re.M)

achou = [False]
def troca(m):
    if not achou[0]:
        achou[0] = True
        return bloco + "\n"
    return ""

s = alvo_re.sub(troca, s)

if not achou[0]:
    ancora = re.search(r"^[ \t]*# // --- Custom listeners", s, re.M)
    if ancora:
        s = s[:ancora.start()] + bloco + "\n\n" + s[ancora.start():]
    else:
        s = s.rstrip() + "\n\n" + bloco + "\n"

s = re.sub(r"\n{3,}", "\n\n", s)
open(alvo, "w").write(s)
PY

# O logind tem a propria acao de ociosidade (IdleAction). O padrao ja e
# "ignore", mas deixar explicito impede que uma atualizacao do systemd ou
# outro pacote reintroduza suspensao pelas costas.
DROPIN="/etc/systemd/logind.conf.d/90-hyde-setup-energia.conf"
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee "$DROPIN" >/dev/null <<'CONF'
# hyde-setup: nada de bloquear ou suspender por ociosidade.
[Login]
IdleAction=ignore
IdleActionSec=0
CONF
sudo systemctl reload systemd-logind 2>/dev/null || true

# Recarrega o hypridle sob o nome que o HyDE usa para ele.
UNIDADE="$(systemctl --user list-units --all --no-legend 2>/dev/null \
    | awk '/-idle\.service/ {print $1; exit}')"
if [ -n "$UNIDADE" ]; then
    systemctl --user restart "$UNIDADE"
    echo "==> $UNIDADE reiniciado"
else
    pkill -x hypridle && (hypridle >/dev/null 2>&1 &)
    echo "==> hypridle reiniciado"
fi

echo "==> Ociosidade: sem bloqueio, sem suspensao."
if [ "$TELA" = "1" ]; then
    echo "    tela apaga em ${TELA_S}s; o sistema continua ligado"
else
    echo "    tela nao apaga (ENERGIA_TELA=0)"
fi
