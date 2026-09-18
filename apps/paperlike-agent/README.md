# PaperlikeAgent — native macOS POC for DASUNG

**Main job: remove macOS dithering on the e-ink panel.** macOS
enables `enableDither` on every framebuffer; on e-ink this shows up as
grain, blotches and a dark image. The agent resets this property to `false`
on Paperlike outputs only, on every two-second cycle, because macOS
restores it on reconnect, wake or mode change. This is
exactly what the official client does with its `disableDitheringTimer` — and
why closing its window with the close button brought the defect back.

This setting is applied **regardless of mode**: it is an IOKit property
write on the framebuffer and never touches the USB port. The built-in
panel is deliberately excluded: removing dithering there would cause banding.
Mechanism, evidence and measurements: [RESEARCH.md](RESEARCH.md).

**Multiple Paperlike monitors.** Every Paperlike output is handled, each
independently: the 253s by their DASUNG EDID (`0x1263`), the 13K by its
scaler's Realtek EDID (`RTK FHD`, vendor `0x4A8B`, product 447 — matched on
both, never on the Realtek vendor alone). A black-and-white 253, a Revo
Color and a 13K plugged in together are covered with no configuration. Do
not identify two 253s by their `ProductName`, which is identical on both;
use `SerialNumber` and `YearOfManufacture`.

**Hotplug.** The agent subscribes to
`CGDisplayRegisterReconfigurationCallback` and re-applies anti-dithering as soon as
a reconfiguration ends, then at 0.15 s, 0.4 s and 1 s — macOS sometimes sets
`enableDither` right after the framebuffer appears. The two-second
timer remains the safety net if the callback is refused, which
`paperlike status` reports as `reconfigurationCallbackRegistered: false`.

**Gamma table monitoring.** `paperlike status` exposes a `gamma` field
per DASUNG output (`ceiling`, `maxDeviation`), and the agent logs an error
as soon as a table stops being linear. It is the most destructive host-side setting
for e-ink — a ceiling below `1.0` crushes all grey levels, which
*are* the image — and it is invisible in Display Settings. Typical
cause: BetterDisplay's software brightness on a monitor without hardware
control. **Reported, never corrected**: the agent writes only one property, on the
framebuffers of a single manufacturer, and fighting another tool over the gamma table
would undo that guarantee.

**Display sleep and system sleep are two distinct cases.** Turning off a monitor
or letting it go to sleep emits no `NSWorkspace` notification: the agent does not
pause, its timer keeps running, and turning the display back on is covered by the
timer as well as by the reconfiguration callback. This is the common case with these
monitors. Only Mac sleep emits `willSleep`/`didWake`: the agent then suspends
its timer, and `didWake` triggers an immediate cycle.

A Swift agent with no icon in the Dock, Cmd-Tab or the menu bar, which never
takes focus. Its only windows are the HUD shown briefly after a
shortcut and the full-screen flash of `clear` (see below). **By default it applies anti-dithering and observes the presence of the DASUNG
and its USB link, without opening the port.** Control mode, which is separate, validates the
MCU, keeps the connection alive, and serves the CLI and global shortcuts. USB
control is not needed for anti-dithering: both modes apply it.

The hardware observed on this Mac: a **Paperlike 253 Color** (macOS name
`Paperlike253`, MCU `0x30`) and a **Paperlike 13K Color** (macOS name
`RTK FHD`, 3200 × 2400, MCU `0x31`), each with its own CH340 `1a86:7523`.
Both speak the same protocol and expose the same settings. The POC does not
validate every DASUNG model. See [RESEARCH.md](RESEARCH.md).

## Installation and commands

From `~/code/mac-setup`, with Apple's developer tools installed:

```sh
make paperlike-test       # Tests without sending any command to a display
make paperlike           # Build, install and start detection at login
paperlike status
```

The application is installed in `~/Applications/PaperlikeAgent.app`.
It is built natively for the Mac in use, with no external dependencies.
Ad hoc signing is fine for this local use; it is not a signed and
notarized distribution for other users.

Default mode can coexist with the official client: both write the same
property with the same value. It reserves a single shortcut,
Ctrl+Opt+Cmd+C (`clear`, below), which needs no USB.
`paperlike status` exposes `ditheringReasserts`, the number of times macOS
re-enabled dithering and the agent removed it. After diagnostics and visual validation, `make paperlike-control`
enables USB control at login. **The agent then takes exclusive hold of the CH340
port: PaperLikeClient will no longer be able to open it while the agent runs.**
To go back to anti-dithering only and hand the port back to the client: `make paperlike`.

In control mode, **Control + Option + Command + R** sends a
Ghost Cleanup request from any application.
This combination does not include Shift, so it does not replace Hyper+R.
The agent uses `RegisterEventHotKey`: it does not listen to keystrokes and does not request
Accessibility permission. A shortcut conflict is reported in
`paperlike status` (`hotkeys[].registered: false`).

### Clearing ghosting without USB

`paperlike clear` (**Ctrl+Opt+Cmd+C**) covers the panel in black, then
white, for 0.3 s each, then lets it redraw the desktop. Every pixel goes
through its full range, an approximation of the monitor's own Ghost Cleanup.
It is drawn by the Mac, so it needs **no USB link** and works in both modes:
it is the only cleanup available for a Paperlike connected by HDMI alone.

It clears the Paperlike under the pointer; from any other display, every
Paperlike (`paperlike 13k clear` narrows it to one). No HUD follows it — the
flash is its own feedback, and a panel drawn right after would leave a new
ghost. `paperlike refresh` remains the monitor's own Ghost Cleanup, sent
over USB.

### Several Paperlike monitors

Each Paperlike with its USB cable gets its own CH340 port, and the agent
drives all of them at once. A port becomes a link only after answering a
supported MCU; register `0x13` then gives the model (the official client's
table: 1 13K Color, 2 13K, 3 103, 4 253, 5 253 Color). The model is what
pairs a port with its screen — 13K ↔ Realtek EDID, 253 Color ↔ DASUNG
product `0x253C`, the other models ↔ any other DASUNG product — since USB
and video take separate paths through a dock.

A command or shortcut acts on **the Paperlike under the pointer**, as `clear`
and the HUD do (AeroSpace moves the pointer with monitor focus). From
another screen it acts on the only Paperlike under control whose screen is
connected — a USB cable plugged in alone is set aside; with several, it
is refused — the HUD says "Point at the one to adjust" — rather than
guessed. Naming the monitor first overrides the pointer:

```sh
paperlike 13k light on
paperlike 253 contrast +1
paperlike 13k query      # MCU, model and every setting of that monitor
```

Accepted names: `13k`, `253`, `103`, and `13k-color`, `13k-bw`,
`253-color`, `253-bw` when two of one family are connected. A shortcut can
name its monitor too: `{"keys": "ctrl+alt+cmd+1", "action": ["13k", "light", "toggle"]}`.
The light mode restored by "light on" is remembered per monitor.

### Display settings (control mode)

Every setting of the official client is exposed, with its bounds. A signed value
acts **relatively** (`paperlike light +10`), which is what a shortcut
needs. **Every write is confirmed by register read-back**: without
confirmation, the command fails instead of claiming it succeeded — this is
precisely the failure mode encountered with the proprietary client.

| Command | Bounds | Setting |
| --- | --- | --- |
| `paperlike contrast` | 1–9 | Contrast |
| `paperlike mode next\|<name>` | — | Display mode: cycle, or text / image / web / active (auto on the 103) |
| `paperlike speed` | 1–5 | Refresh speed |
| `paperlike light on\|off\|toggle` | — | Front light: on / off |
| `paperlike light-mode` | 0–3 | Front light: 0 off |
| `paperlike light` | 0–100 | Front light: brightness (0 off) |
| `paperlike light-temp` | 0–100 | Front light: temperature |
| `paperlike text-enhance` | 0–1 | Text enhancement |
| `paperlike refresh` | — | Ghost Cleanup |
| `paperlike read 09` | — | Read a raw register (diagnostic) |

Front light brightness behaves **like a brightness key**: 0 means
off. From the light being off, `light +10` (Ctrl+Opt+Cmd+↑) turns it on
at the first step, 10%; going down to 0 really turns it off, instead of
leaving it on at zero. Because the monitor ignores brightness while the light is off,
turning it on briefly passes through the last stored level first.
`paperlike light on` (Ctrl+Opt+Cmd+L) restores the last light mode used, remembered across
agent restarts; to choose one, run `paperlike light-mode 1..3`
once. If brightness is 0 at that point, it is raised to 20 so that
turning the light on is visible.

Each model has four display modes, whose register values differ: the 253
Color cycles image 3, active 4, web 5, text 2, and the black-and-white 253
the same without web, which it refuses; the 13K web 6 (read back as 1),
text 2, image 3, active 7; the 103 auto 5, text 2, image 3, active 7 (the official client's
tables and order, see RESEARCH.md). `mode next` follows that order; a value
outside the table restarts at the first mode. A monitor whose model is
unknown is refused.

The light mode is a temperature preset: writing mode 1 reads back a
temperature of 100, and writing any temperature switches the light to mode 3,
the custom one (observed on the 13K).

A setting takes about 0.1 s: read, write, read-back; turning the light on or
off takes a little longer, because the monitor ignores a read-back sent right
after, which is then re-sent 0.2 s later. Rapid presses of the same
shortcut are merged into a single write.

### Keyboard shortcuts

On Control+Option+Command ("Meh", without Shift, so Hyper stays free). All
are active in control mode; default mode registers only `clear`, the one that
needs no USB. The arrows are chosen on purpose: their key codes do not change
from one layout to another, which a letter does not guarantee on AZERTY.

| Shortcut | Action |
| --- | --- |
| `Ctrl+Opt+Cmd+R` | Ghost Cleanup, over USB |
| `Ctrl+Opt+Cmd+C` | Clear by flashing the panel, no USB (both modes) |
| `Ctrl+Opt+Cmd+L` | Turn the front light on / off |
| `Ctrl+Opt+Cmd+M` | Next display mode (the AZERTY M key: `semicolon` in the config) |
| `Ctrl+Opt+Cmd+↑ / ↓` | Front light brightness ±10 |
| `Ctrl+Opt+Cmd+→ / ←` | Contrast ±1 |

`R`, `L` and `C` are in the same position on AZERTY and QWERTY. `M` is not: key names are ANSI positions, and the key printed M on AZERTY is
the ANSI `semicolon` key (ANSI `m` types a comma there), hence `ctrl+alt+cmd+semicolon`. `paperlike status` lists
each shortcut with its registration state: otherwise, a shortcut already taken by another
application fails silently.

### HUD

After each shortcut but `clear`, a small panel appears for 2 s at the top right of the
display under the pointer, like the macOS brightness one: setting,
value (`40%`, `3 / 9`), a gauge with one segment per step, and **`Max` / `Min`**
at the limit. The display mode shows every mode of that monitor by name, the
current one inverted, so the next press is predictable. It shows only the
response of the command that just succeeded, with no extra serial exchange.

It is drawn for e-ink, black-and-white and colour: opaque, black on white,
with no shadow, animation or accent colour — every frame of a fade would be
one more partial refresh, and a colour lands washed out through a colour
filter. Outlines are 2–3 pt and drawn without antialiasing, whose grey fringe
shows as speckle; the type is large and bold. On the
panel, its appearance and disappearance still cost two small
refreshes, and may leave ghosting that Ctrl+Opt+Cmd+R or C clears.
The panel is non-activating and ignores the mouse: focus stays on the current
window. `"hud": false` in the configuration disables it.

### Optional customization

File read **once at startup**, absent by default:
`~/.config/paperlike/config.json`

```json
{ "hotkeys": [
    { "keys": "ctrl+alt+cmd+up", "action": ["light", "+10"] },
    { "keys": "ctrl+alt+cmd+t",  "action": ["text-enhance", "1"] }
  ],
  "hud": true }
```

No file watching, no reloading, no settings window:
the agent remains a background process. A missing or unreadable file
yields the default values and **the agent starts anyway** — anti-dithering,
its only essential function, never depends on this file. Configuration
errors appear in `paperlike status`.

```sh
paperlike detect         # Display / USB presence, without opening the port
paperlike status         # Connection, process, shortcut, latest responses
paperlike query          # Read back the MCU, the model and every setting
paperlike refresh        # Ghost Cleanup, over USB
paperlike clear          # Flash black then white, no USB needed
paperlike contrast 3     # Value from 1 to 9
paperlike speed 4        # Value from 1 to 5
```

These commands can also be used in a Shortcuts "Run Shell Script" action
or a Raycast script. If the PATH is reduced there, use for example:

```sh
"$HOME/.local/bin/paperlike" refresh
```

Output is JSON, with a non-zero exit code on error. For a
setting, `confirmed_by_readback` means the display returned the requested
value. For a cleanup, `acknowledged_by_device` confirms it was received,
not its visual result. `sent` only means the write succeeded.
`status.ok` concerns diagnostics; check `state: connected` for the link.

## Startup and returning to the official client

The user LaunchAgent is registered in
`~/Library/LaunchAgents/com.user.paperlike-agent.plist`. It starts at **login**,
without a terminal, and is relaunched after a crash. No root service
or kernel extension is added. `LSUIElement` and a `prohibited` activation
policy keep the application out of the Dock and Cmd-Tab; `paperlike
status` checks `takesFocus: false`. The local socket and its lock
prevent two instances from driving the display at the same time.

A LaunchAgent fits the way this configuration repo works.
For a distributed application with a preferences UI, one would rather
choose `SMAppService` (macOS 13+) to manage login from within the application.
The POC remains an optional module: `make install` / `make update` do not enable it.

```sh
make paperlike-stop      # Stop and disable launch at login
open -a PaperLikeClient  # Back to the DASUNG software
```

To resume observation, run `make paperlike`; the official client can
stay open. Replacing the official client follows the control procedure
described above, after diagnostics and visual validation.
To remove the application and its LaunchAgent:

```sh
make paperlike-uninstall
```

The sources, the build cache and the repo command remain in place.
If this display variant depends on the keepalive, its image may disappear
when all clients are stopped; reopening PaperLikeClient restores its role.

In control mode, the agent waits if PaperLikeClient, PaperlikeMenu or InkControl is open.
Disable "Launch at Startup" in the official client when replacing it,
so that it does not take over at the next login. It can still be
reopened manually. No uninstallation of the DASUNG client is needed.

## Diagnostics and limitations

- A detected video display does not prove the USB control link. The cable must
  also carry USB data; HDMI alone is not enough.
- Selection: a Paperlike on screen, then every CH340 `1a86:7523`, each asked
  for its MCU — a read that changes nothing — and kept only on a recognized
  reply. This VID/PID is generic: a CH340 that is not a Paperlike only ever
  receives that read, repeated every 10 s, never a setting. Other serial
  ports are not scanned.
- Reconnection every two seconds, port closed during sleep,
  re-identification on wake. Sleep/wake, physical unplugging
  and real login tests are still to be done — including unplugging one of two
  monitors while the other stays under control; the links were only ever
  recreated together, by restarting the agent.
- Serial operations are serialized and time-bounded; a read
  returns as soon as its response arrives, the timeout only applies on failure.
  Fragmented or coalesced USB responses are reassembled. A write followed by a
  missing response is reported as unconfirmed, never as a success.
- Every setting the official client drives is exposed; the real-time clock
  (`0x05`) and the model identifier (`0x13`) are never writable, which a test
  enforces. Beyond `enableDither` on Paperlike outputs, the POC does not modify
  any global macOS graphics setting.
- Before the Mac message `0x20/1`, the POC checks that `enableDither` is indeed `No`
  for every observed Paperlike output. If this state is missing or enabled, it refuses
  to send. This check corrects an assumption from the first attempt; on its own it does not
  demonstrate the cause of the reported display problem.
- Shortcuts are redefined in `~/.config/paperlike/config.json`, read again
  only when the agent starts (`make paperlike-control` to restart it).

Connection transitions and errors are in the macOS unified log:

```sh
log show --last 10m --predicate 'subsystem == "com.user.paperlike-agent"'
```

The command channel is a Unix socket restricted to the user, in
`~/Library/Application Support/PaperlikeAgent/`. The application uses no network server,
telemetry or downloads.
