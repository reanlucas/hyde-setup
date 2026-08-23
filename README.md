<div align="center">

# hyde-setup

**Pós-instalação pessoal do [HyDE](https://github.com/HyDE-Project/HyDE) no Arch.**

```
Arch minimal  →  HyDE  →  hyde-setup
```

Automatiza o que fica de fora do HyDE: pacotes extras, LLM local com aceleração
de GPU, dois módulos próprios, teclado com acentuação portuguesa, monitor e
integrações de aplicativo.

</div>

---

## O resultado

<div align="center">
  <img src="docs/desktop.gif" width="860" alt="The finished desktop running: Spotify plays from the tray while the audio visualiser and the metric charts move">
  <p><em>What the five stages add up to. Spotify is playing from the tray &mdash;
  it started with the session and never took a workspace.</em></p>
</div>

<div align="center">
  <img src="docs/desktop.png" width="820" alt="Finished desktop after running hyde-setup: HyDE bar on top, clock and weather widgets on the left, CPU/GPU/memory panels on the right, music player and audio visualiser at the bottom">
</div>

<div align="center">
  <img src="docs/temas.gif" width="860" alt="Three HyDE themes applied one after another; the wallpaper, the bar, the desktop widgets and the AI sidebar all recolour together, light themes included">
  <p><em>Tudo sai do mesmo wallbash. Trocar de tema repinta a barra, os widgets e
  a barra lateral de LLM juntos &mdash; inclusive nos temas claros.</em></p>
</div>

---

## Instalação

### 1. Base

Arch Linux com o [HyDE](https://github.com/HyDE-Project/HyDE) já instalado.
Este repositório **roda depois** — assume Hyprland funcionando e
`~/.config/hypr` no lugar.

### 2. Clonar

```bash
git clone https://github.com/reanlucas/hyde-setup.git
cd hyde-setup
```

### 3. Primeira execução — gera a configuração

```bash
./install.sh
```

Cria o `setup.conf` a partir do exemplo e para, sem aplicar nada.

### 4. Ajustar ao seu hardware

```bash
$EDITOR setup.conf
```

O mínimo a revisar:

| Chave | Como descobrir |
|---|---|
| `MONITOR_SAIDA` `MONITOR_MODO` | `hyprctl monitors` |
| `MONITOR_ESCALA` | a divisão precisa dar inteiro — `2560/1.25 = 2048` ✅ |
| `GPU_VENDOR` `OLLAMA_PACOTE` | `amd` → `ollama-rocm`, senão `ollama` |
| `OLLAMA_MODELO` | precisa caber na sua VRAM |
| `KB_VARIANT` | `intl` ou `altgr-intl` — veja abaixo |

### 5. Aplicar

```bash
./install.sh
```

Idempotente: rodar de novo reaplica sem duplicar. Para reexecutar só uma etapa:

```bash
./install.sh 20
```

### 6. Depois

```bash
hyde-widgets --show     # widgets do desktop
hyde-ai --setup         # chaves de API do chat
```

---

## As etapas

| Etapa | Conteúdo |
|---|---|
| `10-pacotes` | extras do HyDE, ferramentas, `ollama` com ajuste de GPU, modelo inicial |
| `20-hyprland` | monitor, teclado, atalhos, autostart e Spotify na bandeja |
| `30-teclado` | `~/.XCompose` para `'` + `c` = ç |
| `40-apps` | flags do Spotify, spicetify com as cores do tema, Vulkan |
| `50-modulos` | clona e instala `hyde-widgets` e `hyde-ai` |

---

## Teclado

Duas opções, ambas sobre layout americano:

| | `intl` | `altgr-intl` |
|---|---|---|
| `'` `"` `` ` `` `~` | dead keys | **normais** |
| Acento | `'` + `a` = á | `AltGr` + `'` + `a` = á |
| Cedilha | `'` + `c` = ç ¹ | `AltGr` + `,` = ç |
| Programar | atrito com aspas | sem atrito |

¹ exige o `~/.XCompose` que a etapa `30` instala — o xkb sozinho mapeia
`'` + `c` para `ć`, letra que não existe em português.

---

## Decisões que valem explicar

<details>
<summary><b>O override do usuário, nunca os arquivos do HyDE</b></summary>

Tudo é escrito em `~/.config/hypr/hyprland.lua`, que o HyDE não sobrescreve nas
atualizações. O bloco é delimitado por marcadores e reescrito por inteiro a
cada execução, o que mantém o script idempotente.

</details>

<details>
<summary><b>cm = "srgb", não "hdr"</b></summary>

Ligar HDR mapeia o conteúdo SDR para ~80 nits de referência e **escurece** o
desktop — o oposto do esperado. Só vale com conteúdo HDR de verdade.

</details>

<details>
<summary><b>A escala precisa dar pixel inteiro</b></summary>

`2560 / 1.25 = 2048` funciona. `2560 / 1.3` não dá inteiro, e o resultado é
texto borrado.

</details>

<details>
<summary><b>git url.insteadOf para https</b></summary>

Vários PKGBUILDs clonam por `http://`, bloqueado em redes corporativas — o
`paru` trava sem mensagem de erro. A etapa `10` configura a reescrita.

</details>

<details>
<summary><b>Spotify na bandeja sem <code>--minimized</code></b></summary>

O `--minimized` do Spotify **não funciona no Linux** — o próprio
`spotify --help` diz "Only works on Windows". No Hyprland quem minimiza é a
regra de janela: o cliente sobe com a sessão e vai direto para o scratchpad,
sem roubar o foco nem ocupar workspace.

```lua
hl.window_rule({
    match            = { class = "^([Ss]potify)$" },
    workspace        = "special silent",
    no_initial_focus = true,
})
```

`SUPER + S`, que é do próprio HyDE, mostra a janela. O ícone da bandeja e o
widget de player controlam a reprodução sem precisar dela.

Um `.desktop` em `~/.config/autostart` também não serviria: o Hyprland não
dispara o `xdg-desktop-autostart` por conta própria.

</details>

<details>
<summary><b>Ajuste do Ollama</b></summary>

`flash attention`, cache KV em `q8_0` e contexto de 32k — tudo cabendo na GPU.
Sem isso o contexto fica no padrão de 4096, que é pouco.

</details>

---

## Módulos

| | |
|---|---|
| [hyde-widgets](https://github.com/reanlucas/hyde-widgets) | widgets de desktop em Quickshell |
| [hyde-ai](https://github.com/reanlucas/hyde-ai) | chat com LLM na barra lateral · **beta** |

---

## Licença

MIT
