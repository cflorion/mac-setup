local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

-- Register the custom aerospace event
sbar.add("event", "aerospace_workspace_change")

local spaces = {}

-- Single source of truth for the workspaces, in display order.
--   key   = AeroSpace workspace name (= Hyper shortcut)
--   app   = app name as reported by `aerospace list-windows` (nil = free workspace)
--   label = text shown in SketchyBar
--   side  = side of the notch (left / right)
-- Everything else (left_names, right_names, display_names, workspace_labels) is derived from it.
local workspace_defs = {
  { key = "W", app = "WezTerm",         label = "WezTerm",  side = "left" },
  { key = "M", app = "Superhuman",      label = "Mail Pro", side = "left" },
  { key = "S", app = "Slack",           label = "Slack",    side = "left" },
  { key = "C", app = "Google Chat",     label = "Chat",     side = "left" },
  { key = "L", app = "Linear",          label = "Linear",   side = "left" },
  { key = "O", app = "Obsidian",        label = "Obsidian", side = "left" },
  { key = "T", app = "TickTick",        label = "TickTick", side = "left" },
  { key = "A", app = "Notion Calendar", label = "Agenda",   side = "left" },
  { key = "H", app = "Helium",          label = "Helium",   side = "left" },
  { key = "V", app = "Google Meet",     label = "Meet (V)",  side = "left" },
  { key = "B", app = "Safari",          label = "Safari (B)", side = "right" },
  { key = "G", app = "ChatGPT",         label = "GPT",      side = "right" },
  { key = "Y", app = "Kaset",           label = "YT Music", side = "right" },
  { key = "1", side = "right" },
  { key = "2", side = "right" },
  { key = "3", side = "right" },
}

-- Background apps never shown in a workspace label, even when present in it
-- (e.g. OBS runs in the background, driven by global hotkeys). Matched on the
-- raw aerospace app-name, before display_names mapping.
local hidden_apps = {
  ["OBS Studio"] = true,
  ["Antinote"] = true,
}

-- Derived from workspace_defs:
--   left_names / right_names : item order per side of the notch
--   display_names            : AeroSpace app name -> label (app open)
--   workspace_labels         : key -> label (fallback when the app is closed)
local left_names, right_names = {}, {}
local display_names, workspace_labels = {}, {}
local workspace_names = {}
for _, def in ipairs(workspace_defs) do
  if def.side == "right" then
    right_names[#right_names + 1] = def.key
  else
    left_names[#left_names + 1] = def.key
  end
  workspace_names[#workspace_names + 1] = def.key
  if def.label then
    workspace_labels[def.key] = def.label
    if def.app then
      display_names[def.app] = def.label
    end
  end
end

local function create_space(ws_name, position)
  local space = sbar.add("item", "space." .. ws_name, {
    position = position,
    icon = {
      drawing = false,
      width = 0,
      padding_left = 0,
      padding_right = 0,
    },
    label = {
      padding_left = 6,
      padding_right = 6,
      color = colors.inactive,
      highlight_color = colors.white,
      font = { family = settings.font.text, style = settings.font.style_map["Bold"], size = 13.0 },
      background = { drawing = false },
    },
    padding_right = 1,
    padding_left = 1,
    -- Active-workspace marker: a thin underline. Color luminance (white vs grey)
    -- is indistinguishable on a 1-bit text-mode e-paper display, so the focused
    -- item is flagged by shape instead. colors.white = black in light theme,
    -- white in dark — so the underline always matches the active text color.
    -- Toggled per-focus in set_focus; geometry is set once here.
    background = {
      drawing = false,
      height = 2,
      corner_radius = 0,
      border_width = 0,
      color = colors.white,
      y_offset = -11,
    },
    drawing = true,
  })

  spaces[ws_name] = space

  sbar.add("item", "space.padding." .. ws_name, {
    position = position,
    script = "",
    width = settings.group_paddings,
    drawing = true,
  })

  space:subscribe("mouse.clicked", function(env)
    sbar.exec("aerospace workspace " .. ws_name)
  end)
end

-- Left group: C → H, left to right
for _, ws_name in ipairs(left_names) do
  create_space(ws_name, "left")
end

-- Right group: added in reverse order so they show B → 3 from left to right
for i = #right_names, 1, -1 do
  create_space(right_names[i], "right")
end

-- The currently focused workspace. Cached so label refreshes never need to
-- re-query AeroSpace for focus, and so set_focus can early-return on no-ops.
local current_focus = nil

-- Move the focus highlight (bold + underline) to `focused_ws`. The ONLY writer
-- of icon/label highlight and the underline (background.drawing). It sets EVERY
-- item explicitly (focused on, all others off) rather than just toggling the
-- previous and new ones: apply_focus calls this from async exec callbacks that
-- can interleave under rapid navigation, and "clear only the previous one" would
-- then leave stale underlines lit. A full idempotent pass is self-correcting —
-- after it, exactly one item is highlighted, whatever the prior state. Items
-- already in the right state are not repainted, so there is no flicker.
local function set_focus(focused_ws)
  if not focused_ws or focused_ws == "" or focused_ws == current_focus then
    return
  end
  current_focus = focused_ws

  for _, ws_name in ipairs(workspace_names) do
    local space = spaces[ws_name]
    if space then
      local is_focused = ws_name == focused_ws
      space:set({
        icon = { highlight = is_focused },
        label = { highlight = is_focused, color = is_focused and colors.white or colors.inactive },
        background = { drawing = is_focused },
      })
    end
  end
end

-- Refresh each workspace's label text (app names for occupied spaces, the
-- fallback name otherwise). Async; does NOT touch the focus highlight, so it
-- can never fight set_focus or bounce the selection.
local function refresh_labels()
  sbar.exec("aerospace list-workspaces --monitor all --empty no", function(active_workspaces)
    local active_set = {}
    for ws in active_workspaces:gmatch("[^\r\n]+") do
      active_set[ws:gsub("%s+", "")] = true
    end
    if current_focus then active_set[current_focus] = true end

    for _, ws_name in ipairs(workspace_names) do
      if spaces[ws_name] then
        if active_set[ws_name] then
          -- AeroSpace briefly keeps listing a window whose app was just quit
          -- (its model lags ~0.5s). Filter to windows whose owning PID is
          -- still alive, so the label is correct immediately — no timing guess.
          local list_cmd = "aerospace list-windows --workspace " .. ws_name
            .. " --format '%{app-pid}|%{app-name}'"
            .. " | while IFS='|' read -r pid name; do"
            .. " kill -0 \"$pid\" 2>/dev/null && echo \"$name\"; done"
          sbar.exec(list_cmd, function(windows)
            local icon_line = ""
            for app in windows:gmatch("[^\r\n]+") do
              local trimmed_app = app:gsub("^%s+", ""):gsub("%s+$", "")
              if not hidden_apps[trimmed_app] then
                trimmed_app = display_names[trimmed_app] or trimmed_app
                if trimmed_app ~= "" then
                  icon_line = icon_line == "" and trimmed_app or (icon_line .. "  " .. trimmed_app)
                end
              end
            end
            if icon_line == "" then icon_line = workspace_labels[ws_name] or ws_name end
            spaces[ws_name]:set({ label = icon_line })
          end)
        else
          -- Empty AND unfocused: collapse to just the key letter to keep the bar
          -- compact (16 full-word labels overflow and collide in the middle).
          -- The focused workspace is force-added to active_set above, so a focused
          -- empty space still falls into the active branch and shows its full label.
          spaces[ws_name]:set({ label = ws_name })
        end

        sbar.set("space.padding." .. ws_name, { drawing = true })
      end
    end
  end)
end

-- Move the highlight to the authoritative focused workspace, coalescing rapid
-- calls. The aerospace_workspace_change event stream is noisy under fast
-- navigation: AeroSpace emits duplicated and out-of-order FOCUSED_WORKSPACE
-- hints (even backward ones), which, applied verbatim, make the highlight
-- bounce. So we ignore the event payload and query the real focus instead
-- (verified to reflect a committed switch immediately). A generation counter
-- ensures only the most recently requested read is applied — an earlier read
-- that resolves late is dropped, so the highlight can never jump backward.
local focus_gen = 0
local function apply_focus()
  focus_gen = focus_gen + 1
  local my_gen = focus_gen
  sbar.exec("aerospace list-workspaces --focused", function(focused_ws)
    if my_gen ~= focus_gen then return end
    set_focus(focused_ws:gsub("%s+", ""))
    refresh_labels()
  end)
end

local space_listener = sbar.add("item", {
  drawing = false,
  updates = true,
})

space_listener:subscribe("aerospace_workspace_change", function()
  apply_focus()
end)

-- Refresh the per-workspace app list when the frontmost app changes.
-- AeroSpace emits no "window closed" event, so quitting a floating app
-- (e.g. ⌘Q on System Settings) wouldn't otherwise update the label — but
-- it does change the front app, which fires front_app_switched. The dead-PID
-- filter in refresh_labels makes the just-quit app drop out immediately.
-- Labels only: focus is handled by apply_focus on workspace-change events, so a
-- front-app switch must not move the highlight (it would fight that path).
space_listener:subscribe("front_app_switched", function()
  refresh_labels()
end)

-- Initial render: highlight the focused workspace and fill in the labels.
apply_focus()
