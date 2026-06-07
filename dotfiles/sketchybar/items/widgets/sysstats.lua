local colors = require("colors")
local settings = require("settings")

-- CONFIG_DIR isn't set in sbar.exec's environment, so resolve the script path
-- the same way sketchybarrc resolves the config dir.
local config_dir = os.getenv("CONFIG_DIR")
  or (os.getenv("HOME") .. "/.config/sketchybar")
local stats_script = config_dir .. "/helpers/sysstats.sh"

-- Compact, monochrome, fixed-width system stats: "CPU 23%  RAM 52%".
-- Single text item (no icon, no graph, no color) so it stays legible on the
-- 1-bit text-mode e-paper readout. Sits just left of the date/time (see the
-- require order in items/init.lua). All computation lives in helpers/sysstats.sh.
local sysstats = sbar.add("item", "widgets.sysstats", {
  position = "right",
  icon = { drawing = false },
  label = {
    string = "CPU --%  RAM --%",
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 12.0,
    },
  },
  update_freq = 5,
})

sysstats:subscribe({ "routine", "system_woke" }, function()
  sbar.exec(stats_script, function(out)
    local line = out:gsub("%s+$", "")
    if line ~= "" then
      sysstats:set({ label = { string = line } })
    end
  end)
end)

sysstats:subscribe("mouse.clicked", function()
  sbar.exec("open -a 'Activity Monitor'")
end)

sbar.add("bracket", "widgets.sysstats.bracket", { sysstats.name }, {
  background = { color = colors.bg1 },
})

sbar.add("item", "widgets.sysstats.padding", {
  position = "right",
  width = settings.group_paddings,
})
