local function is_dark_mode()
	local handle = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
	local result = handle:read("*a")
	handle:close()
	return result:find("Dark") ~= nil
end

local with_alpha = function(color, alpha)
	if alpha > 1.0 or alpha < 0.0 then
		return color
	end
	return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
end

-- Dark theme: Catppuccin Mocha
local dark = {
	black = 0xff11111b,
	white = 0xffffffff,       -- active text (pure white on dark)
	red = 0xfff38ba8,
	green = 0xffa6e3a1,
	blue = 0xff89b4fa,
	yellow = 0xfff9e2af,
	orange = 0xfffab387,
	magenta = 0xffcba6f7,
	grey = 0xff666666,        -- inactive text (dark grey on dark)
	dark_gray = 0xff1e1e2e,
	transparent = 0x00000000,

	bar = {
		bg = 0xff000000,
		border = 0xff2c2e34,
	},
	popup = {
		bg = 0x991e1e2e,
		border = 0xff11111b,
	},
	bg1 = 0xff1e1e2e,
	bg2 = 0xff313244,
}

-- Light theme: high-contrast with accents (e-ink friendly)
local light = {
	black = 0xff000000,
	white = 0xff000000,       -- active text (black on light)
	red = 0xffcc0000,
	green = 0xff008800,
	blue = 0xff0055cc,
	yellow = 0xffcc8800,
	orange = 0xffcc5500,
	magenta = 0xff8800aa,
	grey = 0xffaaaaaa,        -- inactive text (light grey on light)
	dark_gray = 0xfff5f5f5,
	transparent = 0x00000000,

	bar = {
		bg = 0xffffffff,
		border = 0xffcccccc,
	},
	popup = {
		bg = 0xe6f0f0f0,
		border = 0xff888888,
	},
	bg1 = 0xffe8e8e8,
	bg2 = 0xffd0d0d0,
}

local palette = is_dark_mode() and dark or light
palette.with_alpha = with_alpha

return palette
