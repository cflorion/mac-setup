local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

-- Register the custom aerospace event
sbar.add("event", "aerospace_workspace_change")

local spaces = {}

-- W=WezTerm, M=Superhuman (MailPro), S=Slack, G=Gemini, C=Google Chat, L=Linear, O=Obsidian
-- T=TickTick, A=Notion Calendar (Agenda), Y=Kaset/YouTube Music, H=Helium (Browser), B=Safari (Browser)
-- Répartis selon le côté de l'encoche : apps à gauche / apps à droite
local left_names  = { "W", "M", "S", "C", "L", "O", "T", "A", "H" }
local right_names = { "B", "G", "Y", "1", "2", "3" }

-- Remappage des noms d'app affichés dans le label (nom AeroSpace -> nom affiché)
local display_names = {
  ["Google Chat"] = "Chat",
  ["Notion Calendar"] = "Agenda",
  ["Kaset"] = "Y Music",
  ["Superhuman"] = "Mail Pro",
  ["Safari"] = "B Safari",
}

local workspace_names = {}
for _, ws in ipairs(left_names)  do workspace_names[#workspace_names + 1] = ws end
for _, ws in ipairs(right_names) do workspace_names[#workspace_names + 1] = ws end

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
                icon_line = "—"
              end
              spaces[ws_name]:set({ label = icon_line })
            end
          )
        else
          spaces[ws_name]:set({ label = ws_name })
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
