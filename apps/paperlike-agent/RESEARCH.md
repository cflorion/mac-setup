# Research and evidence — September 12, 2026

## Paperlike 13K: a second monitor, same protocol — September 13, 2026

A Paperlike 13K Color was added, over USB-C. Plugging it in cost **both**
monitors their USB control: a second CH340 appeared, and the agent refused
any selection as soon as there was more than one (see "Two DASUNG monitors"
below, whose single-adapter observation no longer holds).

### What macOS sees

| | 253 Color | 13K Color |
| --- | --- | --- |
| macOS name | `Paperlike253` | `RTK FHD` |
| EDID vendor / product | `0x1263` (DSC) / 0 | `0x4A8B` (RTK) / 447 |
| Mode observed | 3840 × 2160, 40 Hz | 3200 × 2400, 37 Hz |
| CH340 port | `/dev/cu.usbserial-2115410`, via the dock | `/dev/cu.usbserial-1120` |
| MCU (`0x10`) | `0x30` | `0x31` |
| Model (`0x13`) | 5 | 1 |

The 13K's video goes through a Realtek scaler that reports Realtek's generic
EDID — year 2010, name `RTK FHD` despite 3200 × 2400. Nothing in it says
DASUNG, so the 13K was invisible to anti-dithering, `clear` and the gamma
report, which all matched `0x1263`. It is now matched on vendor **and**
product (`0x4A8B`/447): the vendor alone would catch any monitor built on
that scaler family. Its framebuffer read `enableDither = No` when it was
plugged in; the agent now watches it like the others. The reassert path
itself has not been observed on the 13K: `ditheringReasserts` stayed at 0
during the session, so macOS never re-enabled dithering there to be undone.

Besides its CH340 (`1a86:7523`), the 13K's USB hub carries a CH341
(`1a86:5512`, "USB UART-LPT") and a WCH touch controller (`1a86:e5e3`,
"USB2IIC_CTP_CONTROL"). The agent uses neither.

### Register 0x13 is the model

It was recorded below as "unidentified". The client's reply dispatcher
stores it with `setDisplayVersionMode:`, and `DeviceDisplayNameForMode`
indexes a table of names by that value minus one (table at `0x100034248`; a
parallel one at `0x100034220` holds the Chinese names, picked by a language
flag):

| `0x13` | Client's name |
| --- | --- |
| 1 | PaperLike133K(Color) |
| 2 | PaperLike133K(B&W) |
| 3 | PaperLike103 |
| 4 | PaperLike253(B&W) |
| 5 | PaperLike253(Color) |
| other | PaperLike(Model%d) |

The observations match: 1 on the 13K Color, 5 on the 253 Color. The MCU is
not the model: the client only tests `0x30`/`0x31` to append
" [FrontLight]" to the name. `0x13` stays read-only.

The model is what pairs a CH340 with a screen: 13K models with the Realtek
EDID, the others with the DASUNG one. USB topology cannot do it — here the
253's CH340 hangs off the CalDigit dock while its video takes another path.

The client also decodes the display-mode register (`0x02`) per model
(`updateModeIndexFromValue:forDevice:`): values 2, 3 and 7 for the 13K
models, 2 to 5 for the 253 models. The agent's `mode` bounds (1–2) predate
this and were not revisited — an open item; read-back keeps every write
honest.

### Everything works on the 13K

Written, read back, then restored on the 13K: light off → on (level 30
restored), brightness 30 → 40 → 30, contrast 1 → 2 → 1, temperature, Ghost
Cleanup (`0x03`, acknowledged), and the flash `clear` on its screen alone.

### Front light: the mode is a temperature preset

On the 13K, the light mode and the temperature are one state:

| Write | Reads back |
| --- | --- |
| `light-mode 1` | mode 1, temperature **100** |
| `light-temp 70` | mode **3**, temperature 70 |

Modes 1 and 2 are presets that set the temperature themselves; 3 is the
custom temperature, which any temperature write selects. The client's
`updateViewFrontLightModeDisplay:` likewise singles out mode 3 when enabling
its controls. Consequence: the state read before any test — mode 1 with
temperature 70 — cannot be produced over USB; the 70 was presumably left over
from an earlier custom setting. The 13K was put back in mode 1 after the
tests, which reads 100. Not verified on the 253.

### Several monitors in the agent

- Once a Paperlike is on screen, every CH340 is asked for its MCU — a read,
  never a setting — and each port answering a supported MCU becomes a link,
  kept alive and health-checked on its own. A port that does not answer is
  asked again every 10 s rather than on every tick.
- The `0x20` frame is still gated on `enableDither = No` on **every**
  Paperlike output, the 13K included.
- A command acts on the Paperlike under the pointer, else on the only one,
  and is refused rather than guessed when several remain; `paperlike 13k …`
  names one. Checked with an unnamed `paperlike read 13`, the pointer warped
  onto each screen: the 13K answered 1, the 253 answered 5, and from the
  built-in panel the command was refused with `code: ambiguous`.
- The light mode restored by "light on" is remembered per model.

## Cause of the visual defect: gamma table crushed by BetterDisplay

**Two mistaken attributions preceded this one in this file. They are recorded
here, because each of them seemed solid.**

The defect — dark image, dirty colors, large black areas that flicker at the
slightest movement — was caused neither by the monitor, nor by its registers,
nor by macOS dithering. It came from the **output's gamma table**, crushed by
BetterDisplay's software brightness.

### The experiment that isolated it

The user opened a **fresh macOS user account** on the same Mac, with the same
monitor and the same cables: the display is correct there. That rules out, in a
single stroke, the hardware, the monitor's internal state and any shared system
setting, and points to state specific to the user session. None of the previous
measurements had that discriminating power.

### The confirming measurement

| Display | Gamma table ceiling | Max deviation from the identity ramp |
| --- | --- | --- |
| Built-in (`41038`) | `1.000` | `0.0000` |
| DASUNG `9532` | **`0.375`** | **`0.6250`** |

And in BetterDisplay's preferences:

```
value@softwareBrightness-ColorController@Display:12 = 0.375   ← Revo Color
value@softwareBrightness-ColorController@Display:2  = 1       ← built-in display
value@hardwareBrightness-DDCController@Display:12   = 0
```

The two `0.375` values match exactly. Since the monitor has no usable hardware
brightness control, BetterDisplay has no other way to dim than to crush the
gamma table. On a backlit LCD, that only dims the image. On e-ink, **the grey
levels *are* the image**: everything ends up packed into the bottom third of
the range, contrast collapses and the panel's waveform goes haywire on values
that have become ambiguous.

This also explains what had resisted: the persistence after reboot
(BetterDisplay restores its setting at login), the failure of the official
client — which does set `enableDither = false` — and the fact that unplugging
or restarting the monitor changed nothing, since the table lives on the host
side.

### A gamma table property to know about

CoreGraphics **restores the gamma table when the process that wrote it exits.**
A fix applied by a short-lived utility therefore does not hold, and
BetterDisplay's dimming persists only as long as BetterDisplay is running. This
property first made a detection test look like a failure; it was the test that
was badly built, not the detection.

### Detection added to the agent

`paperlike status` now exposes a `gamma` field per DASUNG output
(`ceiling`, `maxDeviation`), and the agent logs an error as soon as a table
stops being linear. **Read-only, deliberately**: correcting the table would make
the agent a second writer in conflict with BetterDisplay or any legitimate
calibration tool, whereas all of its safety rests on writing only one property,
on the framebuffers of only one manufacturer.

Test: table held at `0.375` by a third-party process → `ceiling: 0.375`,
`maxDeviation: 0.625` and the error logged; on release, back to
`ceiling: 1`, `maxDeviation: 0` and the back-to-linear notice.

## Dithering: a real defect, but a separate one

What follows remains accurate and useful — dithering **was** enabled and had to
be disabled — but it must stop being blamed for the visual defect above.

macOS exposes `enableDither` on each framebuffer; on e-ink, dithering adds
noise. The official client disables it in a loop
(`enableDisableDithering:`, `startDisableDithering`, `disableDitheringTimer`,
`ditheringCheckAction while (true)`), because macOS restores the value on
reconnection, wake or mode change. Closing the client's window with its close
button quits the application, and nothing was maintaining the setting anymore.

| When | ProductID 9532 (DP) | ProductID 0 (HDMI) |
| --- | --- | --- |
| Client quit, after reboot | `enableDither = Yes` | `enableDither = Yes` |
| After `open -a PaperLikeClient` | `enableDither = No` | `enableDither = No` |

**The POC is not implicated in either defect**: at the time of the report it
was in `state = waiting`, `lsof` showed no holder of the port, and its
`requireDisabled` check specifically prevented it from transmitting.

### Mechanism adopted by the agent

The entitlements of `Stillcolor.app` give the exact key:

```
(allow iokit-set-properties (iokit-property "enableDither") (iokit-property "uniformity2D"))
```

The property written is **`enableDither`**; the string `disableDithering`
visible in that binary is only the name of its internal Swift function. Writing
an unknown key is rejected by the driver with `kIOReturnBadArgument`
(`0xE00002C2`) — an error hit and cleared up during the study.

`IORegistryEntrySetCFProperty(service, "enableDither", kCFBooleanFalse)` on the
`IOMobileFramebufferAP` services returns `kern_return = 0` from an ordinary
binary, **not sandboxed and without any entitlement**: Stillcolor needs the
`com.apple.security.temporary-exception.sbpl` exception only because it is
itself sandboxed. The toggle was verified by read-back in both directions.

The agent therefore applies this setting itself on every two-second tick,
whatever the control mode: the write is an IOKit property on the framebuffer
and never touches the USB port. Only outputs whose EDID manufacturer is DASUNG
(`0x1263`) are written — the manufacturer match is the positive condition for
writing. The built-in panel is deliberately excluded: removing dithering there
produces banding.

End-to-end test performed: `enableDither` forced to `true` on both outputs,
restored to `false` by the agent in under two seconds, `result = 0`,
`ditheringReasserts` counter incremented by two and `wasEnabled = true`
recorded. Recovery after a full system sleep cycle has not been observed; the
periodic timer covers it by construction, without proof.

### Two DASUNG monitors, not one — how to tell them apart

**A mistake made during this study, recorded here so that it is not repeated.**
macOS exposes two `Paperlike253` connections. They were taken to be a single
monitor plugged in twice, and "unplug the HDMI cable" was wrongly advised. The
user actually owns **two distinct DASUNG monitors**: a black-and-white
Paperlike 253 and a Paperlike 253 Revo Color.

The trap is that everything that jumps out is identical: same
`ProductName = "Paperlike253"`, same EDID manufacturer `0x1263`, same
3200 × 1800 resolution. The observations used to reach the conclusion
(`SinkDeviceID` `AG6320`, portID 16, `RTK FHD`/`Yealink` history on the same
port) are accurate but prove nothing: they describe a path through a dock,
which is just as true for two monitors as for two cables.

The real discriminators:

| Field | Black and white | Revo Color |
| --- | --- | --- |
| `ProductID` | `0` | `9532` (`0x253C`) |
| `SerialNumber` | `0` | `25312` |
| `YearOfManufacture` | 2020 | 2025 |
| `DFP Type` | 3 (`HDMI`) | 0 (`DP`) |
| `SupportsBT2020RGB` / `YCC` / `cYCC` | absent | present |

The serial number and the year reliably separate the two; the
`SupportsBT2020*` fields are present only on the color model. Never identify a
DASUNG monitor by its `ProductName`.

Consequence for the code: anti-dithering iterates over **all** outputs whose
EDID manufacturer is `0x1263` (and, since the 13K, its Realtek EDID) and
writes each one. Two monitors are therefore covered with no special handling,
and the disappearance of one does not affect the other —
`withPaperlikeFramebuffers` keeps no state between two calls.

At the time, only one CH340 adapter was present (`/dev/cu.usbserial-2115410`),
and the agent refused any selection if a second one appeared. That refusal
was lifted when the 13K arrived — see its section above.

### Black display: resolved by Ghost Cleanup

A symptom distinct from the two previous ones: the Revo Color no longer
displayed anything at all, which neither dithering nor the gamma table
explains — both dirty the image without erasing it. The registers read back at
that moment were contrast 1, mode 2, speed 4, and the monitor was responding
normally.

`paperlike refresh` (command `0x03`) was enough: acknowledgement `5FF5F003…`
from the monitor, image back. It was therefore an internal state of the panel,
not a host problem. An earlier occurrence appeared in the handoff notes,
recovered by changing the contrast — which triggers the same redraw. The move
to remember for a panel stuck black is Ghost Cleanup, which requires
`--control` and the CH340 link.

## Setting latency: the wait came from the agent, not the monitor

A shortcut took about two seconds to act. The monitor had nothing to do with
it: `SerialPort.readFrames` only returned when its timeout expired, **even after
receiving the expected response**. Each read therefore cost its full 0.6 s
timeout, and a setting chains three or four of them (front light precondition,
previous value, 0.25 s wait after the write, read-back).

| Measurement | Before | After |
| --- | --- | --- |
| `paperlike read 07` | 0.63 s | 0.06 s |
| `paperlike query` (4 registers) | 2.47 s | 0.20 s |
| Write + read-back (`light-temp +1`) | ~1.5 s | 0.12 s |

A read now returns as soon as the response for its register is parsed; the
timeout only matters on failure. The monitor **also acknowledges setting
writes** with `5FF5F0<cmd>000000000000A0FA` (observed: `F008` for temperature,
`F009` for brightness): this acknowledgement ends the wait, but it is never
taken as proof — read-back remains the contract of every write.

The limit that refused two commands less than 0.5 s apart
("Command too soon") is replaced by 0.1 s spacing that delays instead of
refusing. On the shortcut side, rapid presses of the same relative key are
coalesced: five presses of ↑ during one exchange yield a single +40 write after
the first one.

## Front light: switching on and off

`paperlike light on|off|toggle` (shortcut ⌃⌥⌘L) writes register `0x07`.
Modes 1 to 3 remain unidentified; the agent restores the last non-zero mode
seen (3 has been observed), and 1 before it has seen one. This mode is read on
connection and kept in the agent's preferences (`lastLightMode`): without that,
every reinstall reset it to 1.

The brightness register `0x09` **reads 0 while the light is off**, and gets its
value back when the light is switched on (observed: 0 when off, 40 after
`light-mode 1`). So the monitor retains it. A genuinely zero value would give a
light that is "on" with no effect on the panel, which would look like a broken
shortcut: in that case only, switching on raises it to 20.

**Brightness and on/off form a single level.** Since `0x09` is ignored while
the light is off, "brighter" from off must first write `0x07`, then the
brightness (`FrontLight.step`, tested); and going down to 0 writes `0x07 = 0`
without touching `0x09`, which the monitor keeps for the next time the light is
switched on. Unavoidable consequence: switching on from ↑ briefly shows the
remembered level before the first step.

**Query ignored after a mode change.** Right after the acknowledgement of a
`0x07` write, the monitor **ignores** the next read: no response, not even a
late one, whereas the same read 50 ms later does get a response. This is what
made the switch-on shortcut fail once the wait was removed (the old fixed
0.25 s pause after every write masked it). A query is now resent every 0.2 s
until its 0.6 s timeout.

## Monitor command map

Mapped by disassembling the client's `updateView…` methods: each method label
immediately precedes the byte it sends, with no inference.

| Cmd | Client method | Setting | Bounds | Original value |
| --- | --- | --- | --- | --- |
| `0x01` | `updateViewThresholdInfo:` | Contrast ("Contrast Level") | 1–9 | 1 |
| `0x02` | `updateViewModeInfo:` | Mode: text / image | 1–2 | 2 |
| `0x03` | `updateViewRefreshInfo:` | Ghost Cleanup | — | — |
| `0x04` | `updateViewSpeedInfo:` | Refresh Speed | 1–5 | 4 |
| `0x05` | `updateRealTimeClockInfo` | **Real-time clock** — not exposed | — | no response |
| `0x07` | `updateViewFrontModeInfo:` | Front light: mode | 0–3 | 0 |
| `0x08` | `updateViewFrontTemperatureValueInfo:` | Front light: temperature | 0–100 | 70 |
| `0x09` | `updateViewFrontBrightnessValueInfo:` | Front light: brightness | 0–100 | 0 |
| `0x0A` | `requestUpdateViewInfo:` | read prefix | — | — |
| `0x10` | — | MCU | — | 48 (`0x30`) |
| `0x12` | `updateTextEnhancementInfo:` | Text Enhancement | 0–1 | 1 |
| `0x13` | `setDisplayVersionMode:` | **Model** — read-only, see the 13K section | — | 5 (253 Color) |
| `0x20` | `updateDitheringInfo:` | dithering state | — | no response |

`0x05` and `0x13` are not exposed for writing: the first is a clock, the second
the model identifier. A test enforces this (`testEverySettingIsUniquelyNamedAndCommanded`).

**Dependency discovered:** `0x09` (front light brightness) is silently ignored
as long as `0x07` is 0. The monitor then keeps the old value without reporting
anything — hence the mandatory read-back after every write, and the explicit
declaration of this dependency in `Setting.requires`, to return a useful
message rather than a misleading bounds error.

Bounds established by writing then reading back: the monitor clamps values
itself, so a rejected value shows up as a diverging read-back and the command
fails instead of claiming to have succeeded. The original state above was
restored after the tests.

## Hardware and client examined

- macOS 26.6.2, Apple M1 Max.
- The physical monitor presents itself to macOS as `Paperlike253`, EDID
  manufacturer `0x1263`, product `0x0000`, 3200 × 1800, mode observed at 40 Hz.
  The "153" mentioned initially does not match the detected name.
- The official client shows `PaperLike253(Color) [FrontLight]`.
- The control link exposes `/dev/cu.usbserial-2115410`, CH340
  `1a86:7523`. The path is detected dynamically, never hard-coded.
- The second DASUNG output, product `0x253C` (9532), is a **second physical
  monitor**: the Revo Color, alongside the black-and-white Paperlike 253 as
  product `0`. See "Two DASUNG monitors" above for the fields that tell them
  apart.
- The client was updated during the investigation. Its window shows
  **V2.0.3**, but its `Info.plist` keeps `CFBundleVersion = 1.2`.
  SHA-256 of the binary examined after this update:
  `c64c223493cae5d2fb86cdcbe8bddb7d75827dbd3e847500af66517b0e0e9304`.

## Primary sources

1. [DASUNG — official downloads](https://www.dasung.com/h-col-112.html):
   Mac client V2.0.3, available at the time of the study.
2. [PaperlikeMenu](https://github.com/WooHooDai/PaperlikeMenu): a recent macOS
   alternative, with menus, shortcuts and login. The author only reports testing
   on PaperLike HD-FT M / Mac mini M4. The repository consulted distributes the
   product and its documentation; it does not establish its compatibility with
   this Color Revo. No code or binary from this project is embedded in the POC.
3. [Denis Sandmann — Dasung Paperlike 253 Linux Driver](https://github.com/dnsandmann/Dasung-Paperlike-253-Linux-Driver):
   USB reverse engineering, CH340, ASCII protocol at 115200 baud, identification
   and keepalive. Public announcement dated June 5, 2026. Linux behavior alone
   does not prove the Mac's; the exchanges were tested here.
4. [Philip Metzler — dasung253](https://github.com/cpmetz/dasung253/blob/master/dasung253.py):
   captures and commands published in 2022 for contrast, speed and Ghost
   Cleanup. The settings were cross-checked against the installed client, then
   against the monitor.
5. [Apple — LSUIElement](https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement)
   and [Launch Services Keys](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/LaunchServicesKeys.html):
   agent application hidden from the Dock.
6. [Apple — SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
   and [Launch Agents](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html):
   launch at login. The POC uses the user LaunchAgent already used in
   mac-setup; a distributed version could use SMAppService.

## Cross-checked protocol

Messages are **24 ASCII characters**, not twelve binary bytes:
`5FF5` + hexadecimal command + hexadecimal value + twelve `0` + `A0FA`.
The Swift implementation is independent; it neither loads nor redistributes the
proprietary client. The public scripts were consulted as descriptions of the
protocol. The installed binary was inspected locally to verify the format, the
setting bounds and the accepted MCUs.

| Action | Host message |
| --- | --- |
| Read the MCU | `5FF50A10000000000000A0FA` |
| Read contrast | `5FF50A01000000000000A0FA` |
| Read mode | `5FF50A02000000000000A0FA` |
| Read speed | `5FF50A04000000000000A0FA` |
| Keep the image active | `5FF52001000000000000A0FA` |
| Run Ghost Cleanup | `5FF50300000000000000A0FA` |
| Contrast 2 | `5FF50102000000000000A0FA` |
| Speed 5 | `5FF50405000000000000A0FA` |

Actual recorded responses:

```text
5FF5F00A103011100001A0FA  MCU 0x30; other bytes kept, not interpreted
5FF5F00A010100000000A0FA  contrast 1
5FF5F00A020200000000A0FA  mode 2
5FF5F00A040400000000A0FA  speed 4
5FF5F020000000000000A0FA  keepalive acknowledgement
5FF5F003000000000000A0FA  Ghost Cleanup acknowledgement
```

The keepalive is sent every two seconds to keep a margin against the timeout
of about five seconds described by the Linux source. No "reset", firmware
update or power-off command is exposed.

In the Mac client V2.0.3, `updateDitheringInfo:` sends command `0x20` with the
dithering-disabled state, from `tryToDisableDithering`. This message is
therefore not a mere keepalive independent of the Mac's graphics state: it tells
the monitor what the host is doing with dithering. This is why
`requireDisabled` remains a **precondition on the serial path**, read back on
every cycle, and not a mere consequence of the write made by the agent: if macOS
sets `enableDither` back to `Yes` between the write and the transmission, the
`0x20/1` frame is skipped for that cycle rather than sent wrongly.

BetterDisplay was ruled out as a cause: `systemVirtual@Display:*` and
`thirdPartyVirtual@Display:*` are all `0` (no virtual display) and
`intelEDIDOverride@v4707m0` is `0` (no active EDID override on the DASUNG).

## Validation performed

- Native build and ad hoc signing of the application.
- Tests of the protocol, USB noise and fragmentation, response filtering,
  command bounds, refusal of ambiguous selection and exchange over a
  pseudo-terminal.
- Actual installation of the LaunchAgent. macOS reports `running` and the
  login item is `enabled, allowed` in `sfltool dumpbtm`.
- `NSRunningApplication` reports `activationPolicy = 2` (prohibited),
  `active = false`, and CoreGraphics counts **zero windows** for the process.
  Since the HUD was introduced, a non-activating window is visible for 1.6 s
  after each shortcut, then none; while it is shown, `paperlike status` reports
  `takesFocus: false` and `visibleWindowCount: 1`, then `0` two seconds later.
  Screenshot taken: the HUD appears at the top right of the display under the
  pointer.
- The POC waits while the official client is open. After the client is closed,
  serial identification succeeds with MCU `0x30`.
- Contrast **1 → 2 → 1**, speed **4 → 5 → 4**: values confirmed by
  read-back after each write. Final state identical to the initial state.
- Ghost Cleanup received and acknowledged by the monitor. The effect on the
  physical panel requires the user's observation.
- Shortcut Control+Option+Command+R accepted by macOS (`OSStatus = 0`).
  The physical keypress remains to be tried by the user.

The detailed log of the settings test stays local in
`cache/paperlike-agent/hardware-test.json` (ignored by Git).
These results prove the exchanges on this Mac and this monitor during the test,
not stability over several days, nor sleep, unplug or full restart cycles. No
overall diagnosis of the proprietary code is claimed.
