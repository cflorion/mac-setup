local colors = require("colors")
local settings = require("settings")

-- CONFIG_DIR isn't set in sbar.exec's environment, so resolve the script path
-- the same way sketchybarrc resolves the config dir.
local config_dir = os.getenv("CONFIG_DIR")
  or (os.getenv("HOME") .. "/.config/sketchybar")
local stats_script = config_dir .. "/helpers/sysstats.sh"

-- Compact, monochrome, fixed-width system stats: "CPU 23%  RAM 52%".
-- Styled to match the adjacent clock (grey text, no background/bracket) so it
-- blends into the bar instead of standing out as a boxed button. Single text
-- item (no icon/graph/color) so it stays legible on the 1-bit e-paper readout.
-- Sits just left of the date/time (see require order in items/init.lua).
-- All computation lives in helpers/sysstats.sh.
local sysstats = sbar.add("item", "widgets.sysstats", {
  position = "right",
  icon = { drawing = false },
  label = {
    string = "CPU --%  RAM --%",
    color = colors.grey,
    padding_right = 10,
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 14.0,
    },
  },
  padding_right = 1,
  background = { drawing = false },
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
