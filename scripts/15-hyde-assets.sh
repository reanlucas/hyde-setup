#!/usr/bin/env bash
# Instala todo o catalogo de temas suportados pelo HyDE e todos os extras.
# O catalogo e mantido pelo proprio HyDE. O `--fetch all` do hydectl apenas
# atualiza temas ja instalados, e algumas versoes misturam logs com a saida de
# `--json`; baixamos o JSON oficial diretamente e aplicamos cada entrada.
set -euo pipefail

CONF="${HYDE_SETUP_CONF:-$(dirname "${BASH_SOURCE[0]}")/../setup.conf}"
# shellcheck disable=SC1090
. "$CONF"

HYDE_DIR="${HYDE_DIR:-$HOME/HyDE}"
EXTRAS_LIST="$HYDE_DIR/Scripts/pkg_extra.lst"
THEME_PATCHER="${HYDE_THEME_PATCHER:-$HOME/.local/lib/hyde/theme.patch.sh}"
CATALOGO_URL="${HYDE_TEMAS_CATALOGO_URL:-https://raw.githubusercontent.com/HyDE-Project/hyde-gallery/master/hyde-themes.json}"

[ -x "$HYDE_DIR/Scripts/install_pkg.sh" ] || {
    echo "ERRO: HyDE nao encontrado em $HYDE_DIR" >&2
    exit 1
}

instalar_extras() {
    [ "${HYDE_EXTRAS:-1}" = "1" ] || {
        echo "==> Extras do HyDE desativados"
        return 0
    }
    [ -f "$EXTRAS_LIST" ] || {
        echo "ERRO: lista de extras ausente: $EXTRAS_LIST" >&2
        return 1
    }

    echo "==> Todos os extras do HyDE"
    # install_pkg.sh entende dependencias e AUR; use_default evita perguntas
    # durante uma restauracao nao interativa.
    use_default=--noconfirm "$HYDE_DIR/Scripts/install_pkg.sh" "$EXTRAS_LIST"

    # O catalogo atual ainda cita o antigo pacote AUR trash-cli-git; o pacote
    # foi incorporado ao repositorio oficial do Arch como trash-cli. Preservar
    # a funcionalidade, em vez de deixar uma entrada obsoleta invalidar toda a
    # restauracao, tambem torna a checagem abaixo significativa.
    if grep -qE '^[[:space:]]*trash-cli-git([[:space:]]|#|$)' "$EXTRAS_LIST" \
       && ! pacman -Qq trash-cli-git >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm trash-cli
    fi

    # O helper do HyDE registra pacotes indisponiveis mas pode terminar com
    # sucesso. Conferir cada entrada ativa impede uma instalacao parcialmente
    # pronta de parecer uma restauracao valida.
    local -a faltando=()
    while IFS= read -r pacote; do
        if [ "$pacote" = "trash-cli-git" ]; then
            pacman -Qq trash-cli >/dev/null 2>&1 || faltando+=("$pacote (ou trash-cli)")
        else
            pacman -Qq "$pacote" >/dev/null 2>&1 || faltando+=("$pacote")
        fi
    done < <(sed -E 's/[[:space:]]+#.*$//; /^[[:space:]]*($|#)/d; s/\|.*$//; s/[[:space:]]+$//' "$EXTRAS_LIST")

    if [ ${#faltando[@]} -gt 0 ]; then
        printf 'ERRO: extras do HyDE ausentes: %s\n' "${faltando[*]}" >&2
        return 1
    fi
}

instalar_temas() {
    # O HyDE Lua ainda consulta este estado legado sem conferir se ele existe.
    # Um arquivo vazio e valido para o hyq e representa corretamente "nenhum
    # override Hyprlang". O contador exportado contorna um typo do color.set.sh
    # atual (render_failed vs render_failures) durante esta restauracao.
    local estado_hyde="${XDG_STATE_HOME:-$HOME/.local/state}/hyde"
    mkdir -p "$estado_hyde"
    [ -e "$estado_hyde/hyprland.conf" ] || touch "$estado_hyde/hyprland.conf"
    export render_failures=0

    local color_set="$HOME/.local/lib/hyde/color.set.sh"
    if [ -f "$color_set" ] \
       && grep -Fxq 'render_failed=0' "$color_set" \
       && grep -q 'render_failures' "$color_set"; then
        cp -pn "$color_set" "$color_set.bak-hyde-setup"
        sed -i '0,/^render_failed=0$/s//render_failures=0/' "$color_set"
        echo "    compatibilidade wallbash corrigida (render_failures)"
    fi

    instalar_galeria() {
        # Todos os repositorios do catalogo sao publicos. Se uma entrada virou
        # 404/privada, Git tenta pedir usuario e senha mesmo que credenciais nao
        # possam resolver; desativar prompts permite classifica-la e continuar.
        export GIT_TERMINAL_PROMPT=0
        export GCM_INTERACTIVE=Never

        command -v curl >/dev/null 2>&1 || {
            echo "ERRO: curl nao encontrado para baixar o catalogo de temas" >&2
            return 1
        }
        [ -x "$THEME_PATCHER" ] || THEME_PATCHER="$(command -v theme.patch.sh || true)"
        [ -n "$THEME_PATCHER" ] && [ -x "$THEME_PATCHER" ] || {
            echo "ERRO: theme.patch.sh nao encontrado" >&2
            return 1
        }

        local catalogo entradas
        catalogo="$(mktemp)"
        entradas="$(mktemp)"
        if ! curl -fsSL --retry 3 --retry-all-errors --connect-timeout 15 \
             --max-time 120 "$CATALOGO_URL" -o "$catalogo"; then
            echo "ERRO: nao foi possivel baixar $CATALOGO_URL" >&2
            rm -f "$catalogo" "$entradas"
            return 1
        fi
        if ! python3 - "$catalogo" >"$entradas" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as arquivo:
        catalogo = json.load(arquivo)
except (OSError, json.JSONDecodeError) as erro:
    raise SystemExit("JSON ausente ou invalido: %s" % erro)
if not isinstance(catalogo, list) or not catalogo:
    raise SystemExit("catalogo vazio ou invalido")
vistos = set()
for item in catalogo:
    nome = item.get("THEME") if isinstance(item, dict) else None
    link = item.get("LINK") if isinstance(item, dict) else None
    if not isinstance(nome, str) or not nome.strip():
        raise SystemExit("entrada sem THEME")
    if not isinstance(link, str) or not link.startswith("https://github.com/"):
        raise SystemExit("LINK invalido para %s" % nome)
    if nome in vistos:
        raise SystemExit("tema duplicado: %s" % nome)
    if any(c in nome + link for c in "\t\r\n"):
        raise SystemExit("caractere de controle no catalogo")
    vistos.add(nome)
    print("%s\t%s" % (nome, link))
PY
        then
            echo "ERRO: catalogo de temas invalido" >&2
            rm -f "$catalogo" "$entradas"
            return 1
        fi
        rm -f "$catalogo"

        local total minimo temas_dir instalados tema link branch link_branch
        total="$(wc -l <"$entradas")"
        minimo="${HYDE_TEMAS_MINIMO:-50}"
        [[ "$minimo" =~ ^[0-9]+$ ]] || {
            echo "ERRO: HYDE_TEMAS_MINIMO deve ser inteiro" >&2
            rm -f "$entradas"
            return 1
        }
        [ "$total" -gt "$minimo" ] || {
            echo "ERRO: catalogo trouxe apenas $total temas (esperado: mais de $minimo)" >&2
            rm -f "$entradas"
            return 1
        }

        temas_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hyde/themes"
        mkdir -p "$temas_dir"
        instalados=0
        local -a indisponiveis=() incompativeis=()

        reparar_tema_upstream() {
            local nome="$1" cache arquivo repo arc cursor
            [ "$nome" = "Nightbrew" ] || return 1
            cursor="${XDG_DATA_HOME:-$HOME/.local/share}/icons/Bibata-Modern-Ice"
            [ -d "$cursor" ] || return 1
            cache="${XDG_CACHE_HOME:-$HOME/.cache}/hyde/themepatcher"
            arquivo="$(find "$cache" -type f \
                -path '*/Configs/.config/hyde/themes/Nightbrew/hypr.theme' \
                -print -quit 2>/dev/null)"
            [ -n "$arquivo" ] || return 1
            grep -Eq '^[[:space:]]*\$CURSOR[-_]THEME[[:space:]]*=' "$arquivo" \
                || return 1
            grep -q 'Bibata-Modern-Ice' "$arquivo" || return 1
            repo="${arquivo%%/Configs/.config/hyde/themes/*}"
            arc="$repo/Source/arcs/Cursor_Bibata-Modern-Ice.tar.gz"
            if [ ! -f "$arc" ]; then
                mkdir -p "$(dirname "$arc")"
                if ! tar -czf "$arc" -C "$(dirname "$cursor")" "$(basename "$cursor")"; then
                    rm -f "$arc"
                    return 1
                fi
                echo "    compatibilidade Nightbrew: cursor padrao reaproveitado"
            fi
        }

        while IFS=$'\t' read -r tema link; do
            if [ -s "$temas_dir/$tema/hypr.theme" ]; then
                instalados=$((instalados + 1))
                continue
            fi

            link_branch="$link"
            if [[ "$link" != */tree/* ]]; then
                if ! branch="$(git ls-remote --symref "${link%/}" HEAD 2>/dev/null \
                    | awk '$1 == "ref:" && $3 == "HEAD" {sub("refs/heads/", "", $2); print $2; exit}')"; then
                    branch=""
                fi
                if [ -z "$branch" ]; then
                    echo "    INDISPONIVEL no GitHub: $tema ($link)" >&2
                    indisponiveis+=("$tema")
                    continue
                fi
                link_branch="${link%/}/tree/$branch"
            fi

            echo "    [$((instalados + 1))/$total] instalando $tema"
            # Em uma repeticao apos a primeira tentativa, o checkout ja esta
            # no cache e podemos corrigir Nightbrew antes de chamar o patcher.
            [ "$tema" != "Nightbrew" ] || reparar_tema_upstream "$tema" || true
            if "$THEME_PATCHER" "$tema" "$link_branch" --skipcaching \
               && [ -s "$temas_dir/$tema/hypr.theme" ]; then
                instalados=$((instalados + 1))
            elif reparar_tema_upstream "$tema" \
                 && "$THEME_PATCHER" "$tema" "$link_branch" --skipcaching \
                 && [ -s "$temas_dir/$tema/hypr.theme" ]; then
                instalados=$((instalados + 1))
            else
                echo "    INCOMPATIVEL com o HyDE atual: $tema" >&2
                incompativeis+=("$tema")
            fi
        done <"$entradas"
        rm -f "$entradas"

        if command -v hyde-shell >/dev/null 2>&1; then
            hyde-shell reload
        else
            echo "ERRO: hyde-shell nao encontrado para recarregar os temas" >&2
            return 1
        fi
        [ "$instalados" -gt "$minimo" ] || {
            echo "ERRO: apenas $instalados temas utilizaveis foram instalados" >&2
            return 1
        }
        local ignorados=$(( ${#indisponiveis[@]} + ${#incompativeis[@]} ))
        if [ "$ignorados" -gt 0 ]; then
            echo "    galeria utilizavel: $instalados/$total temas instalados"
            [ ${#indisponiveis[@]} -eq 0 ] \
                || printf '    indisponiveis no upstream: %s\n' "${indisponiveis[*]}"
            [ ${#incompativeis[@]} -eq 0 ] \
                || printf '    incompativeis no upstream: %s\n' "${incompativeis[*]}"
            if [ "${HYDE_TEMAS_ESTRITO:-0}" = "1" ]; then
                echo "ERRO: HYDE_TEMAS_ESTRITO=1 e o upstream tem entradas quebradas" >&2
                return 1
            fi
        else
            echo "    galeria completa: $instalados/$total temas instalados"
        fi
    }

    case "${HYDE_TEMAS:-galeria}" in
        0|nao|none)
            echo "==> Temas do HyDE desativados"
            return 0
            ;;
        oficiais)
            echo "==> HYDE_TEMAS=oficiais e legado; instalando a galeria completa"
            ;&
        galeria|todos|all)
            echo "==> Todos os temas da galeria suportada pelo HyDE"
            instalar_galeria
            ;;
        *)
            echo "ERRO: HYDE_TEMAS deve ser galeria (ou oficiais legado) ou 0" >&2
            return 1
            ;;
    esac

    local temas
    temas="$(find "${XDG_CONFIG_HOME:-$HOME/.config}/hyde/themes" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
    echo "    $temas diretorio(s) de tema disponivel(is) no total"
}

instalar_extras
instalar_temas
