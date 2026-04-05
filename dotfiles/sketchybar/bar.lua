local colors = require("colors")

-- Equivalent to the --bar domain
sbar.bar({
	topmost = "window",
	drawing = true,
	height = 40,
	color = colors.bar.transparent,
	padding_right = 2,
	padding_left = 2,
})
