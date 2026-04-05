local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

-- Register the custom aerospace event
sbar.add("event", "aerospace_workspace_change")

local spaces = {}
local space_brackets = {}

-- All possible AeroSpace workspaces
local workspace_names = { "A", "B", "C", "M", "S", "T", "1", "2", "3", "4", "5" }

for _, ws_name in ipairs(workspace_names) do
  local space = sbar.add("item", "space." .. ws_name, {
    icon = {
      font = { family = settings.font.numbers, style = settings.font.style_map["Bold"] },
      string = ws_name,
      padding_left = 15,
      padding_right = 8,
      color = colors.white,
      highlight_color = colors.magenta,
    },
    label = {
      padding_right = 20,
      color = colors.grey,
      highlight_color = colors.white,
      font = "sketchybar-app-font:Regular:16.0",
      y_offset = -1,
    },
    padding_right = 1,
    padding_left = 1,
    background = {
      color = colors.bg1,
      height = 26,
    },
    drawing = false, -- hidden by default, shown only when active
  })

  spaces[ws_name] = space

  local space_bracket = sbar.add("bracket", { space.name }, {
    background = {
      color = colors.transparent,
      border_color = colors.bg2,
      height = 28,
      border_width = 2,
    },
  })

  space_brackets[ws_name] = space_bracket

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

        -- Show/hide workspace
        if spaces[ws_name] then
          spaces[ws_name]:set({
            drawing = is_active,
            icon = { highlight = is_focused },
            label = { highlight = is_focused },
          })
        end
        if space_brackets[ws_name] then
          space_brackets[ws_name]:set({
            background = { border_color = is_focused and colors.magenta or colors.bg2 },
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
                  local lookup = app_icons[trimmed_app]
                  local icon = lookup or app_icons["default"]
                  icon_line = icon_line .. " " .. icon
                end
              end
              if no_app then
                icon_line = " —"
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

-- Spaces indicator (toggle with menus)
local spaces_indicator = sbar.add("item", {
  padding_left = -3,
  padding_right = 0,
  icon = {
    padding_left = 8,
    padding_right = 9,
    color = colors.grey,
    string = icons.switch.on,
  },
  label = {
    width = 0,
    padding_left = 0,
    padding_right = 8,
    string = "Spaces",
    color = colors.bg1,
  },
  background = {
    color = colors.with_alpha(colors.grey, 0.0),
    border_color = colors.with_alpha(colors.bg1, 0.0),
  },
})

spaces_indicator:subscribe("swap_menus_and_spaces", function(env)
  local currently_on = spaces_indicator:query().icon.value == icons.switch.on
  spaces_indicator:set({
    icon = currently_on and icons.switch.off or icons.switch.on,
  })
end)

spaces_indicator:subscribe("mouse.entered", function(env)
  sbar.animate("tanh", 30, function()
    spaces_indicator:set({
      background = {
        color = colors.with_alpha(colors.grey, 1.0),
        border_color = colors.with_alpha(colors.bg1, 1.0),
      },
      icon = { color = colors.bg1 },
      label = { width = "dynamic" },
    })
  end)
end)

spaces_indicator:subscribe("mouse.exited", function(env)
  sbar.animate("tanh", 30, function()
    spaces_indicator:set({
      background = {
        color = colors.with_alpha(colors.grey, 0.0),
        border_color = colors.with_alpha(colors.bg1, 0.0),
      },
      icon = { color = colors.grey },
      label = { width = 0 },
    })
  end)
end)

spaces_indicator:subscribe("mouse.clicked", function(env)
  sbar.trigger("swap_menus_and_spaces")
end)
