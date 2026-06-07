local colors = require("colors")

-- Equivalent to the --bar domain
sbar.bar({
	topmost = "window",
	drawing = true,
	height = 32,
	color = colors.bar.bg,
	padding_right = 20, -- room for the macOS camera/mic-in-use green dot
	padding_left = 5,
})
