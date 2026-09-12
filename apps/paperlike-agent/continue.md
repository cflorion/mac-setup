# Continue — PaperlikeAgent POC

## Current state

The native Swift POC, its tests, LaunchAgent, CLI wrapper, Makefile targets and
research notes are in this directory and the repository root. On the test Mac,
`PaperlikeAgent --agent --control` is currently enabled at login and owns the
single CH340 serial port. PaperLikeClient is not running. macOS sees two online
`Paperlike253` video connections plus the built-in display.

The screen became fully black after a monitor power cycle. The user recovered a
visible image by changing contrast, but the image still has the same heavy
ghosting/dirty rendering seen with the official client. This does not establish
that either client caused the rendering defect.

## Next action

Fix and test the local CLI connection first: `paperlike status` currently says
the agent is unavailable even while the agent, `control.sock` and serial file
descriptor are present. `LocalSocket.request` makes the Unix socket nonblocking
before `connect` and treats every nonzero return as failure; handle
`EINPROGRESS` correctly or connect before enabling nonblocking mode. Add a real
Unix-socket integration test, then run `make paperlike-test` and
`make paperlike-build`.

After that fix, ask the user to leave a ghosted image visible and press
Control+Option+Command+R once. Record one of: full flash and cleaner image, full
flash with unchanged ghosting, or no visible response. This is the missing
physical proof for command `0x03`.

## Why

Video detection and serial ownership are proven, and command replies were seen
in the earlier hardware trial. Neither proves that a full refresh changes the
panel. The single hotkey observation separates a delivery problem from an image
processing or panel-state problem.

## Open threads

- The official client terminates when its window cross is clicked. Its
  `prepareForWindowClose` sends `0x20/0`; while active, its timer sends a command
  every two seconds. The POC control mode sends `0x20/1` every two seconds after
  verifying `enableDither = No`. Do not infer causality from this sequence.
- The user changed contrast to regain visibility; the current contrast value is
  unknown because the CLI socket failure prevented a status/query check.
- Sleep/wake, physical reconnect and real login-start behavior remain unproven.
- `RESEARCH.md` contains the hardware evidence, protocol frames and source links.

## Do not

- Do not run PaperLikeClient and the POC control mode against the serial port at
  the same time.
- Do not send more experimental USB commands before agreeing on one observable
  physical test with the user.
- Do not include or alter the unrelated working-tree change in
  `dotfiles/bin/claude`.
