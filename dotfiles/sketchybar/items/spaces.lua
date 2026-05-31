local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

-- Register the custom aerospace event
sbar.add("event", "aerospace_workspace_change")

local spaces = {}

-- Source unique de vérité pour les workspaces, dans l'ordre d'affichage.
--   key   = nom du workspace AeroSpace (= raccourci Hyper)
--   app   = nom d'app tel que rapporté par `aerospace list-windows` (nil = workspace libre)
--   label = texte affiché dans SketchyBar
--   side  = côté de l'encoche (gauche / droite)
-- Tout le reste (left_names, right_names, display_names, workspace_labels) en est dérivé.
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
  { key = "B", app = "Safari",          label = "B-Safari", side = "right" },
  { key = "G", app = "Gemini",          label = "Gemini",   side = "right" },
  { key = "Y", app = "Kaset",           label = "YT Music", side = "right" },
  { key = "1", side = "right" },
  { key = "2", side = "right" },
  { key = "3", side = "right" },
}

-- Dérivés de workspace_defs :
--   left_names / right_names : ordre des items par côté de l'encoche
--   display_names            : nom d'app AeroSpace -> label (app ouverte)
--   workspace_labels         : key -> label (fallback quand l'app est fermée)
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
      color = colors.grey,
      highlight_color = colors.white,
      font = { family = settings.font.text, style = settings.font.style_map["Bold"], size = 13.0 },
      background = { drawing = false },
    },
    padding_right = 1,
    padding_left = 1,
    background = { drawing = false },
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

-- Left group: C → H, gauche vers droite
for _, ws_name in ipairs(left_names) do
  create_space(ws_name, "left")
end

-- Right group: ajoutés en ordre inverse pour s'afficher B → 3 de gauche à droite
for i = #right_names, 1, -1 do
  create_space(right_names[i], "right")
end

-- Update which workspaces are visible and which is focused.
-- focused_hint: if provided, skips the AeroSpace query for instant pre-highlighting.
local function update_spaces(focused_hint)
  local function apply(focused_ws)
    sbar.exec("aerospace list-workspaces --monitor all --empty no", function(active_workspaces)
      local active_set = {}
      for ws in active_workspaces:gmatch("[^\r\n]+") do
        local trimmed = ws:gsub("%s+", "")
        active_set[trimmed] = true
      end

      -- Always show focused workspace
      active_set[focused_ws] = true

      for _, ws_name in ipairs(workspace_names) do
        local is_active = active_set[ws_name] == true
        local is_focused = ws_name == focused_ws

        if spaces[ws_name] then
          local label_color = is_focused and colors.white
            or is_active and colors.grey
            or colors.grey
          spaces[ws_name]:set({
            drawing = true,
            icon = { highlight = is_focused },
            label = {
              highlight = is_focused,
              color = label_color,
            },
          })
        end

        if is_active and spaces[ws_name] then
          -- AeroSpace briefly keeps listing a window whose app was just quit
          -- (its model lags ~0.5s). Filter to windows whose owning PID is
          -- still alive, so the label is correct immediately — no timing guess.
          local list_cmd = "aerospace list-windows --workspace " .. ws_name
            .. " --format '%{app-pid}|%{app-name}'"
            .. " | while IFS='|' read -r pid name; do"
            .. " kill -0 \"$pid\" 2>/dev/null && echo \"$name\"; done"
          sbar.exec(
            list_cmd,
            function(windows)
              local icon_line = ""
              local no_app = true
              for app in windows:gmatch("[^\r\n]+") do
                local trimmed_app = app:gsub("^%s+", ""):gsub("%s+$", "")
                trimmed_app = display_names[trimmed_app] or trimmed_app
                if trimmed_app ~= "" then
                  no_app = false
                  if icon_line ~= "" then
                    icon_line = icon_line .. "  " .. trimmed_app
                  else
                    icon_line = trimmed_app
                  end
                end
              end
              if no_app then
                icon_line = workspace_labels[ws_name] or ws_name
              end
              spaces[ws_name]:set({ label = icon_line })
            end
          )
        else
          spaces[ws_name]:set({ label = workspace_labels[ws_name] or ws_name })
        end

        sbar.set("space.padding." .. ws_name, { drawing = true })
      end
    end)
  end

  if focused_hint and focused_hint ~= "" then
    apply(focused_hint)
  else
    sbar.exec("aerospace list-workspaces --focused", function(focused_ws)
      apply(focused_ws:gsub("%s+", ""))
    end)
  end
end

-- Subscribe to aerospace workspace changes.
-- When FOCUSED_WORKSPACE is set in the event env (sent by the cycle script before
-- the actual switch), use it directly to pre-highlight without an extra AeroSpace query.
local space_listener = sbar.add("item", {
  drawing = false,
  updates = true,
})

space_listener:subscribe("aerospace_workspace_change", function(env)
  local hint = env and env.FOCUSED_WORKSPACE
  if hint and hint:match("%S") then
    update_spaces(hint:gsub("%s+", ""))
  else
    update_spaces()
  end
end)

-- Refresh the per-workspace app list when the frontmost app changes.
-- AeroSpace emits no "window closed" event, so quitting a floating app
-- (e.g. ⌘Q on System Settings) wouldn't otherwise update the label — but
-- it does change the front app, which fires front_app_switched. The dead-PID
-- filter in update_spaces makes the just-quit app drop out immediately.
space_listener:subscribe("front_app_switched", function()
  update_spaces()
end)

-- Initial update
update_spaces()
