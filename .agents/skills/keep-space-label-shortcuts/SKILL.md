---
name: keep-space-label-shortcuts
description: Keep AeroSpace shortcut letters visible in SketchyBar labels when the displayed title starts with a different letter. Use when adding, removing, renaming, or reviewing workspace definitions in dotfiles/sketchybar/items/spaces.lua or their matching bindings in dotfiles/aerospace/aerospace.toml.
---

# Keep Space Label Shortcuts

Apply this rule to every named entry in `workspace_defs`:

- Compare the workspace `key` with the first letter of its displayed `label`, case-insensitively.
- When they differ, format the label as `<title> (<KEY>)`.
- When they match, keep the title without a redundant suffix.
- Ignore numeric free workspaces without labels.

Examples:

- `B` with `Safari` becomes `Safari (B)`.
- `V` with `Meet` becomes `Meet (V)`.
- `G` with `ChatGPT` becomes `ChatGPT (G)`.
- `M` with `Mail Pro` stays `Mail Pro`.

After changing workspaces:

- Check every labeled `workspace_defs` entry, not only the new one.
- Keep the label as the single source used for both open-app and fallback display names.
- Run `luac -p dotfiles/sketchybar/items/spaces.lua`.
- Reload SketchyBar when applying the change to the current machine.
