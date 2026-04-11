local settings = require("settings")
local colors = require("colors")

local cal = sbar.add("item", {
	label = {
		color = colors.white,
		padding_right = 10,
		font = {
			family = settings.font.numbers,
			style = settings.font.style_map["Bold"],
			size = 14.0,
		},
	},
	icon = { drawing = false },
	position = "right",
	padding_right = 1,
	update_freq = 30,
	background = { drawing = false },
})

cal:subscribe({ "forced", "routine", "system_woke" }, function(env)
	cal:set({ label = os.date("%H:%M") })
end)
