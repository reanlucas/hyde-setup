#!/usr/bin/env bash
# Instala todo o catalogo de temas suportados pelo HyDE e todos os extras.
# O catalogo e mantido pelo proprio HyDE; hydectl --fetch all e a interface
# publica que o atualiza e importa cada tema publicado na galeria.
set -euo pipefail

CONF="${HYDE_SETUP_CONF:-$(dirname "${BASH_SOURCE[0]}")/../setup.conf}"
# shellcheck disable=SC1090
. "$CONF"

HYDE_DIR="${HYDE_DIR:-$HOME/HyDE}"
HYDECTL="${HYDECTL:-$HOME/.local/bin/hydectl}"
EXTRAS_LIST="$HYDE_DIR/Scripts/pkg_extra.lst"

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
    case "${HYDE_TEMAS:-galeria}" in
        0|nao|none)
            echo "==> Temas do HyDE desativados"
            return 0
            ;;
        oficiais)
            echo "==> Temas oficiais do HyDE"
            "$HYDE_DIR/Scripts/restore_thm.sh" "$HYDE_DIR/Scripts/themepatcher.lst"
            ;;
        galeria|todos|all)
            [ -x "$HYDECTL" ] || HYDECTL="$(command -v hydectl || true)"
            [ -n "$HYDECTL" ] && [ -x "$HYDECTL" ] || {
                echo "ERRO: hydectl nao encontrado; restaure o HyDE antes dos temas" >&2
                return 1
            }
            echo "==> Todos os temas da galeria suportada pelo HyDE"
            "$HYDECTL" theme import --fetch all
            ;;
        *)
            echo "ERRO: HYDE_TEMAS deve ser galeria, oficiais ou 0" >&2
            return 1
            ;;
    esac

    local temas
    temas="$(find "${XDG_CONFIG_HOME:-$HOME/.config}/hyde/themes" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
    [ "$temas" -gt 0 ] || {
        echo "ERRO: nenhum tema HyDE foi instalado" >&2
        return 1
    }
    echo "    $temas tema(s) disponivel(is)"
}

instalar_extras
instalar_temas
