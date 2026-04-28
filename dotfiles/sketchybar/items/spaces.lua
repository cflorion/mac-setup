local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

-- Register the custom aerospace event
sbar.add("event", "aerospace_workspace_change")

local spaces = {}

-- All possible AeroSpace workspaces
-- C=Claude, W=WezTerm, S=Safari, M=Superhuman, N=Slack, G=Google Chat, P=Linear (Project), O=Obsidian, T=TickTick, I=Notion Calendar, Y=Kaset/YouTube Music, X=Google Chrome
local workspace_names = { "C", "W", "S", "M", "N", "G", "P", "O", "T", "I", "Y", "X", "1", "2", "3", "4", "5" }

for _, ws_name in ipairs(workspace_names) do
  local space = sbar.add("item", "space." .. ws_name, {
    icon = {
      drawing = false,
      width = 0,
      padding_left = 0,
      padding_right = 0,
    },
    label = {
      padding_left = 10,
      padding_right = 10,
      color = colors.grey,
      highlight_color = colors.white,
      font = { family = settings.font.text, style = settings.font.style_map["Bold"], size = 13.0 },
      background = {
        drawing = false,
      },
    },
    padding_right = 1,
    padding_left = 1,
    background = {
      drawing = false,
    },
    drawing = false, -- hidden by default, shown only when active
  })

  spaces[ws_name] = space

  -- Padding
  sbar.add("item", "space.padding." .. ws_name, {
    script = "",
    width = settings.group_paddings,
    drawing = false,
  })

  -- Click to switch workspace
  space:subscribe("mouse.clicked", function(env)
    sbar.exec("aerospace workspace " .. ws_name)
  end)
end

-- Update which workspaces are visible and which is focused
local function update_spaces()
  -- Get focused workspace
  sbar.exec("aerospace list-workspaces --focused", function(focused_ws)
    focused_ws = focused_ws:gsub("%s+", "")

    -- Get all workspaces with windows
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

        -- Show/hide workspace with underline on focused
        if spaces[ws_name] then
          spaces[ws_name]:set({
            drawing = is_active,
            icon = { highlight = is_focused },
            label = {
              highlight = is_focused,
              color = is_focused and colors.white or colors.grey,
            },
          })
        end

        -- Show app icons in workspace label
        if is_active and spaces[ws_name] then
          sbar.exec(
            "aerospace list-windows --workspace " .. ws_name .. " --format '%{app-name}'",
            function(windows)
              local icon_line = ""
              local no_app = true
              for app in windows:gmatch("[^\r\n]+") do
                local trimmed_app = app:gsub("^%s+", ""):gsub("%s+$", "")
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
        end

        -- Update padding visibility to match space
        sbar.set("space.padding." .. ws_name, { drawing = is_active })
      end
    end)
  end)
end

-- Subscribe to aerospace workspace changes
local space_listener = sbar.add("item", {
  drawing = false,
  updates = true,
})

space_listener:subscribe("aerospace_workspace_change", update_spaces)

-- Also update on front_app_switched (window opened/closed may change workspace state)
space_listener:subscribe("front_app_switched", update_spaces)

-- Initial update
update_spaces()
