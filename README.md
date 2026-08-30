<div align="center">

# hyde-setup

**Post-install setup for [HyDE](https://github.com/HyDE-Project/HyDE) on Arch.**

```
Arch minimal  →  HyDE  →  hyde-setup
```

Automates what HyDE leaves out: every published HyDE theme and extra package,
a local LLM with GPU acceleration, two custom modules, Portuguese accents on a
US keyboard, monitor setup and app integrations.

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
| `CORECTRL_RESTORE_PROFILE` | `1` restores this machine's RX 7900 XT profile; use `0` on another GPU |
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
hyde-spotify --show     # reveals the running Spotify window
hyde-ai --doctor        # checks the Hypr-IA backend and its Ollama venv
```

---

## The stages

| Stage | Contents |
|---|---|
| `10-pacotes` | tooling, `ollama` tuned for the GPU, first model |
| `15-hyde-assets` | every active HyDE extra and every theme in the supported gallery |
| `20-hyprland` | monitor, keyboard, keybinds, autostart and Spotify in the tray |
| `30-teclado` | `~/.XCompose` so `'` + `c` gives ç |
| `40-apps` | verified Spotify launcher, Spicetify with stock-client recovery, `Ctrl+C`/`Ctrl+V` in kitty, VS Code theme, waybar scale, Vulkan |
| `45-nautilus` | Nautilus, gvfs, thumbnails, kitty in the context menu, and the MacOS theme recoloured by wallbash |
| `50-modulos` | installs `hyde-widgets`, `hyde-ai` and `hypr-ia`, verifies the Spotify widget in the active Waybar layout, configures the selected Ollama model, then runs a final doctor |
| `55-energia` | never lock or suspend on idle; the screen alone goes off |
| `60-corectrl` | CoreCtrl only: restores this machine's AMD profile, adds `amdgpu.ppfeaturemask=0xffffffff` to the UKI cmdline, installs a user-scoped Polkit rule, disables conflicting daemons, and starts CoreCtrl in the tray |
| `65-jogos` | CS2 and friends: real fullscreen, direct scanout, tearing allowed |

<details>
<summary><strong>Idle: the screen goes off, the machine does not</strong></summary>

HyDE ships four `hypridle` listeners: dim at 60s, `loginctl lock-session` at
120s, DPMS off at 300s, `systemctl suspend` at 500s. Stage 55 rewrites that
section and keeps only the DPMS one. The lock and suspend listeners are not
pushed out to a large timeout -- they are simply not written, so there is no
value to wait out.

What stays is the `general` block, with `lock_cmd` and `unlock_cmd` intact:
manual locking (`loginctl lock-session`, and HyDE's bind) still works. The
change is about the automatic triggers only.

`systemd-logind` has an idle action of its own, so the stage also drops
`/etc/systemd/logind.conf.d/90-hyde-setup-energia.conf` with
`IdleAction=ignore`. The default already is `ignore`, but writing it down
means a systemd update cannot reintroduce a suspend from behind.

The rewrite is idempotent in both directions: it strips its own delimited
block *and* every `listener` block it finds, so if a HyDE update restores the
stock file, running the stage again cleans it out. `~/.config/hypr/hypridle.conf`
is backed up with a timestamp on each run.

</details>


<details>
<summary><strong>CS2 has no "Fullscreen" option, and that is not a bug</strong></summary>

The display-mode dropdown offers only Windowed and Fullscreen Windowed. The
reason is in Valve's own launcher, `game/cs2.sh`:

```sh
# There is Wayland support in SDL but a recent (7/30/2025) attempt at
# allowing SDL to default to Wayland caused a number of customer issues so
# keep the default at X11 for now.
if [ -z "$SDL_VIDEO_DRIVER" ]; then
    export SDL_VIDEO_DRIVER=x11
fi
```

So CS2 is an X client on XWayland, and XWayland cannot change the display
mode — `xrandr` says so itself the moment you run it against one. Exclusive
fullscreen *is* a mode change, so there is nothing for the option to do.
Fullscreen Windowed is the correct mode here.

What was missing is the borderless window behaving like the exclusive one.
Stage 65 writes a window rule that does exactly that:

- `fullscreen` — the window covers the screen, waybar included. Once it is
  fullscreen and alone on its workspace, Hyprland hands the game's buffer
  straight to the display (direct scanout, `hyprctl monitors` calls it
  `solitary`), skipping composition entirely. That is what exclusive
  fullscreen buys you, and here it comes from the compositor.
- `content = "game"` + `immediate`, with `general.allow_tearing` on — real
  vsync-off tearing, which is the point on a high-refresh panel.
- `idle_inhibit = "fullscreen"` — covers the gap stage 55 opens: with the
  screen set to blank on idle, standing still on a bombsite would black out
  the monitor.
- `no_blur` / `no_anim` / `no_shadow` / `no_dim` / `rounding 0` /
  `border_size 0` — no compositor work on a surface that is about to be
  scanned out.

The rule keys were checked one by one against the live compositor with
`hyprctl eval 'hl.window_rule({...})'` rather than guessed: `no_rounding` and
`no_border` are layer-rule-only and are rejected for windows, which is why the
rule uses `rounding = 0` and `border_size = 0`. Hyprland refuses the *whole*
config file when the Lua does not compile — taking every keybind with it — so
the stage backs the file up, reloads, checks `hyprctl configerrors`, and
restores the backup if anything came back.

If you specifically want the in-game option back rather than the effect,
`gamescope` is the way: it is a nested compositor with a real display of its
own, so the game can modeset inside it. As a Steam launch option:

```
gamescope -W 2560 -H 1440 -r 360 -f -- %command%
```

That is not the default here — it adds a compositing step in front of a path
whose whole point is not having one.

</details>

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
<summary><b>Nautilus: the MacOS theme, recoloured by wallbash</b></summary>

HyDE already themes GTK4: on a theme switch it points `~/.config/gtk-4.0` at
`<theme>/gtk-4.0`, and GTK loads that `gtk.css` as *user* CSS, outranking
libadwaita's own sheet. libadwaita 1.6 moved its colours to CSS variables but
kept a compatibility layer — its `:root` sets `--window-bg-color:
@window_bg_color` — so a theme's `@define-color` still reaches the variable.
Nautilus therefore comes up almost fully themed with no help at all. I assumed
the opposite until I measured it.

Two things don't reach it:

**The colours the themes never declared.** Of the 48 themes with a `gtk-4.0`
directory here, 44 define none of the `@sidebar_*` family — and in a file
manager the sidebar is half the window, sitting in Adwaita's grey `#2E2E32`
against a themed window. About half define **none** of the 42, dropping to
stock Adwaita entirely.

**The shape.** No HyDE theme has the sidebar-pane-detached-from-content look
that makes a Finder window read as one.

The MacOS theme has the shape, but its colours are nailed down: 1203 literals,
including `.sidebar { background-color: #333333 }`, so redefining
`@define-color` does nothing. `gerar-macos-dcol.py` rewrites the stylesheet
instead, turning each literal into a wallbash token, and emits it as a template
in `always/` — which HyDE re-renders on every theme change, like its own.

Each colour is classified before being replaced: greys (saturation under 12%)
go to the group-1 ramp, the wallpaper's dominant colour; blues (hue 190–260,
the theme's accent family) go to the group-4 ramp, HyDE's accent; red, green
and orange are left alone, because error and success shouldn't become shades of
the wallpaper. Position on the ramp comes from luminance *rank*, not absolute
value, so all nine steps are used whatever palette wallbash produces. And since
`#333333` (background) and `#373737` (hover) would land on the same step and
become the same colour — killing the hover — each one also carries a `shade()`
relative to its step's median.

**Transparency comes from the compositor, and one HyDE rule was blocking it.**
HyDE ships `filemanagers-fullscreen`, matching `.*Nautilus.*` with `opaque =
true` — which makes Hyprland skip opacity *and* blur for that window. While
that stands nothing shows through, from the compositor or from CSS alpha, and
the same rule forces `float = false` (dolphin escapes it by being in the
floating-class list). The window rule in stage 45 turns both off and sets
`opacity`.

It is uniform across the window. Making **only** the sidebar see-through is
what I could not do, and the honest record of it is: the sidebar renders
byte-identical over two completely different wallpapers, so it is fully opaque,
and none of the CSS routes changed that — alpha on `window.background`, on
`toolbarview`, on every sidebar class and their `:backdrop` twins, repeating the
theme's own high-specificity selectors to win on position, even resetting every
container and repainting one layer at a time. Two things did come out of the
search and are worth keeping: the theme's `.nautilus-window` rules are dead
weight on Nautilus 50, which no longer uses that class; and alpha painted on
nested widgets stacks, so the same 0.62 on `.sidebar`, `.sidebar-pane`,
`.navigation-sidebar` and `.sidebar list` composites to 0.98. Compositor opacity
is the lever that works, and it takes the whole window.

The 42 libadwaita variables are declared from the same palette, since the
MacOS port predates them. One bug of the theme's own is fixed on the way
through: four calls to `gtkmix()`, which is not a GTK4 function — GTK dropped
those rules with *Expected a valid color*. The output parses with zero errors,
which the untouched theme does not.

`gtk4-adw.py` runs as the template's `exec_command` and rebuilds
`~/.config/gtk-4.0` as a real directory — right after HyDE has recreated the
symlink. If the script ever disappears, the symlink comes back on the next
switch: what is lost is the patch, not the theme.

With `NAUTILUS_MACOS=0` the shape is left alone and only the missing colours
are filled in, from the active theme.

**A theme change recolours it; a wallpaper change does not** — not by itself.
HyDE ships `enableWallDcol=0`, which means the wallbash palette comes from the
theme's own `.dcol`, not from the current wallpaper. Measured: switching Rosé
Pine → Tokyo Night moved the palette from `#584268` to `#2A2A3A` and the
stylesheet followed; changing wallpaper inside a theme moved nothing. Set
`enableWallDcol=1` in `~/.config/hyde/config.toml` and the wallpaper drives it
too — for this and for everything else HyDE colours.

Since the user stylesheet is global to GTK4, this is the look every GTK4 app
gets, not only Nautilus. `GTK_THEME=<name>` does scope a theme to one app, but
the user stylesheet outranks it, so the scoped theme loses — verified.

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

`SUPER + S`, HyDE's own bind, reveals the window. Stage 40 also installs
`hyde-spotify` and a user-level desktop entry. Launching Spotify from an app
menu, a `spotify:` link, or the Waybar menu now reveals the already-running
scratchpad window instead of silently exiting with “Opening in existing browser
session”. After Spicetify finishes, the stage restarts Spotify and confirms
that it created a Hyprland window; if the patch broke startup, it restores the
stock client and retries.

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

Running `install.sh` on a fresh Arch with HyDE restores the tracked machine
configuration: monitor, accented keyboard, keybinds, autostart, Spotify in the
tray, kitty, VS Code, waybar scale, Ollama, both modules, all currently
published gallery themes, all active HyDE extras, and the CoreCtrl global
profile. The CoreCtrl stage also verifies its persistent boot parameter,
starts the application in the tray after Waybar, and authorizes only
`org.corectrl.helper.init` / `org.corectrl.helperkiller.init` for the local,
active installer user so the login no longer produces a password popup. The
scripts are idempotent;
an error now makes the top-level installer exit non-zero instead of reporting
a false success.

What is **not** under this repository's control:

| | |
|---|---|
| Package versions | nothing is pinned; installing today gets what the repos hold today |
| HyDE gallery | its catalog is upstream and may gain or retire themes; the run imports every entry available then |
| Renamed HyDE extras | `trash-cli-git` is transparently fulfilled by the current Arch package `trash-cli` |
| API keys | deliberately left out — they live with Hypr-IA (`/key` in the panel, or `~/.hypr-ia/.env`) |
| The Ollama model | a few GB of download |
| Different hardware | `setup.conf` needs editing; in particular set `CORECTRL_RESTORE_PROFILE=0` outside this RX 7900 XT |

---

## Modules

| | |
|---|---|
| [hyde-widgets](https://github.com/reanlucas/hyde-widgets) | desktop widgets in Quickshell |
| [hyde-ai](https://github.com/reanlucas/hyde-ai) | LLM chat in a sidebar · **beta** |

---

## Licence

MIT
