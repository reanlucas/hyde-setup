#!/usr/bin/env python3
"""Transforma o tema GTK4 do MacOS num template wallbash.

O tema MacOS vem num gresource com a folha de estilo inteira e as cores
cravadas em hexadecimal -- 234 cores distintas em 640 lugares. Nao da para
recolorir redefinindo @define-color: a barra lateral, por exemplo, e um
`background-color: #333333` literal.

Entao a gente reescreve a folha: cada cor literal vira um token do wallbash,
e o resultado e um .dcol que o HyDE re-renderiza a cada troca de tema ou de
papel de parede, como ja faz com os proprios templates dele.

Como cada cor e classificada:

  * cinzas (saturacao < 12%)  -> rampa do grupo 1 (1xa1..1xa9), que e a cor
    dominante do papel de parede. Sao a maioria: fundo, bordas, hover;
  * azuis (matiz 190-260)     -> rampa do grupo 4, que e o accent do HyDE;
  * o resto (vermelho, verde, laranja) fica como esta -- sao cores semanticas,
    erro e sucesso nao deveriam virar tons do papel de parede.

Dentro de cada rampa a posicao vem do ranking de luminancia, nao do valor
absoluto: as 9 faixas sao usadas por igual seja qual for a paleta que o
wallbash produzir. E como #333333 (fundo) e #373737 (hover) cairiam na mesma
faixa e virariam a mesma cor -- matando o hover --, cada cor leva ainda um
shade() relativo a mediana da sua faixa, o que preserva as micro-diferencas.

Roda uma vez na instalacao; o .dcol gerado e que vive no ~/.config.
"""
import argparse
import colorsys
import re
import statistics
import sys
from pathlib import Path

TOKEN_NEUTRO = "wallbash_1xa{}"
TOKEN_ACCENT = "wallbash_4xa{}"
TOKEN_TEXTO = "wallbash_txt1"
FAIXAS = 9

COR = re.compile(
    r"#(?P<hex>[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b"
    r"|rgba?\(\s*(?P<r>\d+)\s*,\s*(?P<g>\d+)\s*,\s*(?P<b>\d+)\s*"
    r"(?:,\s*(?P<a>[0-9.]+)\s*)?\)"
)


def rgb_de(m):
    """(r, g, b, alpha) a partir de um match, em 0..1."""
    h = m.group("hex")
    if h:
        if len(h) == 3:
            h = "".join(c * 2 for c in h)
        a = int(h[6:8], 16) / 255 if len(h) == 8 else None
        return (int(h[0:2], 16) / 255, int(h[2:4], 16) / 255,
                int(h[4:6], 16) / 255, a)
    a = m.group("a")
    return (int(m.group("r")) / 255, int(m.group("g")) / 255,
            int(m.group("b")) / 255, float(a) if a is not None else None)


def luminancia(r, g, b):
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def classificar(r, g, b):
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if s < 0.12:
        return "neutro"
    if 190 <= h * 360 <= 260:
        return "accent"
    return "manter"


# O tema traz 4 chamadas a gtkmix(), que nao existe no GTK4 -- e um resto da
# geracao do port. O GTK descarta a regra inteira com "Expected a valid color".
# mix() e o equivalente, so que com fator 0..1 em vez de porcentagem.
GTKMIX = re.compile(r"gtkmix\((.+?),\s*(\d+(?:\.\d+)?)%\)")


def corrigir_gtkmix(css: str) -> str:
    return GTKMIX.sub(lambda m: f"mix({m.group(1)}, {float(m.group(2)) / 100:g})", css)


def gerar(css: str) -> str:
    css = corrigir_gtkmix(css)
    # 1a passada: coleta e classifica
    achados = []
    for m in COR.finditer(css):
        r, g, b, a = rgb_de(m)
        achados.append((m, classificar(r, g, b), luminancia(r, g, b), a))

    # faixas por ranking de luminancia, para cada rampa
    faixa_de = {}
    mediana = {}
    for tipo in ("neutro", "accent"):
        lums = sorted({l for _, t, l, _ in achados if t == tipo})
        if not lums:
            continue
        for i, l in enumerate(lums):
            faixa_de[(tipo, l)] = min(FAIXAS, 1 + i * FAIXAS // len(lums))
        for f in range(1, FAIXAS + 1):
            desta = [l for l in lums if faixa_de[(tipo, l)] == f]
            if desta:
                mediana[(tipo, f)] = statistics.median(desta)

    def substituir(m):
        r, g, b, a = rgb_de(m)
        tipo = classificar(r, g, b)
        lum = luminancia(r, g, b)
        if tipo == "manter":
            return m.group(0)
        if tipo == "neutro" and lum > 0.88:
            base, ref = "#<%s>" % TOKEN_TEXTO, 0.95      # quase branco = texto
        else:
            f = faixa_de[(tipo, lum)]
            token = (TOKEN_NEUTRO if tipo == "neutro" else TOKEN_ACCENT).format(f)
            base, ref = "#<%s>" % token, mediana[(tipo, f)]
        fator = lum / ref if ref > 0.02 else 1.0
        fator = max(0.55, min(1.8, fator))
        expr = base if abs(fator - 1) < 0.03 else f"shade({base}, {fator:.3f})"
        if a is not None and a < 0.999:
            expr = f"alpha({expr}, {a:g})"
        return expr

    return COR.sub(substituir, css)


# as 42 variaveis que o libadwaita 1.6+ usa, ligadas a paleta do wallbash.
# As superficies grandes levam alfa: o Hyprland ja borra o que esta atras, e a
# lateral mais transparente que o conteudo e o que da a leitura de "painel"
# do macOS. A opacidade do compositor fica em 1 para o nautilus (regra de
# janela na etapa 20/45), senao ela escureceria tudo por cima e apagaria a
# diferenca entre lateral e conteudo.
def raiz(a_janela: float, a_lateral: float, a_cabecalho: float) -> str:
    """Bloco de cor: as 42 variaveis do libadwaita mais a camada translucida.

    A transparencia so funciona se UMA camada por regiao for pintada. A
    primeira versao daqui pintava a mesma cor em .sidebar, .sidebar-pane,
    .navigation-sidebar, .sidebar list e mais duas -- e como elas se aninham,
    0.62 empilhado quatro vezes da 0.98: opaco. O desenho certo e este:

      janela  -> pintada com o alfa da LATERAL; e ela que aparece ali, entao
                 e este numero que deixa o menu lateral transparente
      lateral -> transparente de ponta a ponta, deixa a janela passar
      conteudo-> uma unica camada, com o proprio alfa, por cima da janela
      cabecalho -> idem; sem fundo proprio herdaria a lateral e sumiria
    """
    j, l, h = f"{a_janela:g}", f"{a_lateral:g}", f"{a_cabecalho:g}"
    return f"""
:root {{
  --window-bg-color: alpha(#<wallbash_pry1>, {l});
  --window-fg-color: #<wallbash_txt1>;
  --view-bg-color: alpha(#<wallbash_1xa1>, {j});
  --view-fg-color: #<wallbash_txt1>;
  --headerbar-bg-color: alpha(#<wallbash_1xa2>, {h});
  --headerbar-fg-color: #<wallbash_txt1>;
  --headerbar-border-color: #<wallbash_1xa4>;
  --headerbar-backdrop-color: transparent;
  --headerbar-shade-color: alpha(#<wallbash_1xa1>, 0.4);
  --headerbar-darker-shade-color: alpha(#<wallbash_1xa1>, 0.6);
  --sidebar-bg-color: transparent;
  --sidebar-fg-color: #<wallbash_txt1>;
  --sidebar-backdrop-color: transparent;
  --sidebar-border-color: #<wallbash_1xa4>;
  --sidebar-shade-color: alpha(#<wallbash_1xa1>, 0.4);
  --secondary-sidebar-bg-color: transparent;
  --secondary-sidebar-fg-color: #<wallbash_txt1>;
  --secondary-sidebar-backdrop-color: transparent;
  --secondary-sidebar-border-color: #<wallbash_1xa4>;
  --secondary-sidebar-shade-color: alpha(#<wallbash_1xa1>, 0.4);
  --card-bg-color: alpha(#<wallbash_1xa2>, {j});
  --card-fg-color: #<wallbash_txt1>;
  --card-shade-color: alpha(#<wallbash_1xa1>, 0.4);
  --dialog-bg-color: alpha(#<wallbash_1xa2>, {j});
  --dialog-fg-color: #<wallbash_txt1>;
  --popover-bg-color: alpha(#<wallbash_1xa2>, {j});
  --popover-fg-color: #<wallbash_txt1>;
  --popover-shade-color: alpha(#<wallbash_1xa1>, 0.4);
  --thumbnail-bg-color: alpha(#<wallbash_1xa3>, {j});
  --thumbnail-fg-color: #<wallbash_txt1>;
  --shade-color: alpha(#<wallbash_1xa1>, 0.4);
  --scrollbar-outline-color: #<wallbash_1xa4>;
  --accent-bg-color: #<wallbash_4xa9>;
  --accent-fg-color: #<wallbash_4xa1>;
  --destructive-bg-color: #<wallbash_2xa9>;
  --destructive-fg-color: #<wallbash_2xa1>;
  --success-bg-color: #<wallbash_3xa9>;
  --success-fg-color: #<wallbash_3xa1>;
  --warning-bg-color: #<wallbash_2xa7>;
  --warning-fg-color: #<wallbash_2xa1>;
  --error-bg-color: #<wallbash_2xa9>;
  --error-fg-color: #<wallbash_2xa1>;
}}

/* 1. a janela: a unica camada translucida embaixo de tudo */
window.background,
window.background:backdrop {{
  background-color: alpha(#<wallbash_pry1>, {l});
}}

/* 2. a lateral inteira sem pintura propria, do painel ate a lista -- e o que
      faz a transparencia valer para o menu lateral todo, e nao so para uma
      faixa. Cada um destes que pintasse somaria alfa com os de cima. */
.sidebar, .sidebar-pane, .navigation-sidebar,
.sidebar-pane .navigation-sidebar, .sidebar list, .sidebar list row,
.sidebar-pane scrolledwindow, .sidebar-pane viewport,
placessidebar, placessidebar > viewport.frame,
.content-pane .sidebar-pane, .sidebar-pane .content-pane,
.sidebar-pane banner > revealer > widget {{
  background-color: transparent;
  background-image: none;
}}

/* 3. o conteudo: uma camada so, opaca o bastante para nao herdar a
      transparencia da lateral que esta por baixo */
.content-pane, .content-pane scrolledwindow, .content-pane viewport {{
  background-color: transparent;
  background-image: none;
}}
.view, listview.view, gridview, columnview {{
  background-color: alpha(#<wallbash_1xa1>, {j});
}}

/* 4. cabecalho: fundo proprio, senao herdaria a lateral e ficaria ilegivel */
headerbar, .titlebar, headerbar.titlebar, headerbar:backdrop,
.toolbar, tabbar:not(.inline) .box, .top-bar {{
  background-color: alpha(#<wallbash_1xa2>, {h});
  background-image: none;
}}
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tema", default=str(Path.home() / ".local/share/themes/MacOS"))
    ap.add_argument("--saida", required=True)
    ap.add_argument("--variante", default="gtk-dark.css")
    ap.add_argument("--alpha-janela", type=float, default=1.0,
                    help="opacidade do conteudo (0..1)")
    ap.add_argument("--alpha-lateral", type=float, default=1.0,
                    help="opacidade da barra lateral")
    ap.add_argument("--alpha-cabecalho", type=float, default=1.0,
                    help="opacidade do cabecalho")
    a = ap.parse_args()

    gres = Path(a.tema) / "gtk-4.0/gtk.gresource"
    if not gres.is_file():
        print(f"tema sem gresource: {gres}", file=sys.stderr)
        return 1

    import gi
    from gi.repository import Gio
    Gio.Resource.load(str(gres))._register()
    dados = Gio.resources_lookup_data(f"/org/gnome/theme/{a.variante}",
                                      Gio.ResourceLookupFlags.NONE)
    css = dados.get_data().decode("utf-8", "replace")

    corpo = gerar(css) + "\n" + raiz(a.alpha_janela, a.alpha_lateral, a.alpha_cabecalho)
    cabeca = ('${cacheDir}/wallbash/gtk4-macos.css|"$WALLBASH_SCRIPTS/gtk4-adw.py"\n'
              f"/* Gerado por gerar-macos-dcol.py a partir de {a.tema}/gtk-4.0"
              f" ({a.variante}).\n"
              "   Nao edite: rode o gerador de novo. */\n")
    Path(a.saida).write_text(cabeca + corpo, encoding="utf-8")

    n = len(COR.findall(css))
    print(f"{a.saida}: {len(corpo)//1024} KB, {n} literais de cor reescritos")
    return 0


if __name__ == "__main__":
    sys.exit(main())
