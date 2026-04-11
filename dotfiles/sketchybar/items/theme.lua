local theme_watcher = sbar.add("item", "theme_watcher", {
	drawing = false,
	updates = true,
})

theme_watcher:subscribe("system_appearance_change", function()
	sbar.exec("sketchybar --reload")
end)
