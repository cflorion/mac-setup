local colors = require("colors")
local settings = require("settings")

sbar.add("event", "flashspace_workspace_change")

local spaces = {}

-- Single source of truth for FlashSpace workspaces and their shortcut labels.
-- When a title does not start with its shortcut key, the key stays visible in
-- parentheses (for example Safari (B), WhatsApp (D), Messages (H)).
local workspace_defs = {
  { key = "W", label = "WezTerm", side = "left" },
  { key = "M", label = "Mail Pro", side = "left" },
  { key = "P", label = "KissMail (P)", side = "left" },
  { key = "S", label = "msga (S)", side = "left" },
  { key = "D", label = "WhatsApp (D)", side = "left" },
  { key = "H", label = "Messages (H)", side = "left" },
  { key = "C", label = "Claude", side = "left" },
  { key = "L", label = "Linear", side = "left" },
  { key = "O", label = "Obsidian", side = "left" },
  { key = "R", label = "Rappels", side = "left" },
  { key = "A", label = "Agenda", side = "left" },
  { key = "V", label = "Meet (V)", side = "left" },
  { key = "B", label = "Safari (B)", side = "right" },
  { key = "G", label = "ChatGPT (G)", side = "right" },
  { key = "Y", label = "YT Music", side = "right" },
  { key = "N", label = "Notes", side = "right" },
}

local function create_space(def)
  local space = sbar.add("item", "space." .. def.key, {
    position = def.side,
    icon = {
      drawing = false,
      width = 0,
      padding_left = 0,
      padding_right = 0,
    },
    label = {
      string = def.label,
      padding_left = 6,
      padding_right = 6,
      color = colors.inactive,
      highlight_color = colors.white,
      font = { family = settings.font.text, style = settings.font.style_map["Bold"], size = 13.0 },
      background = { drawing = false },
    },
    padding_right = 1,
    padding_left = 1,
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

  spaces[def.key] = space

  sbar.add("item", "space.padding." .. def.key, {
    position = def.side,
    script = "",
    width = settings.group_paddings,
    drawing = true,
  })

  space:subscribe("mouse.clicked", function()
    sbar.exec("flashspace workspace --name " .. def.key)
  end)
end

-- Right-side items are added in reverse because SketchyBar prepends them.
for _, def in ipairs(workspace_defs) do
  if def.side == "left" then create_space(def) end
end
for i = #workspace_defs, 1, -1 do
  if workspace_defs[i].side == "right" then create_space(workspace_defs[i]) end
end

local current_focus = nil

local function set_focus(focused_workspace)
  focused_workspace = focused_workspace and focused_workspace:gsub("%s+", "") or ""
  if focused_workspace == "" or focused_workspace == current_focus then return end

  current_focus = focused_workspace
  for key, space in pairs(spaces) do
    local focused = key == focused_workspace
    space:set({
      label = { highlight = focused, color = focused and colors.white or colors.inactive },
      background = { drawing = focused },
    })
  end
end

local function refresh_focus()
  sbar.exec("flashspace get-workspace 2>/dev/null", function(workspace)
    set_focus(workspace)
  end)
end

local listener = sbar.add("item", "flashspace.workspace.listener", { drawing = false })
listener:subscribe("flashspace_workspace_change", function(env)
  set_focus(env.WORKSPACE)
end)
listener:subscribe("front_app_switched", refresh_focus)
listener:subscribe("system_woke", refresh_focus)

refresh_focus()

return spaces
