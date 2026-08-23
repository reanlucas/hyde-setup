<div align="center">

# hyde-setup

**Post-install setup for [HyDE](https://github.com/HyDE-Project/HyDE) on Arch.**

```
Arch minimal  →  HyDE  →  hyde-setup
```

Automates what HyDE leaves out: extra packages, a local LLM with GPU
acceleration, two custom modules, Portuguese accents on a US keyboard, monitor
setup and app integrations.

</div>

---

## The result

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
  <p><em>It all comes from the same wallbash. A theme switch repaints the bar, the
  desktop widgets and the LLM sidebar together &mdash; light themes included.</em></p>
</div>

---

## Installation

### 1. Base

Arch Linux with [HyDE](https://github.com/HyDE-Project/HyDE) already installed.
This repository **runs afterwards** — it assumes a working Hyprland and
`~/.config/hypr` in place.

### 2. Clone

```bash
git clone https://github.com/reanlucas/hyde-setup.git
cd hyde-setup
```

### 3. First run — generates the config

```bash
./install.sh
```

Creates `setup.conf` from the example and stops, applying nothing.

### 4. Fit it to your hardware

```bash
$EDITOR setup.conf
```

The minimum to review:

| Key | How to find it |
|---|---|
| `MONITOR_SAIDA` `MONITOR_MODO` | `hyprctl monitors` |
| `MONITOR_ESCALA` | the division must come out whole — `2560/1.25 = 2048` ✅ |
| `GPU_VENDOR` `OLLAMA_PACOTE` | `amd` → `ollama-rocm`, otherwise `ollama` |
| `OLLAMA_MODELO` | must fit in your VRAM |
| `KB_VARIANT` | `intl` or `altgr-intl` — see below |

### 5. Apply

```bash
./install.sh
```

Idempotent: running it again reapplies without duplicating. To rerun a single
stage:

```bash
./install.sh 20
```

### 6. Afterwards

```bash
hyde-widgets --show     # desktop widgets
hyde-ai --setup         # chat API keys
```

---

## The stages

| Stage | Contents |
|---|---|
| `10-pacotes` | HyDE extras, tooling, `ollama` tuned for the GPU, first model |
| `20-hyprland` | monitor, keyboard, keybinds, autostart and Spotify in the tray |
| `30-teclado` | `~/.XCompose` so `'` + `c` gives ç |
| `40-apps` | Spotify flags, spicetify, `Ctrl+C`/`Ctrl+V` in kitty, VS Code theme, waybar scale, Vulkan |
| `50-modulos` | clones and installs `hyde-widgets` and `hyde-ai` |

---

## Keyboard

Two options, both on top of the US layout:

| | `intl` | `altgr-intl` |
|---|---|---|
| `'` `"` `` ` `` `~` | dead keys | **plain** |
| Accent | `'` + `a` = á | `AltGr` + `'` + `a` = á |
| Cedilla | `'` + `c` = ç ¹ | `AltGr` + `,` = ç |
| Writing code | quotes get in the way | no friction |

¹ needs the `~/.XCompose` that stage `30` installs — xkb on its own maps
`'` + `c` to `ć`, a letter Portuguese does not have.

---

## Decisions worth explaining

<details>
<summary><b>The user override, never HyDE's own files</b></summary>

Everything is written to `~/.config/hypr/hyprland.lua`, which HyDE does not
overwrite on update. The block is delimited by markers and rewritten whole on
every run, which is what keeps the script idempotent.

</details>

<details>
<summary><b>cm = "srgb", not "hdr"</b></summary>

Turning HDR on maps SDR content to a ~80-nit reference and **darkens** the
desktop — the opposite of what you'd expect. It only pays off with real HDR
content.

</details>

<details>
<summary><b>The scale has to land on whole pixels</b></summary>

`2560 / 1.25 = 2048` works. `2560 / 1.3` doesn't divide evenly, and the result
is blurry text.

</details>

<details>
<summary><b>git url.insteadOf for https</b></summary>

Several PKGBUILDs clone over `http://`, which corporate networks block — `paru`
then hangs with no error message. Stage `10` configures the rewrite.

</details>

<details>
<summary><b>HyDE's <code>Shift+F11</code> looks broken, and isn't</b></summary>

The stock bind cycles **three** states: `0` → `1` (maximise) → `2`
(fullscreen). In a tiling layout state `1` is visually identical to the window
already tiled, so the first press changes nothing on screen — fullscreen only
arrives on the second, and leaves on the third.

Stage `20` swaps it for a straight toggle, in and out on one key:

```lua
hl.bind("SHIFT + F11", hl.dsp.window.fullscreen(), { ... })
```

Since the user override loads after HyDE and the *flags* match, the bind is
replaced rather than duplicated. `SUPER + F` is bound to the same thing, for
keyboards whose F-row sends media keysyms.

</details>

<details>
<summary><b><code>Ctrl+C</code> in the terminal without losing SIGINT</b></summary>

kitty uses `copy_or_interrupt`, not `copy_to_clipboard`: with a selection it
copies, without one it sends the usual `SIGINT`. Mapping it straight to copy
would take away the key's most frequent job in a terminal.

`Ctrl+Shift+C` and `Ctrl+Shift+V` keep working.

</details>

<details>
<summary><b>Spotify in the tray without <code>--minimized</code></b></summary>

Spotify's `--minimized` **does not work on Linux** — `spotify --help` says so
itself: "Only works on Windows". On Hyprland the window rule is what minimises:
the client starts with the session and goes straight to the scratchpad, without
stealing focus or taking a workspace.

```lua
hl.window_rule({
    match            = { class = "^([Ss]potify)$" },
    workspace        = "special silent",
    no_initial_focus = true,
})
```

`SUPER + S`, HyDE's own bind, reveals the window. The tray icon and the player
widget drive playback without it.

A `.desktop` in `~/.config/autostart` wouldn't help either: Hyprland does not
fire `xdg-desktop-autostart` on its own.

</details>

<details>
<summary><b>Ollama tuning</b></summary>

Flash attention, `q8_0` KV cache and a 32k context — all of it fitting on the
GPU. Without this the context stays at the default 4096, which is not much.

</details>

---

## What this repository guarantees — and what it doesn't

Running `install.sh` on a fresh Arch with HyDE reproduces **every setting** on
this machine: monitor, accented keyboard, keybinds, autostart, Spotify in the
tray, kitty, VS Code, waybar scale, Ollama and both modules. The scripts are
idempotent and were tested writing into a throwaway `HOME`.

What is **not** under this repository's control:

| | |
|---|---|
| Package versions | nothing is pinned; installing today gets what the repos hold today |
| HyDE themes | they come from HyDE's installer, not from here |
| API keys | deliberately left out — `hyde-ai --setup` asks later |
| The Ollama model | a few GB of download |
| Different hardware | `setup.conf` needs editing; the example carries this machine's values |

---

## Modules

| | |
|---|---|
| [hyde-widgets](https://github.com/reanlucas/hyde-widgets) | desktop widgets in Quickshell |
| [hyde-ai](https://github.com/reanlucas/hyde-ai) | LLM chat in a sidebar · **beta** |

---

## Licence

MIT
